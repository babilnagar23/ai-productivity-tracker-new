import uuid
from django.utils.dateparse import parse_datetime, parse_date
from django.utils import timezone
from django.db import transaction
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from todos.models import Todo
from routines.models import Routine
from focus.models import FocusSession
from calendar_integration.models import CalendarEvent
from notifications.models import NotificationRecord

# ─────────────────────────────────────────────────────────────────────────────
# Helper Synchronization Functions
# ─────────────────────────────────────────────────────────────────────────────

def _process_todo_sync(user, records, last_sync_dt):
    synced_ids = []
    conflicts = []
    
    for r in records:
        client_uuid = r.get('client_uuid') or r.get('localId')
        if not client_uuid:
            continue
            
        updated_at_str = r.get('updated_at') or r.get('createdAt')
        client_updated_at = parse_datetime(updated_at_str) if updated_at_str else timezone.now()
        
        # Prevent runtime issues if timezone offset is missing
        if client_updated_at and timezone.is_naive(client_updated_at):
            client_updated_at = timezone.make_aware(client_updated_at)
            
        try:
            todo = Todo.objects.get(user=user, client_uuid=client_uuid)
            # Conflict resolution: server is newer?
            if todo.updated_at > client_updated_at:
                conflicts.append({
                    'client_uuid': client_uuid,
                    'server_record': {
                        'client_uuid': str(todo.client_uuid),
                        'title': todo.title,
                        'description': todo.description,
                        'due_date': todo.due_date.isoformat() if todo.due_date else None,
                        'completed': todo.completed,
                        'completed_at': todo.completed_at.isoformat() if todo.completed_at else None,
                        'created_at': todo.created_at.isoformat(),
                        'updated_at': todo.updated_at.isoformat(),
                        'deleted_at': todo.deleted_at.isoformat() if todo.deleted_at else None,
                    },
                    'error': 'Server record is newer'
                })
                continue
        except Todo.DoesNotExist:
            todo = Todo(user=user, client_uuid=client_uuid)
            
        # Update attributes
        todo.title = r.get('title', todo.title)
        todo.description = r.get('description', todo.description or '')
        if r.get('due_date') or r.get('dueDate'):
            raw_date = r.get('due_date') or r.get('dueDate')
            parsed_d = parse_date(raw_date)
            if not parsed_d:
                parsed_dt = parse_datetime(raw_date)
                if parsed_dt:
                    parsed_d = parsed_dt.date()
            todo.due_date = parsed_d or timezone.now().date()
        todo.completed = r.get('completed') == True or r.get('completed') == 1
        
        comp_at = r.get('completed_at') or r.get('completedAt')
        todo.completed_at = parse_datetime(comp_at) if comp_at else None
        
        # Soft delete handling
        del_at = r.get('deleted_at') or r.get('deletedAt')
        if del_at:
            todo.deleted_at = parse_datetime(del_at)
        elif r.get('deletedFlag') == 1:
            todo.deleted_at = timezone.now()
        else:
            todo.deleted_at = None
            
        todo.save()
        synced_ids.append(client_uuid)
        
    # Get server updates
    server_updates = []
    queryset = Todo.objects.filter(user=user)
    if last_sync_dt:
        queryset = queryset.filter(updated_at__gt=last_sync_dt)
        
    for item in queryset:
        if str(item.client_uuid) not in synced_ids:
            server_updates.append({
                'client_uuid': str(item.client_uuid),
                'title': item.title,
                'description': item.description,
                'due_date': item.due_date.isoformat() if item.due_date else None,
                'completed': item.completed,
                'completed_at': item.completed_at.isoformat() if item.completed_at else None,
                'created_at': item.created_at.isoformat(),
                'updated_at': item.updated_at.isoformat(),
                'deleted_at': item.deleted_at.isoformat() if item.deleted_at else None,
            })
            
    return synced_ids, conflicts, server_updates


