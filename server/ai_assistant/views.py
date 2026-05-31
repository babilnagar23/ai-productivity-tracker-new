import json
import logging

from django.conf import settings
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from common.groq_client import generate_ai_response
from routines.models import Routine
from routines.serializers import RoutineSerializer

logger = logging.getLogger('ai')


# ── Helpers ───────────────────────────────────────────────────────────────────

def recent_routine_payload(user, request, limit=7):
    routines = list(Routine.objects.filter(user=user).order_by('-date')[:limit])
    return RoutineSerializer(routines, many=True, context={'request': request}).data


def metrics_summary(user):
    routines = list(Routine.objects.filter(user=user).order_by('-date')[:7])
    if not routines:
        return {'avgStudy': 0, 'avgMobile': 0, 'avgScore': 0}
    return {
        'avgStudy': round(sum(r.study_hours for r in routines) / len(routines), 1),
        'avgMobile': round(sum(r.mobile_usage for r in routines) / len(routines), 1),
        'avgScore': round(sum(r.productivity_score for r in routines) / len(routines), 1),
    }


def _groq_available():
    return bool(getattr(settings, 'GROQ_API_KEY', ''))


# ── Views ─────────────────────────────────────────────────────────────────────

class GeneratePlanView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        logger.info('[AI] Request received — generate-plan')
        payload = recent_routine_payload(request.user, request)
        summary = metrics_summary(request.user)

        if not _groq_available():
            logger.warning('[AI] GROQ_API_KEY not set — returning static fallback')
            plan = (
                f"Neural routine blueprint for {request.user.first_name or request.user.email}:\n"
                f"- Deep work: 2 focused study blocks based on your {summary['avgStudy']} hr average.\n"
                "- Fitness: keep exercise before the highest-cognitive study session.\n"
                f"- Attention guard: keep mobile usage below {max(summary['avgMobile'] - 0.5, 1)} hrs.\n"
                "- Evening close: reflect, update tomorrow's target date, and sleep consistently."
            )
            return Response({'success': True, 'plan': plan})

        prompt = (
            "You are an AI productivity mentor. Create a concise daily routine and exam prep plan "
            f"for this user using recent logs: {json.dumps(payload)}"
        )
        logger.info('[AI] Prompt generated — calling Groq')
        try:
            plan = generate_ai_response(prompt)
            logger.info('[AI] Response received')
            return Response({'success': True, 'plan': plan})
        except Exception as exc:
            logger.exception('[AI] Error: %s', exc)
            return Response({'success': False, 'error': str(exc)}, status=500)


class AnalyzeHabitsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        logger.info('[AI] Request received — analyze-habits')
        payload = recent_routine_payload(request.user, request)
        summary = metrics_summary(request.user)

        if not _groq_available():
            logger.warning('[AI] GROQ_API_KEY not set — returning static fallback')
            analysis = (
                f"Average score is {summary['avgScore']}%. Study averages {summary['avgStudy']} hrs, "
                f"with mobile usage around {summary['avgMobile']} hrs. Push one high-focus block earlier "
                "and keep evening screen time predictable."
            )
            return Response({'success': True, 'analysis': analysis, 'data': analysis})

        prompt = (
            "Analyze these productivity logs and return 3 short behavioral insights. "
            f"Logs: {json.dumps(payload)}"
        )
        logger.info('[AI] Prompt generated — calling Groq')
        try:
            analysis = generate_ai_response(prompt)
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
        payload = recent_routine_payload(request.user, request, limit=5)

        if not _groq_available():
            logger.warning('[AI] GROQ_API_KEY not set — returning static fallback')
            lower = message.lower()
            if any(kw in lower for kw in ('procrastinate', 'lazy', 'study')):
                reply = (
                    "Use the 5-minute start rule: open the material, set one tiny target, and begin "
                    "before negotiating with yourself. Momentum is the point."
                )
            else:
                reply = (
                    "I would prioritize one deep-work block, a firm mobile boundary, and a short end-of-day "
                    "review. Keep the system small enough to repeat tomorrow."
                )
            return Response({'success': True, 'reply': reply})

        prompt = (
            "Respond as a concise, practical AI productivity mentor. "
            f"Recent routine context: {json.dumps(payload)}\nUser message: {message}"
        )
        logger.info('[AI] Prompt generated — calling Groq')
        try:
            reply = generate_ai_response(prompt)
            logger.info('[AI] Response received')
            return Response({'success': True, 'reply': reply})
        except Exception as exc:
            logger.exception('[AI] Error: %s', exc)
            return Response({'success': False, 'error': str(exc)}, status=500)
