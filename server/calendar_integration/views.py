from datetime import datetime, timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from routines.models import Routine

from .models import GoogleCalendarConnection

SCOPES = ['https://www.googleapis.com/auth/calendar.events']


def optional_google_imports():
    try:
        from google.oauth2.credentials import Credentials
        from google_auth_oauthlib.flow import Flow
        from googleapiclient.discovery import build

        return Credentials, Flow, build
    except Exception:
        return None, None, None


def calendar_service(connection):
    Credentials, _, build = optional_google_imports()
    if not Credentials or not build:
        return None
    credentials = Credentials(
        token=connection.access_token,
        refresh_token=connection.refresh_token,
        token_uri=connection.token_uri,
        client_id=settings.GOOGLE_CLIENT_ID,
        client_secret=settings.GOOGLE_CLIENT_SECRET,
        scopes=connection.scopes or SCOPES,
    )
    return build('calendar', 'v3', credentials=credentials)


class CalendarStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        connection = GoogleCalendarConnection.objects.filter(user=request.user).first()
        return Response({'success': True, 'connected': bool(connection and connection.connected)})


class CalendarAuthUrlView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        _, Flow, _ = optional_google_imports()
        if not Flow:
            return Response(
                {'success': False, 'error': 'Install google-api-python-client and google-auth-oauthlib to enable Google Calendar OAuth.'},
                status=501,
            )
        if not settings.GOOGLE_CLIENT_ID or not settings.GOOGLE_CLIENT_SECRET:
            return Response({'success': False, 'error': 'Google OAuth credentials are not configured.'}, status=400)
        flow = Flow.from_client_config(
            {
                'web': {
                    'client_id': settings.GOOGLE_CLIENT_ID,
                    'client_secret': settings.GOOGLE_CLIENT_SECRET,
                    'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
                    'token_uri': 'https://oauth2.googleapis.com/token',
                    'redirect_uris': [settings.GOOGLE_REDIRECT_URI],
                }
            },
            scopes=SCOPES,
            redirect_uri=settings.GOOGLE_REDIRECT_URI,
        )
        auth_url, state = flow.authorization_url(access_type='offline', include_granted_scopes='true', prompt='consent')
        request.session['google_oauth_state'] = state
        return Response({'success': True, 'authUrl': auth_url})


class CalendarCallbackView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        code = request.data.get('code')
        if not code:
            return Response({'success': False, 'error': 'OAuth code is required.'}, status=400)
        _, Flow, _ = optional_google_imports()
        if not Flow:
            return Response({'success': False, 'error': 'Google OAuth dependencies are not installed.'}, status=501)
        flow = Flow.from_client_config(
            {
                'web': {
                    'client_id': settings.GOOGLE_CLIENT_ID,
                    'client_secret': settings.GOOGLE_CLIENT_SECRET,
                    'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
                    'token_uri': 'https://oauth2.googleapis.com/token',
                    'redirect_uris': [settings.GOOGLE_REDIRECT_URI],
                }
            },
            scopes=SCOPES,
            redirect_uri=settings.GOOGLE_REDIRECT_URI,
        )
        flow.fetch_token(code=code)
        credentials = flow.credentials
        expiry = credentials.expiry
        if expiry and timezone.is_naive(expiry):
            expiry = timezone.make_aware(expiry)
        GoogleCalendarConnection.objects.update_or_create(
            user=request.user,
            defaults={
                'access_token': credentials.token or '',
                'refresh_token': credentials.refresh_token or '',
                'token_uri': credentials.token_uri or 'https://oauth2.googleapis.com/token',
                'scopes': list(credentials.scopes or SCOPES),
                'expiry': expiry,
            },
        )
        return Response({'success': True, 'connected': True})


class CalendarSyncView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        connection = GoogleCalendarConnection.objects.filter(user=request.user).first()
        if not connection:
            return Response({'success': False, 'error': 'Google Calendar is not connected.'}, status=400)
        service = calendar_service(connection)
        if not service:
            return Response({'success': False, 'error': 'Google Calendar client dependencies are not installed.'}, status=501)

        routines = Routine.objects.filter(user=request.user).order_by('-date')[:14]
        created = 0
        for routine in routines:
            start = datetime.combine(routine.date, datetime.strptime(routine.wake_time, '%H:%M').time())
            start = timezone.make_aware(start) if timezone.is_naive(start) else start
            end = start + timedelta(minutes=30)
            event = {
                'summary': 'ProductiveAI Daily Routine Review',
                'description': f'Score: {routine.productivity_score}%. Notes: {routine.notes}',
                'start': {'dateTime': start.isoformat()},
                'end': {'dateTime': end.isoformat()},
                'reminders': {'useDefault': False, 'overrides': [{'method': 'popup', 'minutes': 10}]},
            }
            service.events().insert(calendarId=connection.calendar_id, body=event).execute()
            created += 1
        return Response({'success': True, 'created': created})


class ReminderView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        connection = GoogleCalendarConnection.objects.filter(user=request.user).first()
        if not connection:
            return Response({'success': False, 'error': 'Google Calendar is not connected.'}, status=400)
        service = calendar_service(connection)
        if not service:
            return Response({'success': False, 'error': 'Google Calendar client dependencies are not installed.'}, status=501)

        title = request.data.get('title', 'Productivity reminder')
        date = request.data.get('date') or timezone.localdate().isoformat()
        time_value = request.data.get('time', '20:00')
        start = timezone.make_aware(datetime.strptime(f'{date} {time_value}', '%Y-%m-%d %H:%M'))
        event = {
            'summary': title,
            'description': request.data.get('description', 'Created by ProductiveAI.'),
            'start': {'dateTime': start.isoformat()},
            'end': {'dateTime': (start + timedelta(minutes=30)).isoformat()},
            'recurrence': request.data.get('recurrence', []),
            'reminders': {'useDefault': False, 'overrides': [{'method': 'popup', 'minutes': int(request.data.get('minutesBefore', 10))}]},
        }
        result = service.events().insert(calendarId=connection.calendar_id, body=event).execute()
        return Response({'success': True, 'eventId': result.get('id'), 'htmlLink': result.get('htmlLink')})