def _process_routine_sync(user, records, last_sync_dt):
    synced_ids = []
    conflicts = []
    
    for r in records:
        client_uuid = r.get('client_uuid') or r.get('localId')
        if not client_uuid:
            continue
            
        updated_at_str = r.get('updated_at') or r.get('createdAt')
        client_updated_at = parse_datetime(updated_at_str) if updated_at_str else timezone.now()
        
        if client_updated_at and timezone.is_naive(client_updated_at):
            client_updated_at = timezone.make_aware(client_updated_at)
            
        # Try finding by client_uuid
        routine = None
        try:
            routine = Routine.objects.get(user=user, client_uuid=client_uuid)
        except Routine.DoesNotExist:
            # Fallback check by date to prevent 409 unique constraints on user/date
            r_date = parse_date(r.get('date')) if r.get('date') else None
            if r_date:
                routine = Routine.objects.filter(user=user, date=r_date).first()
                if routine and not routine.client_uuid:
                    routine.client_uuid = client_uuid
                    routine.save()

        if routine:
            # Check conflict: server is newer? (Routines don't auto_now=True updated_at by default but we can check created_at or assume client overwrite)
            pass
        else:
            routine = Routine(user=user, client_uuid=client_uuid)
            
        # Update attributes
        if r.get('date'):
            routine.date = parse_date(r.get('date'))
        routine.study_completed = r.get('study_completed') == True or r.get('studyCompleted') == 1
        routine.exercise_completed = r.get('exercise_completed') == True or r.get('exerciseCompleted') == 1
        routine.ml_completed = r.get('ml_completed') == True or r.get('mlCompleted') == 1
        routine.study_hours = float(r.get('study_hours') or r.get('studyHours') or 0.0)
        routine.sleep_time = r.get('sleep_time') or r.get('sleepTime') or '23:00'
        routine.wake_time = r.get('wake_time') or r.get('wakeTime') or '07:00'
        routine.mobile_usage = float(r.get('mobile_usage') or r.get('mobileUsage') or 0.0)
        routine.notes = r.get('notes', routine.notes or '')
        routine.productivity_score = int(r.get('productivity_score') or r.get('productivityScore') or 0)
        
        routine.core_checklists = r.get('core_checklists') or r.get('coreChecklists') or {}
        routine.core_metrics = r.get('core_metrics') or r.get('coreMetrics') or {}
        routine.custom_logs = r.get('custom_logs') or r.get('customLogs') or []
        
        # Soft delete handling
        del_at = r.get('deleted_at') or r.get('deletedAt')
        if del_at:
            routine.deleted_at = parse_datetime(del_at)
        elif r.get('deletedFlag') == 1:
            routine.deleted_at = timezone.now()
        else:
            routine.deleted_at = None
            
        routine.save()
        synced_ids.append(client_uuid)
        
    # Get server updates
    server_updates = []
    queryset = Routine.objects.filter(user=user)
    if last_sync_dt:
        queryset = queryset.filter(created_at__gt=last_sync_dt) # routines only have created_at field
        
    for item in queryset:
        if str(item.client_uuid) not in synced_ids:
            server_updates.append({
                'client_uuid': str(item.client_uuid) if item.client_uuid else None,
                'date': item.date.isoformat() if item.date else None,
                'study_completed': item.study_completed,
                'exercise_completed': item.exercise_completed,
                'ml_completed': item.ml_completed,
                'study_hours': item.study_hours,
                'sleep_time': item.sleep_time,
                'wake_time': item.wake_time,
                'mobile_usage': item.mobile_usage,
                'notes': item.notes,
                'productivity_score': item.productivity_score,
                'core_checklists': item.core_checklists,
                'core_metrics': item.core_metrics,
                'custom_logs': item.custom_logs,
                'created_at': item.created_at.isoformat(),
                'deleted_at': item.deleted_at.isoformat() if item.deleted_at else None,
            })
            
    return synced_ids, conflicts, server_updates


