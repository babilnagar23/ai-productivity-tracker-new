import json
import logging
from datetime import date, datetime, timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from common.groq_client import generate_ai_response
from routines.models import Routine
from routines.serializers import RoutineSerializer

logger = logging.getLogger('ai')

try:
    from todos.models import Todo
except Exception:
    Todo = None

try:
    from calendar_integration.models import CalendarEvent
except Exception:
    CalendarEvent = None

from .models import AiJob
from .tasks import process_ai_job


# ── Helpers ───────────────────────────────────────────────────────────────────

def _groq_available():
    return bool(getattr(settings, 'GROQ_API_KEY', ''))


def _json_default(value):
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return str(value)


def _pick_attr(obj, *names, default=None):
    for name in names:
        if hasattr(obj, name):
            value = getattr(obj, name)
            if value not in (None, ''):
                return value
    return default


def _to_iso(value):
    if value is None:
        return None
    if isinstance(value, datetime):
        if timezone.is_naive(value):
            value = timezone.make_aware(value, timezone.get_current_timezone())
        return timezone.localtime(value).isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    return str(value)


def recent_routine_payload(user, request, limit=14):
    routines = list(Routine.objects.filter(user=user).order_by('-date')[:limit])
    return RoutineSerializer(routines, many=True, context={'request': request}).data


def routine_summary(user, limit=14):
    routines = list(Routine.objects.filter(user=user).order_by('-date')[:limit])
    if not routines:
        return {
            'totalLogs': 0,
            'avgStudy': 0.0,
            'avgMobile': 0.0,
            'avgScore': 0.0,
            'bestScore': 0,
            'totalStudyHours': 0.0,
            'totalMobileUsage': 0.0,
            'currentStreak': 0,
        }

    study_hours = [float(getattr(r, 'study_hours', 0) or 0) for r in routines]
    mobile_usage = [float(getattr(r, 'mobile_usage', 0) or 0) for r in routines]
    scores = [float(getattr(r, 'productivity_score', 0) or 0) for r in routines]

    profile = getattr(user, 'profile', None)

    return {
        'totalLogs': len(routines),
        'avgStudy': round(sum(study_hours) / len(study_hours), 1),
        'avgMobile': round(sum(mobile_usage) / len(mobile_usage), 1),
        'avgScore': round(sum(scores) / len(scores), 1),
        'bestScore': int(max(scores)) if scores else 0,
        'totalStudyHours': round(sum(study_hours), 1),
        'totalMobileUsage': round(sum(mobile_usage), 1),
        'currentStreak': getattr(profile, 'streak', 0) if profile else 0,
    }


def profile_summary(user):
    profile = getattr(user, 'profile', None)
    if not profile:
        return {}

    try:
        custom_config = profile.custom_config or {}
    except Exception:
        custom_config = {}

    return {
        'xp': getattr(profile, 'xp', 0),
        'streak': getattr(profile, 'streak', 0),
        'custom_config': custom_config,
    }


def todos_payload(user, limit=30):
    if Todo is None:
        return []

    field_names = {f.name for f in Todo._meta.fields}
    order_fields = []
    if 'completed' in field_names:
        order_fields.append('completed')
    elif 'is_completed' in field_names:
        order_fields.append('is_completed')

    if 'due_date' in field_names:
        order_fields.append('due_date')
    elif 'date' in field_names:
        order_fields.append('date')
    elif 'scheduled_for' in field_names:
        order_fields.append('scheduled_for')
    elif 'deadline' in field_names:
        order_fields.append('deadline')
    elif 'due' in field_names:
        order_fields.append('due')
    else:
        order_fields.append('id')

    today = timezone.localdate()
    items = []

    try:
        qs = Todo.objects.filter(user=user).order_by(*order_fields)[:limit]
    except Exception as e:
        logger.error('[AI Helper] Todo query failed: %s', e)
        return []

    for todo in qs:
        due = _pick_attr(todo, 'due_date', 'date', 'scheduled_for', 'deadline', 'due', default=None)
        completed = bool(_pick_attr(todo, 'completed', 'is_completed', default=False))
        due_date = None

        if isinstance(due, datetime):
            due_date = timezone.localtime(due).date()
        elif isinstance(due, date):
            due_date = due

        items.append({
            'id': getattr(todo, 'id', None),
            'title': getattr(todo, 'title', getattr(todo, 'name', '')),
            'description': getattr(todo, 'description', '') or '',
            'due': _to_iso(due),
            'completed': completed,
            'completed_at': _to_iso(_pick_attr(todo, 'completed_at', 'done_at', default=None)),
            'priority': _pick_attr(todo, 'priority', 'importance', default='normal'),
            'is_today': bool(due_date == today) if due_date else False,
            'is_overdue': bool(due_date and due_date < today and not completed),
        })

    return items


