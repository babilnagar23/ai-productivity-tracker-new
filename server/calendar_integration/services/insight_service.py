"""
Insight Service — AI-powered productivity insights generation.

Responsible for:
  - Building Groq prompts from user routine/calendar data
  - Generating and persisting ProductivityInsight records
  - Returning cached or freshly generated insights
"""
import logging
from datetime import timedelta

from django.utils import timezone

from ..exceptions import AIScheduleError
from ..models import CalendarEvent, ProductivityInsight

logger = logging.getLogger('calendar')


def _build_insights_prompt(user) -> str:
    """Build the Groq prompt for productivity insight generation."""
    from routines.models import Routine

    routines = Routine.objects.filter(user=user).order_by('-date')[:14]
    if not routines:
        return None

    routine_summary = '\n'.join([
        f"- {r.date}: score={r.productivity_score}%, study={r.study_hours}h, "
        f"sleep={r.sleep_time}-{r.wake_time}, mobile={r.mobile_usage}h, exercise={r.exercise_completed}"
        for r in routines
    ])

    calendar_events_count = CalendarEvent.objects.filter(
        user=user,
        start_time__gte=timezone.now() - timedelta(days=14),
    ).count()

    return f"""Analyze this user's productivity data and generate personalized AI insights.

Routine data (last 14 days):
{routine_summary}

Calendar events logged: {calendar_events_count}
Today: {timezone.now().strftime('%Y-%m-%d')}

Generate exactly 6 unique, actionable insights. Return ONLY valid JSON:
{{
  "insights": [
    {{
      "type": "peak_hours|burnout_risk|consistency|sleep_impact|exercise_impact|focus_pattern|general",
      "title": "Short punchy title (max 8 words)",
      "body": "Detailed insight with specific data reference (max 25 words)",
      "icon": "zap|brain|moon|flame|heart|clock|trending-up|alert-triangle",
      "score": null
    }}
  ]
}}

Be specific, data-driven, and motivating. Reference actual numbers from the data."""


def get_cached_insights(user) -> list:
    """Return the most recent cached insights for a user."""
    insights = ProductivityInsight.objects.filter(user=user)[:8]
    return [
        {
            'id': i.id,
            'type': i.insight_type,
            'title': i.title,
            'body': i.body,
            'icon': i.icon,
            'score': i.score,
            'generatedAt': i.generated_at.isoformat(),
        }
        for i in insights
    ]


def generate_fresh_insights(user) -> list:
    """
    Generate new productivity insights via Groq and persist them.

    Returns:
        list of serialized insight dicts

    Raises:
        AIScheduleError: no routine data, or AI call/JSON parse failed
        ValueError: GROQ_API_KEY not configured
    """
    from django.conf import settings
    from common.groq_client import generate_ai_json
    from routines.models import Routine

    if not getattr(settings, 'GROQ_API_KEY', ''):
        raise ValueError('GROQ_API_KEY is not configured.')

    if not Routine.objects.filter(user=user).exists():
        return []

    prompt = _build_insights_prompt(user)
    if not prompt:
        return []

    try:
        data = generate_ai_json(prompt, max_tokens=2000)
    except Exception as exc:
        logger.error('[Calendar] Insight generation failed for user %s: %s', user.id, exc)
        raise AIScheduleError(f'AI insight generation failed: {exc}') from exc

    # Replace old insights with fresh ones
    ProductivityInsight.objects.filter(user=user).delete()

    saved = []
    for ins in data.get('insights', []):
        obj = ProductivityInsight.objects.create(
            user=user,
            insight_type=ins.get('type', 'general'),
            title=ins.get('title', ''),
            body=ins.get('body', ''),
            icon=ins.get('icon', 'sparkles'),
            score=ins.get('score'),
        )
        saved.append({
            'id': obj.id,
            'type': obj.insight_type,
            'title': obj.title,
            'body': obj.body,
            'icon': obj.icon,
            'score': obj.score,
            'generatedAt': obj.generated_at.isoformat(),
        })

    logger.info('[Calendar] Generated %d insights for user %s', len(saved), user.id)
    return saved