def _process_focus_sync(user, records, last_sync_dt):
    synced_ids = []
    conflicts = []
    
    for r in records:
        client_uuid = r.get('client_uuid') or r.get('localId')
        if not client_uuid:
            continue
            
        updated_at_str = r.get('updated_at') or r.get('createdAt')
        client_updated_at = parse_datetime(updated_at_str) if updated_at_str else timezone.now()
        
        if client_updated_at and timezone.is_naive(client_updated_at):
            client_updated_at = timezone.make_aware(client_updated_at)
            
        try:
            session = FocusSession.objects.get(user=user, client_uuid=client_uuid)
            if session.updated_at > client_updated_at:
                conflicts.append({
                    'client_uuid': client_uuid,
                    'server_record': {
                        'client_uuid': str(session.client_uuid),
                        'session_type': session.session_type,
                        'label': session.label,
                        'start_time': session.start_time.isoformat(),
                        'end_time': session.end_time.isoformat() if session.end_time else None,
                        'duration_minutes': session.duration_minutes,
                        'completed': session.completed,
                        'laps_json': session.laps_json,
                        'created_at': session.created_at.isoformat(),
                        'updated_at': session.updated_at.isoformat(),
                        'deleted_at': session.deleted_at.isoformat() if session.deleted_at else None,
                    },
                    'error': 'Server record is newer'
                })
                continue
        except FocusSession.DoesNotExist:
            session = FocusSession(user=user, client_uuid=client_uuid)
            
        session.session_type = r.get('session_type') or r.get('sessionType') or 'timer'
        session.label = r.get('label') or 'Focus Session'
        
        s_time = r.get('start_time') or r.get('startTime')
        if s_time:
            session.start_time = parse_datetime(s_time)
        e_time = r.get('end_time') or r.get('endTime')
        if e_time:
            session.end_time = parse_datetime(e_time)
            
        session.duration_minutes = int(r.get('duration_minutes') or r.get('durationMinutes') or 0)
        session.completed = r.get('completed') == True or r.get('completed') == 1
        session.laps_json = r.get('laps_json') or r.get('lapsJson') or []
        
        # Soft delete handling
        del_at = r.get('deleted_at') or r.get('deletedAt')
        if del_at:
            session.deleted_at = parse_datetime(del_at)
        elif r.get('deletedFlag') == 1:
            session.deleted_at = timezone.now()
        else:
            session.deleted_at = None
            
        session.save()
        synced_ids.append(client_uuid)
        
    # Get server updates
    server_updates = []
    queryset = FocusSession.objects.filter(user=user)
    if last_sync_dt:
        queryset = queryset.filter(updated_at__gt=last_sync_dt)
        
    for item in queryset:
        if str(item.client_uuid) not in synced_ids:
            server_updates.append({
                'client_uuid': str(item.client_uuid),
                'session_type': item.session_type,
                'label': item.label,
                'start_time': item.start_time.isoformat(),
                'end_time': item.end_time.isoformat() if item.end_time else None,
                'duration_minutes': item.duration_minutes,
                'completed': item.completed,
                'laps_json': item.laps_json,
                'created_at': item.created_at.isoformat(),
                'updated_at': item.updated_at.isoformat(),
                'deleted_at': item.deleted_at.isoformat() if item.deleted_at else None,
            })
            
    return synced_ids, conflicts, server_updates


