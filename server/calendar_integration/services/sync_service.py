"""
Sync Service — bidirectional sync between local CalendarEvents and Google Calendar.

Responsible for:
  - Pushing routine logs to Google Calendar as events
  - Pulling Google Calendar events into local CalendarEvent records
  - Recording SyncLog entries
"""
import logging
from datetime import datetime, timedelta

from django.conf import settings
from django.utils import timezone

from ..exceptions import CalendarSyncError, GoogleDependencyMissing
from ..models import CalendarEvent, GoogleCalendarConnection, SyncLog
from .google_calendar_service import build_calendar_service, fetch_google_events, push_event_to_google

logger = logging.getLogger('calendar')


def sync_routines_to_google(user, routines) -> int:
    """
    Push routine log entries to Google Calendar as events.

    Args:
        user: Django user instance
        routines: queryset or list of Routine instances

    Returns:
        int: number of events successfully created on Google Calendar

    Raises:
        CalendarSyncError: connection or API failure
    """
    try:
        connection = GoogleCalendarConnection.objects.get(user=user)
    except GoogleCalendarConnection.DoesNotExist:
        raise CalendarSyncError('Google Calendar is not connected for this user.')

    service = build_calendar_service(connection)

    created = 0
    for routine in routines:
        try:
            start = datetime.combine(
                routine.date,
                datetime.strptime(routine.wake_time, '%H:%M').time(),
            )
            start = timezone.make_aware(start) if timezone.is_naive(start) else start
            end = start + timedelta(minutes=30)

            event_body = {
                'summary': 'Productivity Tracker Daily Routine Review',
                'description': (
                    f'Score: {routine.productivity_score}%. '
                    f'Notes: {routine.notes}'
                ),
                'start': {'dateTime': start.isoformat()},
                'end': {'dateTime': end.isoformat()},
                'reminders': {
                    'useDefault': False,
                    'overrides': [{'method': 'popup', 'minutes': 10}],
                },
            }
            service.events().insert(
                calendarId=connection.calendar_id,
                body=event_body,
            ).execute()
            created += 1
        except Exception as exc:
            logger.warning(
                '[Calendar] Routine sync failed for routine %s: %s',
                routine.date,
                exc,
            )
            continue

    SyncLog.objects.create(
        user=user,
        direction='push',
        status='success' if created > 0 else 'partial',
        events_synced=created,
    )
    logger.info('[Calendar] Pushed %d routine events to Google for user %s', created, user.id)
    return created


def pull_google_events_to_local(user, days_back: int = 30, days_ahead: int = 60) -> dict:
    """
    Fetch events from Google Calendar and upsert them into local CalendarEvent records.

    Args:
        user: Django user instance
        days_back: how many days in the past to pull
        days_ahead: how many days in the future to pull

    Returns:
        dict with keys: created, updated, total

    Raises:
        CalendarSyncError: connection or API failure
    """
    try:
        connection = GoogleCalendarConnection.objects.get(user=user)
    except GoogleCalendarConnection.DoesNotExist:
        raise CalendarSyncError('Google Calendar is not connected for this user.')

    service = build_calendar_service(connection)

    now = timezone.now()
    time_min = now - timedelta(days=days_back)
    time_max = now + timedelta(days=days_ahead)

    google_events = fetch_google_events(
        service,
        calendar_id=connection.calendar_id,
        time_min=time_min,
        time_max=time_max,
    )

    created = updated = 0
    for g_event in google_events:
        google_event_id = g_event.get('id', '')
        if not google_event_id:
            continue

        start_raw = g_event.get('start', {})
        end_raw = g_event.get('end', {})

        start_str = start_raw.get('dateTime') or start_raw.get('date', '')
        end_str = end_raw.get('dateTime') or end_raw.get('date', '')

        if not start_str or not end_str:
            continue

        try:
            from .event_service import parse_iso_datetime, _ensure_aware
            start_time = _ensure_aware(parse_iso_datetime(start_str))
            end_time = _ensure_aware(parse_iso_datetime(end_str))
        except Exception as exc:
            logger.warning('[Calendar] Skipping Google event %s — bad dates: %s', google_event_id, exc)
            continue

        all_day = 'date' in start_raw and 'dateTime' not in start_raw

        defaults = {
            'title': g_event.get('summary', 'Google Event'),
            'description': g_event.get('description', ''),
            'location': g_event.get('location', ''),
            'start_time': start_time,
            'end_time': end_time,
            'all_day': all_day,
            'synced_to_google': True,
        }

        obj, was_created = CalendarEvent.objects.update_or_create(
            user=user,
            google_event_id=google_event_id,
            defaults=defaults,
        )

        if was_created:
            created += 1
        else:
            updated += 1

    SyncLog.objects.create(
        user=user,
        direction='pull',
        status='success',
        events_synced=created + updated,
    )

    result = {'created': created, 'updated': updated, 'total': created + updated}
    logger.info('[Calendar] Pull from Google for user %s: %s', user.id, result)
    return result
