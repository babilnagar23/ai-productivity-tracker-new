"""
calendar_integration views — thin view layer.

Each view:
1. Validates the incoming request
2. Delegates business logic to a service
3. Returns a standardized API response

No raw Google API code, sync logic, or AI prompt building belongs here.
"""
import logging
from datetime import timedelta

from django.conf import settings
from django.shortcuts import redirect
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .exceptions import (
    AIScheduleError,
    CalendarSyncError,
    EventNotFound,
    GoogleAuthError,
    GoogleDependencyMissing,
)
from .models import (
    GoogleCalendarConnection,
    NotificationSettings,
    SyncLog,
)
from .services.ai_schedule_service import apply_ai_schedule, generate_ai_schedule
from .services.event_service import (
    create_event,
    delete_event,
    list_events,
    serialize_event,
    update_event,
)
from .services.insight_service import generate_fresh_insights, get_cached_insights
from .services.oauth_service import (
    disconnect,
    exchange_code_for_tokens,
    generate_auth_url,
    save_connection,
)
from .services.sync_service import pull_google_events_to_local, sync_routines_to_google

logger = logging.getLogger('calendar')


# ── OAuth ──────────────────────────────────────────────────────────────────────

class CalendarStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        connection = GoogleCalendarConnection.objects.filter(user=request.user).first()
        last_sync = SyncLog.objects.filter(user=request.user).first()
        return Response({
            'success': True,
            'connected': bool(connection and connection.connected),
            'googleEmail': connection.google_email if connection else '',
            'lastSynced': last_sync.synced_at.isoformat() if last_sync else None,
        })


class CalendarAuthUrlView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            for_mobile = request.query_params.get('client') == 'mobile'
            auth_url = generate_auth_url(for_mobile=for_mobile)
            return Response({'success': True, 'authUrl': auth_url})
        except GoogleDependencyMissing as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_501_NOT_IMPLEMENTED)
        except GoogleAuthError as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_400_BAD_REQUEST)


class CalendarCallbackView(APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAuthenticated()]

    def get(self, request):
        """HTTP GET callback from Google — redirect to the appropriate frontend/mobile URL."""
        code = request.GET.get('code')
        state = request.GET.get('state', '')

        if state.endswith('_mobile'):
            if code:
                return redirect(f'productivityapp://calendar/callback?code={code}')
            return redirect('productivityapp://calendar')

        frontend_url = getattr(settings, 'FRONTEND_URL', 'http://localhost:5173')
        if code:
            return redirect(f'{frontend_url}/auth/google/callback?code={code}')
        return redirect(f'{frontend_url}/calendar')

    def post(self, request):
        """Exchange the OAuth code for tokens and store the connection."""
        code = request.data.get('code')
        if not code:
            return Response(
                {'success': False, 'error': 'OAuth code is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            token_data = exchange_code_for_tokens(code)
            connection = save_connection(request.user, token_data)
            logger.info('[Calendar] OAuth completed for user %s', request.user.id)
            return Response({
                'success': True,
                'connected': True,
                'googleEmail': connection.google_email,
            })
        except GoogleDependencyMissing as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_501_NOT_IMPLEMENTED)
        except GoogleAuthError as exc:
            logger.warning('[Calendar] OAuth failed for user %s: %s', request.user.id, exc)
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_400_BAD_REQUEST)


class CalendarDisconnectView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        disconnect(request.user)
        return Response({'success': True, 'connected': False})


# ── Sync ───────────────────────────────────────────────────────────────────────

class CalendarSyncView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from routines.models import Routine
        routines = Routine.objects.filter(user=request.user).order_by('-date')[:14]
        try:
            created = sync_routines_to_google(request.user, routines)
            return Response({'success': True, 'created': created})
        except CalendarSyncError as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        except GoogleDependencyMissing as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_501_NOT_IMPLEMENTED)


class CalendarFetchGoogleView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            result = pull_google_events_to_local(request.user)
            return Response({'success': True, **result})
        except CalendarSyncError as exc:
            err = str(exc)
            status_code = status.HTTP_400_BAD_REQUEST if 'not connected' in err.lower() else status.HTTP_500_INTERNAL_SERVER_ERROR
            return Response({'success': False, 'error': err}, status=status_code)
        except GoogleDependencyMissing as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_501_NOT_IMPLEMENTED)


class SyncLogsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        logs = SyncLog.objects.filter(user=request.user).order_by('-synced_at')[:20]
        return Response({
            'success': True,
            'logs': [
                {
                    'id': l.id,
                    'direction': l.direction,
                    'status': l.status,
                    'eventsSynced': l.events_synced,
                    'errorMessage': l.error_message,
                    'syncedAt': l.synced_at.isoformat(),
                }
                for l in logs
            ],
        })


# ── Reminders ─────────────────────────────────────────────────────────────────

