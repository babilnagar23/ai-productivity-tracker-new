"""
Event Service — CalendarEvent CRUD and serialization.

Responsible for:
  - Creating, reading, updating, and deleting CalendarEvent records
  - Serializing events for API responses
  - Optionally syncing an event to Google Calendar after a local mutation
"""
import logging
from datetime import datetime

from django.utils import timezone
from django.utils.dateparse import parse_datetime

from ..constants import COLOR_MAP
from ..exceptions import CalendarSyncError, EventNotFound
from ..models import CalendarEvent, GoogleCalendarConnection

logger = logging.getLogger('calendar')


# ── Serialization ─────────────────────────────────────────────────

def serialize_event(event: 'CalendarEvent') -> dict:
    """Convert a CalendarEvent model instance to an API-ready dict."""
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


# ── Parsing helpers ───────────────────────────────────────────────

def parse_iso_datetime(value):
    """
    Parse an ISO 8601 datetime string, handling 'Z' suffix.
    Raises ValueError on invalid input.
    """
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


def _ensure_aware(dt):
    """Make a datetime timezone-aware if it is naive."""
    if dt and timezone.is_naive(dt):
        return timezone.make_aware(dt)
    return dt


# ── CRUD ──────────────────────────────────────────────────────────

def list_events(user, start_str=None, end_str=None, date_str=None):
    """
    Return a queryset of CalendarEvents for a user, optionally filtered
    by date range or specific date.
    """
    qs = CalendarEvent.objects.filter(user=user)

    if date_str:
        try:
            qs = qs.filter(start_time__date=date_str)
        except Exception:
            pass

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

    return qs


def create_event(user, data: dict, push_to_google: bool = False) -> 'CalendarEvent':
    """
    Create a new CalendarEvent.

    Args:
        user: Django user instance
        data: validated event data dict (title, start, end, …)
        push_to_google: if True, also push the event to Google Calendar

    Returns:
        CalendarEvent instance

    Raises:
        ValueError: invalid date strings
        CalendarSyncError: Google push failed
    """
    start_time = _ensure_aware(parse_iso_datetime(data['start']))
    end_time = _ensure_aware(parse_iso_datetime(data['end']))

    event = CalendarEvent.objects.create(
        user=user,
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
        reminders=data.get('reminders', []),
        is_ai_generated=data.get('isAiGenerated', False),
    )
    logger.info('[Calendar] Created event id=%s for user %s', event.id, user.id)

    if push_to_google:
        _sync_event_to_google(user, event)

    return event


def update_event(user, pk: int, data: dict, push_to_google: bool = False) -> 'CalendarEvent':
    """
    Update an existing CalendarEvent.

    Raises:
        EventNotFound: event does not exist or belongs to a different user.
    """
    try:
        event = CalendarEvent.objects.get(pk=pk, user=user)
    except CalendarEvent.DoesNotExist:
        raise EventNotFound(f'CalendarEvent id={pk} not found for user {user.id}')

    update_fields = []

    if 'title' in data:
        event.title = data['title']
        update_fields.append('title')
    if 'description' in data:
        event.description = data['description']
        update_fields.append('description')
    if 'start' in data:
        event.start_time = _ensure_aware(parse_iso_datetime(data['start']))
        update_fields.append('start_time')
    if 'end' in data:
        event.end_time = _ensure_aware(parse_iso_datetime(data['end']))
        update_fields.append('end_time')
    if 'allDay' in data:
        event.all_day = data['allDay']
        update_fields.append('all_day')
    if 'color' in data:
        event.color = data['color']
        update_fields.append('color')
    if 'category' in data:
        event.category = data['category']
        update_fields.append('category')
    if 'location' in data:
        event.location = data['location']
        update_fields.append('location')
    if 'attendees' in data:
        event.attendees = data['attendees']
        update_fields.append('attendees')
    if 'recurrence' in data:
        event.recurrence = data['recurrence']
        update_fields.append('recurrence')
    if 'reminders' in data:
        event.reminders = data['reminders']
        update_fields.append('reminders')
    if 'completed' in data:
        event.completed = data['completed']
        update_fields.append('completed')

    if update_fields:
        event.save(update_fields=update_fields)
        logger.info('[Calendar] Updated event id=%s fields=%s', event.id, update_fields)

    if push_to_google:
        _sync_event_to_google(user, event)

    return event


def delete_event(user, pk: int, delete_from_google: bool = False) -> None:
    """
    Delete a CalendarEvent (and optionally remove it from Google Calendar).

    Raises:
        EventNotFound: event does not exist or belongs to a different user.
    """
    try:
        event = CalendarEvent.objects.get(pk=pk, user=user)
    except CalendarEvent.DoesNotExist:
        raise EventNotFound(f'CalendarEvent id={pk} not found for user {user.id}')

    google_event_id = event.google_event_id
    event.delete()
    logger.info('[Calendar] Deleted event id=%s for user %s', pk, user.id)

    if delete_from_google and google_event_id:
        try:
            connection = GoogleCalendarConnection.objects.get(user=user)
            from .google_calendar_service import build_calendar_service, delete_event_from_google
            service = build_calendar_service(connection)
            delete_event_from_google(service, google_event_id, calendar_id=connection.calendar_id)
        except GoogleCalendarConnection.DoesNotExist:
            logger.debug('[Calendar] No Google connection; skipping Google delete for event %s', pk)
        except Exception as exc:
            logger.warning('[Calendar] Google delete failed for event id=%s: %s', pk, exc)


# ── Internal helpers ──────────────────────────────────────────────

def _sync_event_to_google(user, event: 'CalendarEvent') -> None:
    """
    Push a single event to Google Calendar if the user is connected.
    Updates event.google_event_id and event.synced_to_google on success.
    """
    try:
        connection = GoogleCalendarConnection.objects.get(user=user)
        from .google_calendar_service import build_calendar_service, push_event_to_google
        service = build_calendar_service(connection)
        google_event_id = push_event_to_google(service, event, calendar_id=connection.calendar_id)
        event.google_event_id = google_event_id
        event.synced_to_google = True
        event.save(update_fields=['google_event_id', 'synced_to_google'])
    except GoogleCalendarConnection.DoesNotExist:
        logger.debug('[Calendar] No Google connection for user %s; skipping push', user.id)
    except CalendarSyncError as exc:
        logger.warning('[Calendar] Google push failed for event id=%s: %s', event.id, exc)
