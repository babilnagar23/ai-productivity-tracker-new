"""
Google Calendar Service — wraps the Google Calendar API client.

Responsible for:
  - Building the googleapiclient service instance
  - Pushing / updating / deleting events on Google Calendar
  - Pulling events from Google Calendar

All raw Google API calls live here. No view code touches the API directly.
"""
import logging

from django.conf import settings

from ..constants import GOOGLE_COLOR_MAP, SCOPES
from ..exceptions import CalendarSyncError, GoogleDependencyMissing
from .token_service import get_google_credentials

logger = logging.getLogger('calendar')


def build_calendar_service(connection):
    """
    Build and return an authenticated Google Calendar v3 API service.

    Args:
        connection: GoogleCalendarConnection instance

    Returns:
        googleapiclient.discovery.Resource (calendar v3)

    Raises:
        GoogleDependencyMissing: google-api-python-client not installed.
        CalendarSyncError: credential or connection error.
    """
    try:
        from googleapiclient.discovery import build
    except ImportError as exc:
        raise GoogleDependencyMissing(
            'google-api-python-client is not installed. Add it to requirements.txt.'
        ) from exc

    try:
        credentials = get_google_credentials(connection)
        service = build('calendar', 'v3', credentials=credentials)
        logger.debug('[Calendar] Service built for user %s', connection.user_id)
        return service
    except GoogleDependencyMissing:
        raise
    except Exception as exc:
        logger.error('[Calendar] Failed to build service for user %s: %s', connection.user_id, exc)
        raise CalendarSyncError(f'Failed to connect to Google Calendar: {exc}') from exc


def build_oauth2_service(credentials):
    """
    Build and return a Google oauth2 v2 API service (for fetching user info).

    Args:
        credentials: google.oauth2.credentials.Credentials

    Returns:
        googleapiclient.discovery.Resource (oauth2 v2)
    """
    try:
        from googleapiclient.discovery import build
    except ImportError as exc:
        raise GoogleDependencyMissing(
            'google-api-python-client is not installed.'
        ) from exc

    return build('oauth2', 'v2', credentials=credentials)


def push_event_to_google(service, event, calendar_id='primary'):
    """
    Insert or update a CalendarEvent on Google Calendar.

    Args:
        service: authenticated googleapiclient service
        event: CalendarEvent model instance
        calendar_id: Google Calendar ID (default 'primary')

    Returns:
        str: The Google event ID returned by the API.

    Raises:
        CalendarSyncError: on API failure.
    """
    body = {
        'summary': event.title,
        'description': event.description,
        'location': event.location,
        'start': {'dateTime': event.start_time.isoformat(), 'timeZone': settings.TIME_ZONE},
        'end': {'dateTime': event.end_time.isoformat(), 'timeZone': settings.TIME_ZONE},
        'colorId': GOOGLE_COLOR_MAP.get(event.color, '9'),
        'reminders': {
            'useDefault': False,
            'overrides': [
                {'method': 'popup', 'minutes': r}
                for r in (event.reminders or [10])
            ],
        },
    }
    if event.recurrence:
        body['recurrence'] = event.recurrence
    if event.attendees:
        body['attendees'] = [{'email': a} for a in event.attendees]

    try:
        if event.google_event_id:
            result = service.events().update(
                calendarId=calendar_id,
                eventId=event.google_event_id,
                body=body,
            ).execute()
            logger.info('[Calendar] Updated Google event %s for event id=%s', result.get('id'), event.id)
        else:
            result = service.events().insert(
                calendarId=calendar_id,
                body=body,
            ).execute()
            logger.info('[Calendar] Created Google event %s for event id=%s', result.get('id'), event.id)

        return result.get('id', '')

    except Exception as exc:
        logger.error('[Calendar] push_event_to_google failed for event id=%s: %s', event.id, exc)
        raise CalendarSyncError(f'Google Calendar push failed: {exc}') from exc


def delete_event_from_google(service, google_event_id, calendar_id='primary'):
    """
    Delete an event from Google Calendar by its Google event ID.

    Raises:
        CalendarSyncError: on API failure.
    """
    try:
        service.events().delete(calendarId=calendar_id, eventId=google_event_id).execute()
        logger.info('[Calendar] Deleted Google event %s', google_event_id)
    except Exception as exc:
        logger.error('[Calendar] delete_event_from_google failed for %s: %s', google_event_id, exc)
        raise CalendarSyncError(f'Google Calendar delete failed: {exc}') from exc


def fetch_google_events(service, calendar_id='primary', time_min=None, time_max=None, max_results=250):
    """
    Pull events from a Google Calendar within an optional time window.

    Args:
        service: authenticated googleapiclient service
        calendar_id: Google Calendar ID
        time_min: datetime (inclusive lower bound)
        time_max: datetime (inclusive upper bound)
        max_results: maximum number of events to retrieve

    Returns:
        list[dict]: raw Google Calendar event dicts.

    Raises:
        CalendarSyncError: on API failure.
    """
    kwargs = {
        'calendarId': calendar_id,
        'maxResults': max_results,
        'singleEvents': True,
        'orderBy': 'startTime',
    }
    if time_min:
        kwargs['timeMin'] = time_min.isoformat()
    if time_max:
        kwargs['timeMax'] = time_max.isoformat()

    try:
        result = service.events().list(**kwargs).execute()
        events = result.get('items', [])
        logger.info('[Calendar] Fetched %d Google events', len(events))
        return events
    except Exception as exc:
        logger.error('[Calendar] fetch_google_events failed: %s', exc)
        raise CalendarSyncError(f'Google Calendar fetch failed: {exc}') from exc