def calendar_payload(user, days_ahead=7, limit=20):
    if CalendarEvent is None:
        return []

    try:
        qs = CalendarEvent.objects.filter(user=user)
    except Exception:
        try:
            qs = CalendarEvent.objects.filter(owner=user)
        except Exception:
            return []

    field_names = {f.name for f in CalendarEvent._meta.fields}
    start_field = 'start_time' if 'start_time' in field_names else ('start' if 'start' in field_names else None)
    end_field = 'end_time' if 'end_time' in field_names else ('end' if 'end' in field_names else None)

    now = timezone.now()
    end = now + timedelta(days=days_ahead)

    if start_field:
        try:
            qs = qs.filter(**{
                f'{start_field}__gte': now,
                f'{start_field}__lte': end,
            })
        except Exception:
            pass

        try:
            qs = qs.order_by(start_field)
        except Exception:
            pass

    items = []
    for event in qs[:limit]:
        start_value = _pick_attr(event, 'start_time', 'start', 'start_date', default=None)
        end_value = _pick_attr(event, 'end_time', 'end', 'end_date', default=None)

        items.append({
            'id': getattr(event, 'id', None),
            'title': getattr(event, 'title', getattr(event, 'name', '')),
            'description': getattr(event, 'description', '') or '',
            'category': getattr(event, 'category', '') or '',
            'location': getattr(event, 'location', '') or '',
            'allDay': bool(_pick_attr(event, 'all_day', 'allDay', default=False)),
            'start': _to_iso(start_value),
            'end': _to_iso(end_value),
            'color': getattr(event, 'color', '') or '',
            'syncedToGoogle': bool(_pick_attr(event, 'synced_to_google', 'syncedToGoogle', default=False)),
        })

    return items


def detect_intent(message):
    lower_message = message.lower()
    if any(kw in lower_message for kw in ('to do list', 'tasks', 'my tasks')):
        return 'todos'
    if any(kw in lower_message for kw in ('schedule', 'google schedule', 'today plan')):
        return 'schedule'
    if any(kw in lower_message for kw in ('analyze', 'habit', 'productivity')):
        return 'analysis'
    return 'general_coach'


def build_ai_context(user, request, message, mode):
    intent = detect_intent(message)
    r_summary = routine_summary(user, limit=14)
    return {
        'mode': mode,
        'intent': intent,
        'current_time': timezone.localtime(timezone.now()).isoformat(),
        'message': message,
        'profile': profile_summary(user),
        'routine_summary': r_summary,
        'productivity_metrics': r_summary,
        'recent_routines': recent_routine_payload(user, request, limit=14),
        'todos': todos_payload(user, limit=30),
        'calendar_events': calendar_payload(user, days_ahead=7, limit=20),
    }


