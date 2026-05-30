import json
from datetime import datetime, timedelta

import google.generativeai as genai
from django.conf import settings
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from routines.models import Routine

from .models import (
    AISchedule,
    CalendarEvent,
    GoogleCalendarConnection,
    NotificationSettings,
    ProductivityInsight,
    SyncLog,
)

SCOPES = [
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/userinfo.email',
    'openid',
]

COLOR_MAP = {
    'blue': '#3B82F6',
    'purple': '#8B5CF6',
    'green': '#10B981',
    'pink': '#EC4899',
    'orange': '#F59E0B',
    'cyan': '#06B6D4',
    'red': '#EF4444',
}

GOOGLE_COLOR_MAP = {
    'blue': '9',
    'purple': '3',
    'green': '2',
    'pink': '4',
    'orange': '6',
    'cyan': '7',
    'red': '11',
}


from django.utils.dateparse import parse_datetime

def parse_iso_datetime(value):
    if not value:
        return None
    dt = parse_datetime(value)
    if dt is None:
        try:
            if isinstance(value, str) and value.endswith('Z'):
                value = value[:-1] + '+00:00'
            dt = datetime.fromisoformat(value)
        except Exception:
            raise ValueError(f"Invalid isoformat string: '{value}'")
    return dt


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


def serialize_event(event):
    return {
        'id': event.id,
        'googleEventId': event.google_event_id,
        'title': event.title,
        'description': event.description,
        'start': event.start_time.isoformat(),
        'end': event.end_time.isoformat(),
        'allDay': event.all_day,
        'color': COLOR_MAP.get(event.color, '#3B82F6'),
        'colorKey': event.color,
        'category': event.category,
        'location': event.location,
        'attendees': event.attendees,
        'recurrence': event.recurrence,
        'reminders': event.reminders,
        'syncedToGoogle': event.synced_to_google,
        'isAiGenerated': event.is_ai_generated,
        'completed': event.completed,
        'createdAt': event.created_at.isoformat(),
    }


def push_event_to_google(service, event, calendar_id='primary'):
    """Push a CalendarEvent to Google Calendar and return google_event_id."""
    body = {
        'summary': event.title,
        'description': event.description,
        'location': event.location,
        'start': {'dateTime': event.start_time.isoformat(), 'timeZone': settings.TIME_ZONE},
        'end': {'dateTime': event.end_time.isoformat(), 'timeZone': settings.TIME_ZONE},
        'colorId': GOOGLE_COLOR_MAP.get(event.color, '9'),
        'reminders': {
            'useDefault': False,
            'overrides': [{'method': 'popup', 'minutes': r} for r in (event.reminders or [10])],
        },
    }
    if event.recurrence:
        body['recurrence'] = event.recurrence
    if event.attendees:
        body['attendees'] = [{'email': a} for a in event.attendees]

    if event.google_event_id:
        result = service.events().update(
            calendarId=calendar_id, eventId=event.google_event_id, body=body
        ).execute()
    else:
        result = service.events().insert(calendarId=calendar_id, body=body).execute()
    return result.get('id', '')


# ─────────────────────────────────────────────────────────────────────────────
# Existing Views (preserved + enhanced)
# ─────────────────────────────────────────────────────────────────────────────

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
        auth_url, state = flow.authorization_url(
            access_type='offline',
            include_granted_scopes='true',
            prompt='consent',
        )
        request.session['google_oauth_state'] = state
        return Response({'success': True, 'authUrl': auth_url})


class CalendarCallbackView(APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAuthenticated()]

    def get(self, request):
        code = request.GET.get('code')
        frontend_url = getattr(settings, 'FRONTEND_URL', 'http://localhost:5173')
        from django.shortcuts import redirect
        if code:
            return redirect(f"{frontend_url}/calendar?code={code}")
        return redirect(f"{frontend_url}/calendar")

    def post(self, request):
        code = request.data.get('code')
        if not code:
            return Response({'success': False, 'error': 'OAuth code is required.'}, status=400)

        _, Flow, build = optional_google_imports()
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

        # Fetch Google user email
        google_email = ''
        try:
            from googleapiclient.discovery import build as g_build
            user_info_service = g_build('oauth2', 'v2', credentials=credentials)
            user_info = user_info_service.userinfo().get().execute()
            google_email = user_info.get('email', '')
        except Exception:
            pass

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
                'google_email': google_email,
            },
        )
        return Response({'success': True, 'connected': True, 'googleEmail': google_email})


