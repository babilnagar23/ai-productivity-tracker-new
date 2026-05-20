from datetime import timedelta

from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from routines.models import Routine
from routines.serializers import RoutineSerializer
from users.defaults import DEFAULT_CONFIG


def user_config(user):
    return getattr(user.profile, 'custom_config', None) or DEFAULT_CONFIG


def current_streak(routines):
    dates = {routine.date for routine in routines}
    day = timezone.localdate()
    streak = 0
    while day in dates:
        streak += 1
        day -= timedelta(days=1)
    return streak


def score_breakdown(routines):
    scores = [routine.productivity_score for routine in routines]
    return {
        'excellent': len([score for score in scores if score >= 80]),
        'steady': len([score for score in scores if 50 <= score < 80]),
        'needsFocus': len([score for score in scores if score < 50]),
    }


class WeeklyAnalyticsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        routines = Routine.objects.filter(user=request.user).order_by('date')
        recent = list(routines)[-7:]
        return Response({'success': True, 'data': RoutineSerializer(recent, many=True, context={'request': request}).data})


class FullAnalyticsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        config = user_config(request.user)
        routines = list(Routine.objects.filter(user=request.user).order_by('-date', '-created_at'))
        serialized = RoutineSerializer(routines, many=True, context={'request': request}).data
        total = len(routines)
        avg_score = round(sum(routine.productivity_score for routine in routines) / total, 1) if total else 0
        best_score = max((routine.productivity_score for routine in routines), default=0)

        checklist_rates = {}
        for checklist in config.get('coreChecklists', []):
            checklist_id = checklist['id']
            completed = sum(1 for routine in routines if (routine.core_checklists or {}).get(checklist_id, False))
            checklist_rates[checklist_id] = {
                'title': checklist['title'],
                'completed': completed,
                'total': total,
                'rate': round((completed / total) * 100, 1) if total else 0,
            }

        heatmap = [
            {
                'date': routine.date.isoformat(),
                'score': routine.productivity_score,
                'completed': sum(1 for value in (routine.core_checklists or {}).values() if value),
            }
            for routine in sorted(routines, key=lambda item: item.date)
        ]

        sleep_hours = []
        for routine in routines:
            try:
                sleep_hours.append(int(str(routine.sleep_time).split(':')[0]))
            except (TypeError, ValueError):
                continue
        avg_sleep_hour = round(sum(sleep_hours) / len(sleep_hours), 1) if sleep_hours else 0

        study_vs_mobile = [
            {
                'date': routine.date.isoformat(),
                'studyHours': routine.study_hours,
                'mobileUsage': routine.mobile_usage,
                'focusRatio': round(routine.study_hours / max(routine.mobile_usage, 0.5), 2),
            }
            for routine in sorted(routines, key=lambda item: item.date)
        ]

        return Response({
            'success': True,
            'config': {
                'coreChecklists': config.get('coreChecklists', []),
                'coreMetrics': config.get('coreMetrics', []),
            },
            'stats': {
                'totalLogs': total,
                'avgScore': avg_score,
                'bestScore': best_score,
                'checklistRates': checklist_rates,
                'currentStreak': current_streak(routines),
                'scoreBreakdown': score_breakdown(routines),
                'avgSleepHour': avg_sleep_hour,
            },
            'behavioral': {
                'habitHeatmap': heatmap,
                'studyVsMobile': study_vs_mobile,
                'sleepConsistency': {
                    'averageSleepHour': avg_sleep_hour,
                    'variance': round(max(sleep_hours) - min(sleep_hours), 1) if len(sleep_hours) > 1 else 0,
                },
            },
            'data': serialized,
        })


class InsightsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        routines = list(Routine.objects.filter(user=request.user).order_by('-date')[:14])
        if not routines:
            return Response({'success': True, 'insights': ['Start with one daily log to unlock behavioral insights.']})
        avg_score = round(sum(routine.productivity_score for routine in routines) / len(routines), 1)
        avg_study = round(sum(routine.study_hours for routine in routines) / len(routines), 1)
        avg_mobile = round(sum(routine.mobile_usage for routine in routines) / len(routines), 1)
        insights = [
            f'Your recent productivity average is {avg_score}%.',
            f'Study time is averaging {avg_study} hrs while mobile usage is {avg_mobile} hrs.',
            'Protect the first focus block of the day when mobile usage starts rising.',
        ]
        return Response({'success': True, 'insights': insights})