def build_prompt(context):
    intent = context.get('intent', 'general_coach')
    message = context.get('message', '')

    routines_count = len(context.get('recent_routines', []))
    todos_list = context.get('todos', [])
    todos_count = len(todos_list)
    events_list = context.get('calendar_events', [])
    events_count = len(events_list)
    r_summary = context.get('routine_summary', {})
    
    first_3_todos = [t.get('title', '') for t in todos_list[:3]]
    first_3_events = [e.get('title', '') for e in events_list[:3]]

    # Goal 5: Debug log requirements
    logger.info(
        "[AI DEBUG] Generating prompt context stats:\n"
        "- Count of routines: %d\n"
        "- Count of todos: %d\n"
        "- Count of calendar events: %d\n"
        "- Current intent: %s\n"
        "- First 3 todo titles: %s\n"
        "- First 3 event titles: %s\n"
        "- avgStudy: %s, avgMobile: %s, avgScore: %s",
        routines_count,
        todos_count,
        events_count,
        intent,
        first_3_todos,
        first_3_events,
        r_summary.get('avgStudy', 0.0),
        r_summary.get('avgMobile', 0.0),
        r_summary.get('avgScore', 0.0)
    )

    if intent == 'todos':
        task_block = (
            "The user is asking about their tasks/to-do list.\n"
            "Analyze the 'todos' and 'calendar_events' in the context.\n"
            "Provide conversational priority recommendations.\n"
            "Naturally mention their actual tasks. For example, explain what their highest priority is and why based on due dates and status. "
            "Point out overdue tasks naturally, and explain that clearing them helps. "
            "Finally, give a brief, highly specific suggestion on what to tackle first today."
        )
    elif intent == 'schedule':
        task_block = (
            "The user is asking about their schedule or today's plan.\n"
            "Analyze the 'calendar_events', 'todos', and 'routine_summary' in the context.\n"
            "Provide a natural daily schedule explanation.\n"
            "Walk through their day conversationally, referencing real events from their calendar and placing their tasks or study blocks around these events. "
            "Mention how this fits into their current habits. "
            "End with a concise, encouraging tip on how to stay on track today."
        )
    elif intent == 'analysis':
        task_block = (
            "The user is asking for habit/productivity analysis.\n"
            "Analyze 'routine_summary' and 'recent_routines' in the context.\n"
            "Provide conversational insights and observations.\n"
            "Share 3-5 short, naturally flowing insights backed by their actual numbers (average study hours, average mobile usage, streak, best score, productivity score trends). "
            "Mention exact values naturally, e.g., 'I noticed you studied 6 hours on average this week.' "
            "Suggest one practical next step to improve productivity or reduce mobile usage."
        )
    else:
        # general_coach
        task_block = (
            "Act as a personal AI productivity coach.\n"
            "Respond to the user's message using the provided context.\n"
            "Provide a coach-like conversation.\n"
            "Answer the user's question concisely. Naturally integrate the user's real todo titles, event titles, and routine numbers into your answer. "
            "Never give generic motivational or wellness advice (like 'drink water' or 'sleep 8 hours') unless directly supported by the context. "
            "Conclude with 1-2 practical next steps."
        )

    return f"""
You are a personal productivity coach.

Speak naturally as if chatting with the user.

Your task:
{task_block}

Hard rules:
1. Do not use markdown.
2. Do not use # headers.
3. Do not use ## headers.
4. Do not use ### headers.
5. Do not use code blocks.
6. Do not use report formatting or excessive bullet lists.
7. Use short paragraphs.
8. Use emojis sparingly when useful.
9. Reference actual user data (real tasks, real events, real productivity metrics).
10. Explain WHY you are making each recommendation.
11. Write like a human coach speaking directly to the user.
12. Use ONLY the supplied data in the CONTEXT. Never invent tasks, times, events, or habits.
13. If any data type (todos, calendar events, or routines) is empty or missing, state it naturally in the conversation (e.g., "I noticed you don't have any calendar events scheduled today") and suggest they add some.
14. Do not output generic filler text.
15. Keep the response concise: 150–300 words maximum. Mobile friendly. Easy to read.

CURRENT USER MESSAGE:
{message}

CONTEXT:
{json.dumps(context, default=_json_default, ensure_ascii=False, indent=2)}
""".strip()


def build_local_reply(context):
    todos = context.get('todos', [])
    events = context.get('calendar_events', [])
    summary = context.get('routine_summary', {})

    overdue = [t for t in todos if t.get('is_overdue')]
    today_todos = [t for t in todos if t.get('is_today') and not t.get('completed')]
    upcoming_todos = [t for t in todos if not t.get('completed') and not t.get('is_today') and not t.get('is_overdue')]

    lines = []
    lines.append("### Local AI Coach Reply")
    lines.append("Here is your local context-aware productivity briefing:")

    # 1. Check missing data
    missing_data = []
    if not todos:
        missing_data.append("Todos (tasks)")
    if not events:
        missing_data.append("Calendar events")
    if not summary or summary.get('totalLogs', 0) == 0:
        missing_data.append("Recent routine logs")

    if missing_data:
        lines.append(f"\n⚠️ **Missing Data Sources:** We could not locate any data for: {', '.join(missing_data)}. Please log some entries to get personalized AI advice.")

    # 2. Overdue Todos
    if overdue:
        lines.append("\n**⚠️ Overdue Tasks:**")
        for item in overdue[:5]:
            due_str = f" (due: {item.get('due')})" if item.get('due') else ""
            lines.append(f"- {item.get('title', 'Untitled task')}{due_str}")

    # 3. Today's Todos
    if today_todos:
        lines.append("\n**📅 Today's Tasks:**")
        for item in today_todos[:5]:
            lines.append(f"- {item.get('title', 'Untitled task')}")

    # 4. Next Calendar Event
    if events:
        next_event = events[0]
        lines.append("\n**⏰ Next Calendar Event:**")
        lines.append(
            f"- **{next_event.get('title', 'Untitled event')}** starting at {next_event.get('start', 'N/A')} (Category: {next_event.get('category', 'personal')})"
        )

    # 5. Routine Summary
    if summary and summary.get('totalLogs', 0) > 0:
        lines.append("\n**📊 Routine Summary (Last 14 Days):**")
        lines.append(f"- Average study time: {summary.get('avgStudy', 0.0)} hours/day")
        lines.append(f"- Average mobile usage: {summary.get('avgMobile', 0.0)} hours/day")
        lines.append(f"- Average productivity score: {summary.get('avgScore', 0.0)}/100")
        lines.append(f"- Current streak: {summary.get('currentStreak', 0)} days")
    else:
        lines.append("\n**📊 Routine Summary:**")
        lines.append("- No routine logs found to compute study, mobile usage, or streak metrics.")

    # 6. Specific Action
    lines.append("\n**🎯 Suggested Next Steps:**")
    actions = []
    if overdue:
        actions.append(f"Resolve your overdue task: '{overdue[0].get('title')}' immediately.")
    elif today_todos:
        actions.append(f"Work on today's task: '{today_todos[0].get('title')}' as your primary focus.")
    else:
        actions.append("Create some tasks (todos) or add events to plan your study sessions.")

    if summary and summary.get('avgMobile', 0.0) > 4:
        actions.append(f"Limit screen time today (your average mobile usage is high at {summary.get('avgMobile')} hours).")

    for act in actions:
        lines.append(f"- {act}")

    return "\n".join(lines)