class CalendarDisconnectView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        GoogleCalendarConnection.objects.filter(user=request.user).delete()
        return Response({'success': True, 'connected': False})


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
            try:
                start = datetime.combine(routine.date, datetime.strptime(routine.wake_time, '%H:%M').time())
                start = timezone.make_aware(start) if timezone.is_naive(start) else start
                end = start + timedelta(minutes=30)
                event_body = {
                    'summary': 'ProductiveAI Daily Routine Review',
                    'description': f'Score: {routine.productivity_score}%. Notes: {routine.notes}',
                    'start': {'dateTime': start.isoformat()},
                    'end': {'dateTime': end.isoformat()},
                    'reminders': {'useDefault': False, 'overrides': [{'method': 'popup', 'minutes': 10}]},
                }
                service.events().insert(calendarId=connection.calendar_id, body=event_body).execute()
                created += 1
            except Exception:
                continue

        SyncLog.objects.create(user=request.user, direction='push', status='success', events_synced=created)
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
        event_body = {
            'summary': title,
            'description': request.data.get('description', 'Created by ProductiveAI.'),
            'start': {'dateTime': start.isoformat()},
            'end': {'dateTime': (start + timedelta(minutes=30)).isoformat()},
            'recurrence': request.data.get('recurrence', []),
            'reminders': {
                'useDefault': False,
                'overrides': [{'method': 'popup', 'minutes': int(request.data.get('minutesBefore', 10))}],
            },
        }
        result = service.events().insert(calendarId=connection.calendar_id, body=event_body).execute()
        return Response({'success': True, 'eventId': result.get('id'), 'htmlLink': result.get('htmlLink')})


# ─────────────────────────────────────────────────────────────────────────────
# NEW: CalendarEvent CRUD
# ─────────────────────────────────────────────────────────────────────────────

class CalendarEventsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """List events for a date range. Params: start, end (ISO strings)."""
        start_str = request.query_params.get('start')
        end_str = request.query_params.get('end')
        qs = CalendarEvent.objects.filter(user=request.user)
        if start_str:
            try:
                qs = qs.filter(start_time__gte=start_str)
            except Exception:
                pass
        if end_str:
            try:
                qs = qs.filter(end_time__lte=end_str)
            except Exception:
                pass
        return Response({'success': True, 'events': [serialize_event(e) for e in qs]})

    def post(self, request):
        """Create a new calendar event."""
        data = request.data
        try:
            start_time = parse_iso_datetime(data['start'])
            end_time = parse_iso_datetime(data['end'])
        except (KeyError, ValueError) as exc:
            return Response({'success': False, 'error': f'Invalid dates: {exc}'}, status=400)

        if timezone.is_naive(start_time):
            start_time = timezone.make_aware(start_time)
        if timezone.is_naive(end_time):
            end_time = timezone.make_aware(end_time)

        event = CalendarEvent.objects.create(
            user=request.user,
            title=data.get('title', 'Untitled'),
            description=data.get('description', ''),
            start_time=start_time,
            end_time=end_time,
            all_day=data.get('allDay', False),
            color=data.get('color', 'blue'),
            category=data.get('category', 'personal'),
            location=data.get('location', ''),
            attendees=data.get('attendees', []),
            recurrence=data.get('recurrence', []),
            reminders=data.get('reminders', [10]),
            is_ai_generated=data.get('isAiGenerated', False),
        )

        # Optionally sync to Google Calendar
        if data.get('syncToGoogle', False):
            connection = GoogleCalendarConnection.objects.filter(user=request.user).first()
            if connection and connection.connected:
                service = calendar_service(connection)
                if service:
                    try:
                        google_id = push_event_to_google(service, event, connection.calendar_id)
                        event.google_event_id = google_id
                        event.synced_to_google = True
                        event.save(update_fields=['google_event_id', 'synced_to_google'])
                        SyncLog.objects.create(user=request.user, direction='push', status='success', events_synced=1)
                    except Exception as exc:
                        SyncLog.objects.create(user=request.user, direction='push', status='error', error_message=str(exc))

        return Response({'success': True, 'event': serialize_event(event)}, status=201)


class CalendarEventDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def _get_event(self, request, pk):
        try:
            return CalendarEvent.objects.get(pk=pk, user=request.user)
        except CalendarEvent.DoesNotExist:
            return None

    def get(self, request, pk):
        event = self._get_event(request, pk)
        if not event:
            return Response({'success': False, 'error': 'Event not found'}, status=404)
        return Response({'success': True, 'event': serialize_event(event)})

    def put(self, request, pk):
        event = self._get_event(request, pk)
        if not event:
            return Response({'success': False, 'error': 'Event not found'}, status=404)

        data = request.data
        for field, attr in [
            ('title', 'title'), ('description', 'description'), ('location', 'location'),
            ('color', 'color'), ('category', 'category'), ('allDay', 'all_day'),
            ('attendees', 'attendees'), ('recurrence', 'recurrence'), ('reminders', 'reminders'),
            ('completed', 'completed'),
        ]:
            if field in data:
                setattr(event, attr, data[field])

        if 'start' in data:
            st = parse_iso_datetime(data['start'])
            event.start_time = timezone.make_aware(st) if timezone.is_naive(st) else st
        if 'end' in data:
            et = parse_iso_datetime(data['end'])
            event.end_time = timezone.make_aware(et) if timezone.is_naive(et) else et

        event.save()

        # Sync update to Google
        connection = GoogleCalendarConnection.objects.filter(user=request.user).first()
        if connection and connection.connected and event.synced_to_google:
            service = calendar_service(connection)
            if service:
                try:
                    push_event_to_google(service, event, connection.calendar_id)
                    SyncLog.objects.create(user=request.user, direction='push', status='success', events_synced=1)
                except Exception as exc:
                    SyncLog.objects.create(user=request.user, direction='push', status='error', error_message=str(exc))

        return Response({'success': True, 'event': serialize_event(event)})

    def delete(self, request, pk):
        event = self._get_event(request, pk)
        if not event:
            return Response({'success': False, 'error': 'Event not found'}, status=404)

        # Delete from Google Calendar too
        if event.synced_to_google and event.google_event_id:
            connection = GoogleCalendarConnection.objects.filter(user=request.user).first()
            if connection and connection.connected:
                service = calendar_service(connection)
                if service:
                    try:
                        service.events().delete(
                            calendarId=connection.calendar_id, eventId=event.google_event_id
                        ).execute()
                    except Exception:
                        pass

        event.delete()
        return Response({'success': True, 'deleted': True})


# ─────────────────────────────────────────────────────────────────────────────
# NEW: Pull events from Google Calendar into DB
# ─────────────────────────────────────────────────────────────────────────────

