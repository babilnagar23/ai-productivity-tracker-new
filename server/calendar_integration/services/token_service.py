"""
Token service — builds Google OAuth2 Credentials from a stored connection.

Responsible for:
  - Constructing google.oauth2.credentials.Credentials from DB values
  - Detecting token expiry
  - (Future) refreshing tokens automatically
"""
import logging

from django.conf import settings
from django.utils import timezone

from ..constants import SCOPES
from ..exceptions import GoogleDependencyMissing

logger = logging.getLogger('calendar')


def get_google_credentials(connection):
    """
    Build a google.oauth2.credentials.Credentials object from a stored
    GoogleCalendarConnection.

    Returns:
        google.oauth2.credentials.Credentials

    Raises:
        GoogleDependencyMissing: google-auth packages not installed.
    """
    try:
        from google.oauth2.credentials import Credentials
    except ImportError as exc:
        raise GoogleDependencyMissing(
            'google-auth is not installed. Add it to requirements.txt.'
        ) from exc

    return Credentials(
        token=connection.access_token,
        refresh_token=connection.refresh_token,
        token_uri=connection.token_uri or 'https://oauth2.googleapis.com/token',
        client_id=settings.GOOGLE_CLIENT_ID,
        client_secret=settings.GOOGLE_CLIENT_SECRET,
        scopes=connection.scopes or SCOPES,
    )


def is_token_expired(connection) -> bool:
    """Return True if the stored access token is expired or will expire soon."""
    if not connection.expiry:
        return False
    buffer = timezone.timedelta(minutes=5)
    return timezone.now() >= (connection.expiry - buffer)