# ── Views ─────────────────────────────────────────────────────────────────────

class GeneratePlanView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        logger.info('[AI] Request received — generate-plan')

        context = build_ai_context(
            user=request.user,
            request=request,
            message='Generate a daily routine and exam prep plan',
            mode='generate_plan',
        )

        if not _groq_available():
            logger.warning('[AI] GROQ_API_KEY not set — returning local fallback')
            return Response({
                'success': True,
                'plan': build_local_reply(context),
            })

        prompt = build_prompt(context)
        logger.info('[AI] Prompt generated — calling Groq')
        try:
            plan = generate_ai_response(prompt, clean=True)
            logger.info('[AI] Response received')
            return Response({'success': True, 'plan': plan})
        except Exception as exc:
            logger.exception('[AI] Error: %s', exc)
            return Response({'success': False, 'error': str(exc)}, status=500)


class AnalyzeHabitsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        logger.info('[AI] Request received — analyze-habits')

        context = build_ai_context(
            user=request.user,
            request=request,
            message='Analyze my habits and productivity patterns',
            mode='analyze_habits',
        )

        if not _groq_available():
            logger.warning('[AI] GROQ_API_KEY not set — returning local fallback')
            summary = context['routine_summary']
            analysis = (
                f"Average study is {summary.get('avgStudy', 0)} hrs, "
                f"mobile usage is {summary.get('avgMobile', 0)} hrs, "
                f"and average productivity score is {summary.get('avgScore', 0)}.\n\n"
                f"Next action: focus on one deep-work block, reduce mobile usage, and complete overdue todos first."
            )
            return Response({'success': True, 'analysis': analysis, 'data': analysis})

        prompt = build_prompt(context)
        logger.info('[AI] Prompt generated — calling Groq')
        try:
            analysis = generate_ai_response(prompt, clean=True)
            logger.info('[AI] Response received')
            return Response({'success': True, 'analysis': analysis, 'data': analysis})
        except Exception as exc:
            logger.exception('[AI] Error: %s', exc)
            return Response({'success': False, 'error': str(exc)}, status=500)


class ChatCoachView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        message = (request.data.get('message') or '').strip()
        if not message:
            return Response(
                {'success': False, 'error': 'Empty prompt messages received.'},
                status=400,
            )

        logger.info('[AI] Request received — chat-coach')

        context = build_ai_context(
            user=request.user,
            request=request,
            message=message,
            mode='chat',
        )

        if not _groq_available():
            logger.warning('[AI] GROQ_API_KEY not set — returning local fallback')
            return Response({
                'success': True,
                'reply': build_local_reply(context),
            })

        prompt = build_prompt(context)
        logger.info('[AI] Prompt generated — calling Groq')
        try:
            reply = generate_ai_response(prompt, clean=True)
            logger.info('[AI] Response received')
            return Response({'success': True, 'reply': reply, 'data': reply})
        except Exception as exc:
            logger.exception('[AI] Error: %s', exc)
            return Response({'success': False, 'error': str(exc)}, status=500)


class AiJobStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, job_id):
        try:
            job = AiJob.objects.get(
                id=job_id,
                user=request.user,
            )

            return Response({
                'job_id': job.id,
                'status': job.status,
                'result': job.result,
                'error': job.error,
            })

        except AiJob.DoesNotExist:
            return Response(
                {'error': 'Job not found'},
                status=404,
            )