class CalendarFetchGoogleView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        connection = GoogleCalendarConnection.objects.filter(user=request.user).first()
        if not connection or not connection.connected:
            return Response({'success': False, 'error': 'Google Calendar not connected.'}, status=400)
        service = calendar_service(connection)
        if not service:
            return Response({'success': False, 'error': 'Google Calendar dependencies not installed.'}, status=501)

        now = timezone.now()
        time_min = (now - timedelta(days=30)).isoformat()
        time_max = (now + timedelta(days=60)).isoformat()

        try:
            result = service.events().list(
                calendarId=connection.calendar_id,
                timeMin=time_min,
                timeMax=time_max,
                singleEvents=True,
                orderBy='startTime',
                maxResults=250,
            ).execute()
            google_events = result.get('items', [])
        except Exception as exc:
            SyncLog.objects.create(user=request.user, direction='pull', status='error', error_message=str(exc))
            return Response({'success': False, 'error': str(exc)}, status=500)

        imported = 0
        for g_event in google_events:
            g_id = g_event.get('id', '')
            if not g_id:
                continue

            # Parse start/end
            start_raw = g_event.get('start', {})
            end_raw = g_event.get('end', {})
            all_day = 'date' in start_raw and 'dateTime' not in start_raw

            if all_day:
                from datetime import date as date_type
                start_dt = datetime.combine(
                    datetime.strptime(start_raw['date'], '%Y-%m-%d').date(),
                    datetime.min.time()
                )
                end_dt = datetime.combine(
                    datetime.strptime(end_raw.get('date', start_raw['date']), '%Y-%m-%d').date(),
                    datetime.min.time()
                )
            else:
                try:
                    start_dt = parse_iso_datetime(start_raw.get('dateTime', now.isoformat()))
                    end_dt = parse_iso_datetime(end_raw.get('dateTime', now.isoformat()))
                except Exception:
                    continue

            if timezone.is_naive(start_dt):
                start_dt = timezone.make_aware(start_dt)
            if timezone.is_naive(end_dt):
                end_dt = timezone.make_aware(end_dt)

            CalendarEvent.objects.update_or_create(
                user=request.user,
                google_event_id=g_id,
                defaults={
                    'title': g_event.get('summary', 'Untitled'),
                    'description': g_event.get('description', ''),
                    'start_time': start_dt,
                    'end_time': end_dt,
                    'all_day': all_day,
                    'location': g_event.get('location', ''),
                    'attendees': [a.get('email', '') for a in g_event.get('attendees', [])],
                    'recurrence': g_event.get('recurrence', []),
                    'synced_to_google': True,
                    'color': 'blue',
                },
            )
            imported += 1

        SyncLog.objects.create(user=request.user, direction='pull', status='success', events_synced=imported)
        return Response({'success': True, 'imported': imported})


# ─────────────────────────────────────────────────────────────────────────────
# NEW: AI Scheduler — Gemini-powered plan generation
# ─────────────────────────────────────────────────────────────────────────────