def _process_calendar_sync(user, records, last_sync_dt):
    from calendar_integration.models import GoogleCalendarConnection
    from calendar_integration.views import calendar_service, push_event_to_google, pull_google_calendar_events
    
    # Try to pull latest events from Google Calendar first
    pull_google_calendar_events(user)
    
    synced_ids = []
    conflicts = []
    
    for r in records:
        client_uuid = r.get('client_uuid') or r.get('localId')
        if not client_uuid:
            continue
            
        updated_at_str = r.get('updated_at') or r.get('createdAt')
        client_updated_at = parse_datetime(updated_at_str) if updated_at_str else timezone.now()
        
        if client_updated_at and timezone.is_naive(client_updated_at):
            client_updated_at = timezone.make_aware(client_updated_at)
            
        try:
            event = CalendarEvent.objects.get(user=user, client_uuid=client_uuid)
            if event.updated_at > client_updated_at:
                conflicts.append({
                    'client_uuid': client_uuid,
                    'server_record': {
                        'client_uuid': str(event.client_uuid),
                        'title': event.title,
                        'description': event.description,
                        'start_time': event.start_time.isoformat(),
                        'end_time': event.end_time.isoformat(),
                        'all_day': event.all_day,
                        'color': event.color,
                        'category': event.category,
                        'location': event.location,
                        'googleEventId': event.google_event_id,
                        'syncedToGoogle': event.synced_to_google,
                        'syncStatus': 'synced',
                        'completed': event.completed,
                        'created_at': event.created_at.isoformat(),
                        'updated_at': event.updated_at.isoformat(),
                        'deleted_at': event.deleted_at.isoformat() if event.deleted_at else None,
                    },
                    'error': 'Server record is newer'
                })
                continue
        except CalendarEvent.DoesNotExist:
            event = CalendarEvent(user=user, client_uuid=client_uuid)
            
        event.title = r.get('title') or 'Untitled Event'
        event.description = r.get('description') or ''
        
        s_time = r.get('start_time') or r.get('startTime')
        if s_time:
            event.start_time = parse_datetime(s_time)
        e_time = r.get('end_time') or r.get('endTime')
        if e_time:
            event.end_time = parse_datetime(e_time)
            
        event.all_day = r.get('all_day') == True or r.get('allDay') == 1
        event.color = r.get('color') or 'blue'
        event.category = r.get('category') or 'personal'
        event.location = r.get('location') or ''
        event.google_event_id = r.get('googleEventId') or ''
        event.completed = r.get('completed') == True or r.get('completed') == 1
        
        synced_to_google = r.get('syncedToGoogle') == True or r.get('synced_to_google') == True or r.get('syncToGoogle') == True or r.get('syncedToGoogle') == 1
        event.synced_to_google = synced_to_google
        
        # Soft delete handling
        del_at = r.get('deleted_at') or r.get('deletedAt')
        if del_at:
            event.deleted_at = parse_datetime(del_at)
        elif r.get('deletedFlag') == 1:
            event.deleted_at = timezone.now()
        else:
            event.deleted_at = None
            
        event.save()
        
        if event.synced_to_google and not event.deleted_at:
            connection = GoogleCalendarConnection.objects.filter(user=user).first()
            if connection and connection.connected:
                service = calendar_service(connection)
                if service:
                    try:
                        google_id = push_event_to_google(service, event, connection.calendar_id)
                        event.google_event_id = google_id
                        event.save(update_fields=['google_event_id'])
                        SyncLog.objects.create(user=user, direction='push', status='success', events_synced=1)
                    except Exception as exc:
                        SyncLog.objects.create(user=user, direction='push', status='error', error_message=str(exc))
        
        synced_ids.append(client_uuid)
        
    # Get server updates
    server_updates = []
    queryset = CalendarEvent.objects.filter(user=user)
    if last_sync_dt:
        queryset = queryset.filter(updated_at__gt=last_sync_dt)
        
    for item in queryset:
        if str(item.client_uuid) not in synced_ids:
            server_updates.append({
                'client_uuid': str(item.client_uuid) if item.client_uuid else None,
                'title': item.title,
                'description': item.description,
                'start_time': item.start_time.isoformat(),
                'end_time': item.end_time.isoformat(),
                'all_day': item.all_day,
                'color': item.color,
                'category': item.category,
                'location': item.location,
                'googleEventId': item.google_event_id,
                'syncedToGoogle': item.synced_to_google,
                'syncStatus': 'synced',
                'completed': item.completed,
                'created_at': item.created_at.isoformat(),
                'updated_at': item.updated_at.isoformat(),
                'deleted_at': item.deleted_at.isoformat() if item.deleted_at else None,
            })
            
    return synced_ids, conflicts, server_updates


