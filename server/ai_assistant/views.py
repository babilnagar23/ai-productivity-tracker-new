import json

from django.conf import settings
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from routines.models import Routine
from routines.serializers import RoutineSerializer


def configured_model():
    api_key = getattr(settings, 'GEMINI_API_KEY', '')
    if not api_key or api_key == 'dummy_placeholder_key_replace_me':
        return None
    try:
        import google.generativeai as genai

        genai.configure(api_key=api_key)
        return genai.GenerativeModel(getattr(settings, 'GEMINI_MODEL', 'gemini-2.5-flash'))
    except Exception:
        return None


def recent_routine_payload(user, request, limit=7):
    routines = list(Routine.objects.filter(user=user).order_by('-date')[:limit])
    return RoutineSerializer(routines, many=True, context={'request': request}).data


def metrics_summary(user):
    routines = list(Routine.objects.filter(user=user).order_by('-date')[:7])
    if not routines:
        return {'avgStudy': 0, 'avgMobile': 0, 'avgScore': 0}
    return {
        'avgStudy': round(sum(routine.study_hours for routine in routines) / len(routines), 1),
        'avgMobile': round(sum(routine.mobile_usage for routine in routines) / len(routines), 1),
        'avgScore': round(sum(routine.productivity_score for routine in routines) / len(routines), 1),
    }


class GeneratePlanView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        payload = recent_routine_payload(request.user, request)
        summary = metrics_summary(request.user)
        model = configured_model()
        if not model:
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
        response = model.generate_content(prompt)
        return Response({'success': True, 'plan': response.text})


class AnalyzeHabitsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        payload = recent_routine_payload(request.user, request)
        summary = metrics_summary(request.user)
        model = configured_model()
        if not model:
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
        response = model.generate_content(prompt)
        return Response({'success': True, 'analysis': response.text, 'data': response.text})


class ChatCoachView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        message = (request.data.get('message') or '').strip()
        if not message:
            return Response({'success': False, 'error': 'Empty prompt messages received.'}, status=400)

        payload = recent_routine_payload(request.user, request, limit=5)
        model = configured_model()
        if not model:
            lower = message.lower()
            if 'procrastinate' in lower or 'lazy' in lower or 'study' in lower:
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
        response = model.generate_content(prompt)
        return Response({'success': True, 'reply': response.text})