class AISchedulerView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        prompt = request.data.get('prompt', '').strip()
        if not prompt:
            return Response({'success': False, 'error': 'Prompt is required.'}, status=400)

        api_key = settings.GEMINI_API_KEY
        if not api_key:
            return Response({'success': False, 'error': 'Gemini API key not configured.'}, status=501)

        # Gather context from user's routines
        recent_routines = Routine.objects.filter(user=request.user).order_by('-date')[:7]
        routine_context = '\n'.join([
            f"- {r.date}: score={r.productivity_score}%, study={r.study_hours}h, exercise={r.exercise_completed}"
            for r in recent_routines
        ]) or 'No recent routine data.'

        existing_events = CalendarEvent.objects.filter(
            user=request.user,
            start_time__gte=timezone.now(),
            start_time__lte=timezone.now() + timedelta(days=30),
        ).order_by('start_time')[:20]
        event_context = '\n'.join([
            f"- {e.title} on {e.start_time.strftime('%Y-%m-%d %H:%M')}"
            for e in existing_events
        ]) or 'No upcoming events.'

        system_prompt = f"""You are an elite AI productivity scheduler embedded in ProductiveAI, a futuristic SaaS productivity OS.

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

        try:
            genai.configure(api_key=api_key)
            model = genai.GenerativeModel(settings.GEMINI_MODEL)
            response = model.generate_content(system_prompt)
            raw = response.text.strip()

            # Strip markdown code fences if present
            if raw.startswith('```'):
                lines = raw.split('\n')
                raw = '\n'.join(lines[1:-1]) if lines[-1].strip() == '```' else '\n'.join(lines[1:])

            plan_data = json.loads(raw)
        except json.JSONDecodeError as exc:
            return Response({'success': False, 'error': f'AI returned invalid JSON: {exc}'}, status=500)
        except Exception as exc:
            return Response({'success': False, 'error': f'AI generation failed: {exc}'}, status=500)

        # Save AI schedule record
        ai_schedule = AISchedule.objects.create(
            user=request.user,
            prompt=prompt,
            plan_title=plan_data.get('planTitle', 'AI Schedule'),
            plan_summary=plan_data.get('planSummary', ''),
            generated_events=plan_data.get('events', []),
            status='pending',
        )

        return Response({
            'success': True,
            'scheduleId': ai_schedule.id,
            'planTitle': plan_data.get('planTitle', ''),
            'planSummary': plan_data.get('planSummary', ''),
            'insights': plan_data.get('insights', []),
            'events': plan_data.get('events', []),
        })


class AIScheduleApplyView(APIView):
    """Apply a generated AI schedule — create CalendarEvent records and optionally sync to Google."""
    permission_classes = [IsAuthenticated]

    def post(self, request, schedule_id):
        try:
            ai_schedule = AISchedule.objects.get(pk=schedule_id, user=request.user)
        except AISchedule.DoesNotExist:
            return Response({'success': False, 'error': 'Schedule not found.'}, status=404)

        sync_to_google = request.data.get('syncToGoogle', False)
        connection = None
        service = None
        if sync_to_google:
            connection = GoogleCalendarConnection.objects.filter(user=request.user).first()
            if connection and connection.connected:
                service = calendar_service(connection)

        created_events = []
        for evt in ai_schedule.generated_events:
            try:
                date_str = evt['date']
                start_str = f"{date_str}T{evt['startTime']}:00"
                end_str = f"{date_str}T{evt['endTime']}:00"
                start_dt = timezone.make_aware(datetime.fromisoformat(start_str))
                end_dt = timezone.make_aware(datetime.fromisoformat(end_str))
            except (KeyError, ValueError):
                continue

            cal_event = CalendarEvent.objects.create(
                user=request.user,
                title=evt.get('title', 'AI Session'),
                description=evt.get('description', ''),
                start_time=start_dt,
                end_time=end_dt,
                color=evt.get('color', 'purple'),
                category=evt.get('category', 'study'),
                reminders=evt.get('reminders', [10]),
                is_ai_generated=True,
                ai_metadata={'scheduleId': ai_schedule.id, 'priority': evt.get('priority', 'medium')},
            )

            if service and connection:
                try:
                    g_id = push_event_to_google(service, cal_event, connection.calendar_id)
                    cal_event.google_event_id = g_id
                    cal_event.synced_to_google = True
                    cal_event.save(update_fields=['google_event_id', 'synced_to_google'])
                except Exception:
                    pass

            created_events.append(serialize_event(cal_event))

        ai_schedule.status = 'applied'
        ai_schedule.save(update_fields=['status'])

        if service:
            SyncLog.objects.create(
                user=request.user, direction='push', status='success', events_synced=len(created_events)
            )

        return Response({'success': True, 'created': len(created_events), 'events': created_events})


# ─────────────────────────────────────────────────────────────────────────────
# NEW: AI Insights
# ─────────────────────────────────────────────────────────────────────────────

class AIInsightsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Return recent cached insights."""
        insights = ProductivityInsight.objects.filter(user=request.user)[:8]
        return Response({
            'success': True,
            'insights': [
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
            ],
        })

    def post(self, request):
        """Generate fresh AI insights via Gemini."""
        api_key = settings.GEMINI_API_KEY
        if not api_key:
            return Response({'success': False, 'error': 'Gemini API key not configured.'}, status=501)

        routines = Routine.objects.filter(user=request.user).order_by('-date')[:14]
        if not routines:
            return Response({'success': True, 'insights': [], 'message': 'No routine data yet.'})

        routine_summary = '\n'.join([
            f"- {r.date}: score={r.productivity_score}%, study={r.study_hours}h, "
            f"sleep={r.sleep_time}-{r.wake_time}, mobile={r.mobile_usage}h, exercise={r.exercise_completed}"
            for r in routines
        ])

        calendar_events = CalendarEvent.objects.filter(
            user=request.user,
            start_time__gte=timezone.now() - timedelta(days=14),
        ).count()

        system_prompt = f"""Analyze this user's productivity data and generate personalized AI insights.

Routine data (last 14 days):
{routine_summary}

Calendar events logged: {calendar_events}
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

        try:
            genai.configure(api_key=api_key)
            model = genai.GenerativeModel(settings.GEMINI_MODEL)
            response = model.generate_content(system_prompt)
            raw = response.text.strip()
            if raw.startswith('```'):
                lines = raw.split('\n')
                raw = '\n'.join(lines[1:-1]) if lines[-1].strip() == '```' else '\n'.join(lines[1:])
            data = json.loads(raw)
        except Exception as exc:
            return Response({'success': False, 'error': str(exc)}, status=500)

        # Clear old insights and save new ones
        ProductivityInsight.objects.filter(user=request.user).delete()
        saved = []
        for ins in data.get('insights', []):
            obj = ProductivityInsight.objects.create(
                user=request.user,
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

        return Response({'success': True, 'insights': saved})


# ─────────────────────────────────────────────────────────────────────────────
# NEW: Productivity Heatmap Analytics
# ─────────────────────────────────────────────────────────────────────────────

class ProductivityHeatmapView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Return heatmap data: per-day productivity scores + calendar event density."""
        days = int(request.query_params.get('days', 30))
        since = timezone.now() - timedelta(days=days)

        routines = Routine.objects.filter(user=request.user, date__gte=since.date())
        events = CalendarEvent.objects.filter(user=request.user, start_time__gte=since)

        # Build heatmap: date → productivity score
        heatmap = {}
        for r in routines:
            heatmap[str(r.date)] = {
                'score': r.productivity_score,
                'studyHours': r.study_hours,
                'exercise': r.exercise_completed,
                'sleepTime': r.sleep_time,
                'wakeTime': r.wake_time,
                'mobileUsage': r.mobile_usage,
            }

        # Event density per day
        event_density = {}
        for e in events:
            day_key = str(e.start_time.date())
            event_density[day_key] = event_density.get(day_key, 0) + 1

        # Stats
        scores = [r.productivity_score for r in routines]
        avg_score = round(sum(scores) / len(scores), 1) if scores else 0
        best_day = max(heatmap, key=lambda d: heatmap[d]['score'], default=None)
        total_events = events.count()

        # Hourly breakdown from events
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
                'totalEvents': total_events,
                'peakHour': peak_hour,
                'streak': self._calc_streak(routines),
            },
        })

    def _calc_streak(self, routines):
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