def _process_notification_sync(user, records, last_sync_dt):
    synced_ids = []
    conflicts = []
    
    for r in records:
        client_uuid = r.get('client_uuid') or r.get('localId')
        if not client_uuid:
            continue
            
        updated_at_str = r.get('updated_at') or r.get('createdAt')
        client_updated_at = parse_datetime(updated_at_str) if updated_at_str else timezone.now()
        
        if client_updated_at and timezone.is_naive(client_updated_at):
            client_updated_at = timezone.make_aware(client_updated_at)
            
        try:
            notif = NotificationRecord.objects.get(user=user, client_uuid=client_uuid)
            if notif.updated_at > client_updated_at:
                conflicts.append({
                    'client_uuid': client_uuid,
                    'server_record': {
                        'client_uuid': str(notif.client_uuid),
                        'type': notif.type,
                        'title': notif.title,
                        'body': notif.body,
                        'payload_json': notif.payload_json,
                        'scheduled_for': notif.scheduled_for.isoformat() if notif.scheduled_for else None,
                        'delivered_at': notif.delivered_at.isoformat() if notif.delivered_at else None,
                        'read_at': notif.read_at.isoformat() if notif.read_at else None,
                        'dismissed_at': notif.dismissed_at.isoformat() if notif.dismissed_at else None,
                        'created_at': notif.created_at.isoformat(),
                        'updated_at': notif.updated_at.isoformat(),
                        'deleted_at': notif.deleted_at.isoformat() if notif.deleted_at else None,
                    },
                    'error': 'Server record is newer'
                })
                continue
        except NotificationRecord.DoesNotExist:
            notif = NotificationRecord(user=user, client_uuid=client_uuid)
            
        notif.type = r.get('type') or 'todo'
        notif.title = r.get('title') or 'Notification'
        notif.body = r.get('body') or ''
        notif.payload_json = r.get('payload_json') or r.get('payloadJson') or {}
        
        sched = r.get('scheduled_for') or r.get('scheduledFor')
        notif.scheduled_for = parse_datetime(sched) if sched else None
        
        deliv = r.get('delivered_at') or r.get('deliveredAt')
        notif.delivered_at = parse_datetime(deliv) if deliv else None
        
        read = r.get('read_at') or r.get('readAt')
        notif.read_at = parse_datetime(read) if read else None
        
        dism = r.get('dismissed_at') or r.get('dismissedAt')
        notif.dismissed_at = parse_datetime(dism) if dism else None
        
        # Soft delete handling
        del_at = r.get('deleted_at') or r.get('deletedAt')
        if del_at:
            notif.deleted_at = parse_datetime(del_at)
        elif r.get('deletedFlag') == 1:
            notif.deleted_at = timezone.now()
        else:
            notif.deleted_at = None
            
        notif.save()
        synced_ids.append(client_uuid)
        
    # Get server updates
    server_updates = []
    queryset = NotificationRecord.objects.filter(user=user)
    if last_sync_dt:
        queryset = queryset.filter(updated_at__gt=last_sync_dt)
        
    for item in queryset:
        if str(item.client_uuid) not in synced_ids:
            server_updates.append({
                'client_uuid': str(item.client_uuid),
                'type': item.type,
                'title': item.title,
                'body': item.body,
                'payload_json': item.payload_json,
                'scheduled_for': item.scheduled_for.isoformat() if item.scheduled_for else None,
                'delivered_at': item.delivered_at.isoformat() if item.delivered_at else None,
                'read_at': item.read_at.isoformat() if item.read_at else None,
                'dismissed_at': item.dismissed_at.isoformat() if item.dismissed_at else None,
                'created_at': item.created_at.isoformat(),
                'updated_at': item.updated_at.isoformat(),
                'deleted_at': item.deleted_at.isoformat() if item.deleted_at else None,
            })
            
    return synced_ids, conflicts, server_updates

# ─────────────────────────────────────────────────────────────────────────────
# Sync API View Classes
# ─────────────────────────────────────────────────────────────────────────────

class SyncTasksView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        records = request.data.get('records', [])
        last_sync = request.data.get('last_sync_time')
        last_sync_dt = parse_datetime(last_sync) if last_sync else None
        
        synced_ids, conflicts, server_updates = _process_todo_sync(request.user, records, last_sync_dt)
        
        return Response({
            'success': True,
            'synced_ids': synced_ids,
            'conflicts': conflicts,
            'server_updates': server_updates,
            'sync_time': timezone.now().isoformat()
        })


class SyncDailyLogsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        records = request.data.get('records', [])
        last_sync = request.data.get('last_sync_time')
        last_sync_dt = parse_datetime(last_sync) if last_sync else None
        
        synced_ids, conflicts, server_updates = _process_routine_sync(request.user, records, last_sync_dt)
        
        return Response({
            'success': True,
            'synced_ids': synced_ids,
            'conflicts': conflicts,
            'server_updates': server_updates,
            'sync_time': timezone.now().isoformat()
        })


class SyncRoutinesView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        records = request.data.get('records', [])
        last_sync = request.data.get('last_sync_time')
        last_sync_dt = parse_datetime(last_sync) if last_sync else None
        
        synced_ids, conflicts, server_updates = _process_routine_sync(request.user, records, last_sync_dt)
        
        return Response({
            'success': True,
            'synced_ids': synced_ids,
            'conflicts': conflicts,
            'server_updates': server_updates,
            'sync_time': timezone.now().isoformat()
        })


class SyncFocusSessionsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        records = request.data.get('records', [])
        last_sync = request.data.get('last_sync_time')
        last_sync_dt = parse_datetime(last_sync) if last_sync else None
        
        synced_ids, conflicts, server_updates = _process_focus_sync(request.user, records, last_sync_dt)
        
        return Response({
            'success': True,
            'synced_ids': synced_ids,
            'conflicts': conflicts,
            'server_updates': server_updates,
            'sync_time': timezone.now().isoformat()
        })


class SyncCalendarEventsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        records = request.data.get('records', [])
        last_sync = request.data.get('last_sync_time')
        last_sync_dt = parse_datetime(last_sync) if last_sync else None
        
        synced_ids, conflicts, server_updates = _process_calendar_sync(request.user, records, last_sync_dt)
        
        return Response({
            'success': True,
            'synced_ids': synced_ids,
            'conflicts': conflicts,
            'server_updates': server_updates,
            'sync_time': timezone.now().isoformat()
        })


class SyncNotificationsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        records = request.data.get('records', [])
        last_sync = request.data.get('last_sync_time')
        last_sync_dt = parse_datetime(last_sync) if last_sync else None
        
        synced_ids, conflicts, server_updates = _process_notification_sync(request.user, records, last_sync_dt)
        
        return Response({
            'success': True,
            'synced_ids': synced_ids,
            'conflicts': conflicts,
            'server_updates': server_updates,
            'sync_time': timezone.now().isoformat()
        })


class SyncBatchView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        last_sync = request.data.get('last_sync_time')
        last_sync_dt = parse_datetime(last_sync) if last_sync else None
        
        client_tasks = request.data.get('tasks', [])
        client_routines = request.data.get('routines', [])
        client_focus = request.data.get('focus_sessions', [])
        client_calendar = request.data.get('calendar_events', [])
        client_notifications = request.data.get('notifications', [])
        
        with transaction.atomic():
            task_synced, task_conflicts, task_updates = _process_todo_sync(request.user, client_tasks, last_sync_dt)
            routine_synced, routine_conflicts, routine_updates = _process_routine_sync(request.user, client_routines, last_sync_dt)
            focus_synced, focus_conflicts, focus_updates = _process_focus_sync(request.user, client_focus, last_sync_dt)
            calendar_synced, calendar_conflicts, calendar_updates = _process_calendar_sync(request.user, client_calendar, last_sync_dt)
            notification_synced, notification_conflicts, notification_updates = _process_notification_sync(request.user, client_notifications, last_sync_dt)
            
        return Response({
            'success': True,
            'tasks': {
                'synced_ids': task_synced,
                'conflicts': task_conflicts,
                'server_updates': task_updates,
            },
            'routines': {
                'synced_ids': routine_synced,
                'conflicts': routine_conflicts,
                'server_updates': routine_updates,
            },
            'focus_sessions': {
                'synced_ids': focus_synced,
                'conflicts': focus_conflicts,
                'server_updates': focus_updates,
            },
            'calendar_events': {
                'synced_ids': calendar_synced,
                'conflicts': calendar_conflicts,
                'server_updates': calendar_updates,
            },
            'notifications': {
                'synced_ids': notification_synced,
                'conflicts': notification_conflicts,
                'server_updates': notification_updates,
            },
            'sync_time': timezone.now().isoformat()
        })
