"""
AI Schedule Service — AI-powered schedule generation and application.

Responsible for:
  - Building Groq prompts from user context
  - Generating an AI schedule via Groq
  - Persisting AISchedule records
  - Applying (materialising) an AISchedule into CalendarEvent records
"""
import json
import logging
from datetime import datetime, timedelta

from django.utils import timezone

from ..exceptions import AIScheduleError
from ..models import AISchedule, CalendarEvent, GoogleCalendarConnection, SyncLog
from .google_calendar_service import build_calendar_service, push_event_to_google

logger = logging.getLogger('calendar')


def _build_schedule_prompt(user, prompt: str) -> str:
    """Build the Groq prompt for schedule generation."""
    from routines.models import Routine

    recent_routines = Routine.objects.filter(user=user).order_by('-date')[:7]
    routine_context = '\n'.join([
        f"- {r.date}: score={r.productivity_score}%, study={r.study_hours}h, exercise={r.exercise_completed}"
        for r in recent_routines
    ]) or 'No recent routine data.'

    existing_events = CalendarEvent.objects.filter(
        user=user,
        start_time__gte=timezone.now(),
        start_time__lte=timezone.now() + timedelta(days=30),
    ).order_by('start_time')[:20]

    event_context = '\n'.join([
        f"- {e.title} on {e.start_time.strftime('%Y-%m-%d %H:%M')}"
        for e in existing_events
    ]) or 'No upcoming events.'

    return f"""You are an elite AI productivity scheduler embedded in Productivity Tracker.

User Request: {prompt}

User's recent routine data (last 7 days):
{routine_context}

User's existing upcoming calendar events:
{event_context}

Today's date: {timezone.now().strftime('%Y-%m-%d')}
Current time: {timezone.now().strftime('%H:%M')}

Generate a detailed, realistic scheduling plan. Return ONLY valid JSON in this exact format:
{{
  "planTitle": "string — short plan title",
  "planSummary": "string — 2-3 sentence overview",
  "insights": ["string", "string"],
  "events": [
    {{
      "title": "string",
      "description": "string",
      "date": "YYYY-MM-DD",
      "startTime": "HH:MM",
      "endTime": "HH:MM",
      "category": "study|work|exercise|break|personal",
      "color": "blue|purple|green|pink|orange|cyan",
      "reminders": [10],
      "priority": "high|medium|low"
    }}
  ]
}}

Rules:
- Avoid conflicts with existing events
- Balance study, breaks, exercise
- Consider typical peak productivity hours (morning and evening)
- Keep sessions 25-90 minutes (Pomodoro-style)
- Add buffer time between sessions
- Max 6 events per day
- Return ONLY the JSON, no markdown, no explanation"""


def generate_ai_schedule(user, prompt: str) -> 'AISchedule':
    """
    Generate a new AISchedule for the user using Groq.

    Args:
        user: Django user instance
        prompt: user's scheduling request

    Returns:
        AISchedule instance

    Raises:
        AIScheduleError: AI generation or JSON parsing failed
    """
    from common.groq_client import generate_ai_json

    system_prompt = _build_schedule_prompt(user, prompt)

    try:
        plan_data = generate_ai_json(system_prompt, max_tokens=2000)
    except json.JSONDecodeError as exc:
        logger.error('[Calendar] AI schedule returned invalid JSON for user %s: %s', user.id, exc)
        raise AIScheduleError(f'AI returned invalid JSON: {exc}') from exc
    except Exception as exc:
        logger.error('[Calendar] AI schedule generation failed for user %s: %s', user.id, exc)
        raise AIScheduleError(f'AI generation failed: {exc}') from exc

    schedule = AISchedule.objects.create(
        user=user,
        prompt=prompt,
        plan_title=plan_data.get('planTitle', 'AI Schedule'),
        plan_summary=plan_data.get('planSummary', ''),
        generated_events=plan_data.get('events', []),
        status='pending',
    )

    logger.info('[Calendar] Generated AI schedule id=%s for user %s', schedule.id, user.id)
    return schedule, plan_data


def apply_ai_schedule(user, schedule_id: int, sync_to_google: bool = False) -> list:
    """
    Materialise an AISchedule by creating CalendarEvent records.

    Args:
        user: Django user instance
        schedule_id: primary key of the AISchedule
        sync_to_google: if True, also push events to Google Calendar

    Returns:
        list of serialized CalendarEvent dicts

    Raises:
        AIScheduleError: schedule not found or application failed
    """
    from .event_service import serialize_event

    try:
        ai_schedule = AISchedule.objects.get(pk=schedule_id, user=user)
    except AISchedule.DoesNotExist:
        raise AIScheduleError(f'AI schedule id={schedule_id} not found.')

    # Optionally prepare Google service
    service = connection = None
    if sync_to_google:
        try:
            connection = GoogleCalendarConnection.objects.get(user=user)
            if connection.connected:
                service = build_calendar_service(connection)
        except GoogleCalendarConnection.DoesNotExist:
            logger.debug('[Calendar] No Google connection; skipping Google sync for schedule %s', schedule_id)

    created_events = []
    for evt in ai_schedule.generated_events:
        try:
            date_str = evt['date']
            start_str = f"{date_str}T{evt['startTime']}:00"
            end_str = f"{date_str}T{evt['endTime']}:00"
            start_dt = timezone.make_aware(datetime.fromisoformat(start_str))
            end_dt = timezone.make_aware(datetime.fromisoformat(end_str))
        except (KeyError, ValueError) as exc:
            logger.warning('[Calendar] Skipping invalid AI event entry: %s — %s', evt, exc)
            continue

        cal_event = CalendarEvent.objects.create(
            user=user,
            title=evt.get('title', 'AI Session'),
            description=evt.get('description', ''),
            start_time=start_dt,
            end_time=end_dt,
            color=evt.get('color', 'purple'),
            category=evt.get('category', 'study'),
            reminders=evt.get('reminders', [10]),
            is_ai_generated=True,
            ai_metadata={
                'scheduleId': ai_schedule.id,
                'priority': evt.get('priority', 'medium'),
            },
        )

        if service and connection:
            try:
                g_id = push_event_to_google(service, cal_event, connection.calendar_id)
                cal_event.google_event_id = g_id
                cal_event.synced_to_google = True
                cal_event.save(update_fields=['google_event_id', 'synced_to_google'])
            except Exception as exc:
                logger.warning('[Calendar] Google push failed for AI event id=%s: %s', cal_event.id, exc)

        created_events.append(serialize_event(cal_event))

    ai_schedule.status = 'applied'
    ai_schedule.save(update_fields=['status'])

    if service:
        SyncLog.objects.create(
            user=user,
            direction='push',
            status='success',
            events_synced=len(created_events),
        )

    logger.info(
        '[Calendar] Applied AI schedule id=%s for user %s — created %d events',
        schedule_id, user.id, len(created_events),
    )
    return created_events