# ─────────────────────────────────────────────────────────────────────────────
# NEW: Notification Settings
# ─────────────────────────────────────────────────────────────────────────────

class NotificationSettingsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        settings_obj, _ = NotificationSettings.objects.get_or_create(user=request.user)
        return Response({
            'success': True,
            'settings': {
                'browserNotifications': settings_obj.browser_notifications,
                'emailReminders': settings_obj.email_reminders,
                'eventRemindersMinutes': settings_obj.event_reminders_minutes,
                'dailySummary': settings_obj.daily_summary,
                'aiSuggestions': settings_obj.ai_suggestions,
            },
        })

    def post(self, request):
        settings_obj, _ = NotificationSettings.objects.get_or_create(user=request.user)
        data = request.data
        if 'browserNotifications' in data:
            settings_obj.browser_notifications = data['browserNotifications']
        if 'emailReminders' in data:
            settings_obj.email_reminders = data['emailReminders']
        if 'eventRemindersMinutes' in data:
            settings_obj.event_reminders_minutes = data['eventRemindersMinutes']
        if 'dailySummary' in data:
            settings_obj.daily_summary = data['dailySummary']
        if 'aiSuggestions' in data:
            settings_obj.ai_suggestions = data['aiSuggestions']
        if 'vapidSubscription' in data:
            settings_obj.vapid_subscription = data['vapidSubscription']
        settings_obj.save()
        return Response({'success': True})


# ─────────────────────────────────────────────────────────────────────────────
# NEW: Google Webhook (scaffolded for production)
# ─────────────────────────────────────────────────────────────────────────────

class WebhookView(APIView):
    permission_classes = []  # Google sends unauthenticated push notifications

    def post(self, request):
        """Receives Google Calendar push notification and triggers a sync."""
        channel_id = request.headers.get('X-Goog-Channel-Id', '')
        resource_state = request.headers.get('X-Goog-Resource-State', '')

        if resource_state == 'sync':
            return Response(status=200)

        # In production: look up user by channel_id, trigger pull sync
        # For now, acknowledge receipt
        return Response(status=200)


class SyncLogsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        logs = SyncLog.objects.filter(user=request.user)[:20]
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