class ReminderView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from datetime import datetime
        from .services.google_calendar_service import build_calendar_service
        from .exceptions import CalendarSyncError, GoogleDependencyMissing

        connection = GoogleCalendarConnection.objects.filter(user=request.user).first()
        if not connection or not connection.connected:
            return Response(
                {'success': False, 'error': 'Google Calendar is not connected.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            service = build_calendar_service(connection)
        except GoogleDependencyMissing as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_501_NOT_IMPLEMENTED)
        except CalendarSyncError as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        title = request.data.get('title', 'Productivity reminder')
        date = request.data.get('date') or timezone.localdate().isoformat()
        time_value = request.data.get('time', '20:00')
        start = timezone.make_aware(datetime.strptime(f'{date} {time_value}', '%Y-%m-%d %H:%M'))
        event_body = {
            'summary': title,
            'description': request.data.get('description', 'Created by Productivity Tracker.'),
            'start': {'dateTime': start.isoformat()},
            'end': {'dateTime': (start + timedelta(minutes=30)).isoformat()},
            'recurrence': request.data.get('recurrence', []),
            'reminders': {
                'useDefault': False,
                'overrides': [{'method': 'popup', 'minutes': int(request.data.get('minutesBefore', 10))}],
            },
        }
        try:
            result = service.events().insert(calendarId=connection.calendar_id, body=event_body).execute()
            logger.info('[Calendar] Reminder created for user %s: %s', request.user.id, result.get('id'))
            return Response({'success': True, 'eventId': result.get('id'), 'htmlLink': result.get('htmlLink')})
        except Exception as exc:
            logger.error('[Calendar] Reminder creation failed for user %s: %s', request.user.id, exc)
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ── Events CRUD ───────────────────────────────────────────────────────────────

class CalendarEventsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = list_events(
            user=request.user,
            start_str=request.query_params.get('start'),
            end_str=request.query_params.get('end'),
            date_str=request.query_params.get('date'),
        )
        return Response({'success': True, 'events': [serialize_event(e) for e in qs]})

    def post(self, request):
        try:
            has_google = GoogleCalendarConnection.objects.filter(
                user=request.user,
            ).values_list('refresh_token', 'access_token').first()
            push = bool(has_google and any(has_google))
            event = create_event(request.user, request.data, push_to_google=push)
            return Response({'success': True, 'event': serialize_event(event)}, status=status.HTTP_201_CREATED)
        except (KeyError, ValueError) as exc:
            return Response({'success': False, 'error': f'Invalid dates: {exc}'}, status=status.HTTP_400_BAD_REQUEST)


class CalendarEventDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            from .models import CalendarEvent
            event = CalendarEvent.objects.get(pk=pk, user=request.user)
            return Response({'success': True, 'event': serialize_event(event)})
        except Exception:
            return Response({'success': False, 'error': 'Event not found'}, status=status.HTTP_404_NOT_FOUND)

    def put(self, request, pk):
        return self._update(request, pk)

    def patch(self, request, pk):
        return self._update(request, pk)

    def _update(self, request, pk):
        try:
            has_google = GoogleCalendarConnection.objects.filter(
                user=request.user,
            ).values_list('refresh_token', 'access_token').first()
            push = bool(has_google and any(has_google))
            event = update_event(request.user, pk, request.data, push_to_google=push)
            return Response({'success': True, 'event': serialize_event(event)})
        except EventNotFound:
            return Response({'success': False, 'error': 'Event not found'}, status=status.HTTP_404_NOT_FOUND)
        except ValueError as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        try:
            has_google = GoogleCalendarConnection.objects.filter(
                user=request.user,
            ).values_list('refresh_token', 'access_token').first()
            delete_from_google = bool(has_google and any(has_google))
            delete_event(request.user, pk, delete_from_google=delete_from_google)
            return Response({'success': True, 'deleted': True})
        except EventNotFound:
            return Response({'success': False, 'error': 'Event not found'}, status=status.HTTP_404_NOT_FOUND)


# ── AI Scheduler ──────────────────────────────────────────────────────────────

class AISchedulerView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        prompt = request.data.get('prompt', '').strip()
        if not prompt:
            return Response(
                {'success': False, 'error': 'Prompt is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not getattr(settings, 'GROQ_API_KEY', ''):
            return Response(
                {'success': False, 'error': 'GROQ_API_KEY is not configured.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )
        try:
            schedule, plan_data = generate_ai_schedule(request.user, prompt)
            return Response({
                'success': True,
                'scheduleId': schedule.id,
                'planTitle': plan_data.get('planTitle', ''),
                'planSummary': plan_data.get('planSummary', ''),
                'insights': plan_data.get('insights', []),
                'events': plan_data.get('events', []),
            })
        except AIScheduleError as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AIScheduleApplyView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, schedule_id):
        sync_to_google = request.data.get('syncToGoogle', False)
        try:
            created_events = apply_ai_schedule(request.user, schedule_id, sync_to_google=sync_to_google)
            return Response({
                'success': True,
                'created': len(created_events),
                'events': created_events,
            })
        except AIScheduleError as exc:
            err = str(exc)
            status_code = status.HTTP_404_NOT_FOUND if 'not found' in err.lower() else status.HTTP_500_INTERNAL_SERVER_ERROR
            return Response({'success': False, 'error': err}, status=status_code)


# ── AI Insights ───────────────────────────────────────────────────────────────

class AIInsightsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Return recent cached insights."""
        insights = get_cached_insights(request.user)
        return Response({'success': True, 'insights': insights})

    def post(self, request):
        """Generate fresh AI insights via Groq."""
        try:
            insights = generate_fresh_insights(request.user)
            if not insights:
                return Response({
                    'success': True,
                    'insights': [],
                    'message': 'No routine data yet.',
                })
            return Response({'success': True, 'insights': insights})
        except ValueError as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_501_NOT_IMPLEMENTED)
        except AIScheduleError as exc:
            return Response({'success': False, 'error': str(exc)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ── Analytics ─────────────────────────────────────────────────────────────────

class ProductivityHeatmapView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Return per-day productivity scores and calendar event density."""
        from .models import CalendarEvent
        from routines.models import Routine

        days = int(request.query_params.get('days', 30))
        since = timezone.now() - timedelta(days=days)

        routines = Routine.objects.filter(user=request.user, date__gte=since.date())
        events = CalendarEvent.objects.filter(user=request.user, start_time__gte=since)

        heatmap = {
            str(r.date): {
                'score': r.productivity_score,
                'studyHours': r.study_hours,
                'exercise': r.exercise_completed,
                'sleepTime': r.sleep_time,
                'wakeTime': r.wake_time,
                'mobileUsage': r.mobile_usage,
            }
            for r in routines
        }

        event_density = {}
        for e in events:
            day_key = str(e.start_time.date())
            event_density[day_key] = event_density.get(day_key, 0) + 1

        scores = [r.productivity_score for r in routines]
        avg_score = round(sum(scores) / len(scores), 1) if scores else 0
        best_day = max(heatmap, key=lambda d: heatmap[d]['score'], default=None)

        hour_counts = [0] * 24
        for e in events:
            hour_counts[e.start_time.hour] += 1
        peak_hour = hour_counts.index(max(hour_counts)) if any(hour_counts) else 9

        return Response({
            'success': True,
            'heatmap': heatmap,
            'eventDensity': event_density,
            'stats': {
                'avgProductivityScore': avg_score,
                'bestDay': best_day,
                'totalEvents': events.count(),
                'peakHour': peak_hour,
                'streak': self._calc_streak(routines),
            },
        })

    @staticmethod
    def _calc_streak(routines):
        if not routines:
            return 0
        dates = sorted({r.date for r in routines}, reverse=True)
        streak = 0
        expected = timezone.now().date()
        for d in dates:
            if d == expected:
                streak += 1
                expected -= timedelta(days=1)
            else:
                break
        return streak


# ── Notification Settings ─────────────────────────────────────────────────────

class NotificationSettingsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        obj, _ = NotificationSettings.objects.get_or_create(user=request.user)
        return Response({
            'success': True,
            'settings': {
                'browserNotifications': obj.browser_notifications,
                'emailReminders': obj.email_reminders,
                'eventRemindersMinutes': obj.event_reminders_minutes,
                'dailySummary': obj.daily_summary,
                'aiSuggestions': obj.ai_suggestions,
                # Flutter-compatible snake_case aliases
                'daily_summary': obj.daily_summary,
                'event_reminders': obj.browser_notifications,
                'event_reminders_minutes': obj.event_reminders_minutes,
                'ai_suggestions': obj.ai_suggestions,
            },
        })

    def post(self, request):
        return self._update(request)

    def patch(self, request):
        return self._update(request)

    def _update(self, request):
        obj, _ = NotificationSettings.objects.get_or_create(user=request.user)
        data = request.data

        if 'browserNotifications' in data:
            obj.browser_notifications = data['browserNotifications']
        if 'event_reminders' in data:
            obj.browser_notifications = data['event_reminders']
        if 'emailReminders' in data:
            obj.email_reminders = data['emailReminders']
        if 'eventRemindersMinutes' in data or 'event_reminders_minutes' in data:
            obj.event_reminders_minutes = data.get('eventRemindersMinutes', data.get('event_reminders_minutes', obj.event_reminders_minutes))
        if 'dailySummary' in data or 'daily_summary' in data:
            obj.daily_summary = data.get('dailySummary', data.get('daily_summary', obj.daily_summary))
        if 'aiSuggestions' in data or 'ai_suggestions' in data:
            obj.ai_suggestions = data.get('aiSuggestions', data.get('ai_suggestions', obj.ai_suggestions))
        if 'vapidSubscription' in data:
            obj.vapid_subscription = data['vapidSubscription']

        obj.save()
        return Response({'success': True})


# ── Webhook ───────────────────────────────────────────────────────────────────

class WebhookView(APIView):
    """Receive Google Calendar push notifications."""
    permission_classes = []  # Google sends unauthenticated push notifications

    def post(self, request):
        resource_state = request.headers.get('X-Goog-Resource-State', '')
        channel_id = request.headers.get('X-Goog-Channel-Id', '')

        logger.debug('[Calendar] Webhook received: state=%s channel=%s', resource_state, channel_id)

        if resource_state == 'sync':
            return Response(status=status.HTTP_200_OK)

        # Production: look up user by channel_id and trigger a pull sync
        return Response(status=status.HTTP_200_OK)
