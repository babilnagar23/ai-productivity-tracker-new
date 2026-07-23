"""
OAuth Service — handles Google OAuth2 authorization flow.

Responsible for:
  - Building the OAuth2 Flow from Django settings
  - Generating the authorization URL
  - Exchanging an authorization code for tokens
  - Fetching the Google user's email address
  - Persisting the connection to the database

No view logic lives here — this service is pure business logic.
"""
import logging
from urllib.parse import parse_qs, urlencode, urlparse, urlunparse

from django.conf import settings
from django.utils import timezone

from ..constants import SCOPES
from ..exceptions import GoogleAuthError, GoogleDependencyMissing
from ..models import GoogleCalendarConnection

logger = logging.getLogger('calendar')

_OAUTH_CLIENT_CONFIG_KEYS = ('client_id', 'client_secret', 'auth_uri', 'token_uri', 'redirect_uris')


def _build_client_config() -> dict:
    """Construct the Google OAuth2 client config dict from Django settings."""
    if not settings.GOOGLE_CLIENT_ID or not settings.GOOGLE_CLIENT_SECRET:
        raise GoogleAuthError('Google OAuth credentials (GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET) are not configured.')

    return {
        'web': {
            'client_id': settings.GOOGLE_CLIENT_ID,
            'client_secret': settings.GOOGLE_CLIENT_SECRET,
            'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
            'token_uri': 'https://oauth2.googleapis.com/token',
            'redirect_uris': [settings.GOOGLE_REDIRECT_URI],
        }
    }


def _get_flow(redirect_uri=None):
    """
    Create a google_auth_oauthlib.flow.Flow from current settings.

    Raises:
        GoogleDependencyMissing: oauthlib packages not installed.
        GoogleAuthError: credentials not configured.
    """
    try:
        from google_auth_oauthlib.flow import Flow
    except ImportError as exc:
        raise GoogleDependencyMissing(
            'google-auth-oauthlib is not installed. Add it to requirements.txt.'
        ) from exc

    client_config = _build_client_config()
    return Flow.from_client_config(
        client_config,
        scopes=SCOPES,
        redirect_uri=redirect_uri or settings.GOOGLE_REDIRECT_URI,
    )


def generate_auth_url(for_mobile: bool = False) -> str:
    """
    Generate a Google OAuth2 authorization URL.

    Args:
        for_mobile: if True, appends '_mobile' to the state parameter so
                    the callback handler knows to redirect to the app's
                    deep link instead of the web frontend.

    Returns:
        str: authorization URL to redirect the user to.

    Raises:
        GoogleAuthError, GoogleDependencyMissing
    """
    flow = _get_flow()
    auth_url, state = flow.authorization_url(
        access_type='offline',
        include_granted_scopes='true',
        prompt='consent',
    )

    if for_mobile:
        parsed = urlparse(auth_url)
        query = parse_qs(parsed.query)
        if 'state' in query:
            query['state'][0] += '_mobile'
            parsed = parsed._replace(query=urlencode(query, doseq=True))
            auth_url = urlunparse(parsed)

    logger.info('[Calendar] Generated OAuth URL (mobile=%s)', for_mobile)
    return auth_url


def exchange_code_for_tokens(code: str) -> dict:
    """
    Exchange an authorization code for access + refresh tokens.

    Args:
        code: the OAuth2 authorization code from Google's callback.

    Returns:
        dict with keys: access_token, refresh_token, token_uri, scopes, expiry, google_email

    Raises:
        GoogleAuthError: token exchange or user-info fetch failed.
        GoogleDependencyMissing: dependencies not installed.
    """
    if not code:
        raise GoogleAuthError('Authorization code is required.')

    try:
        flow = _get_flow()
        flow.fetch_token(code=code)
        credentials = flow.credentials
    except GoogleDependencyMissing:
        raise
    except Exception as exc:
        logger.error('[Calendar] Token exchange failed: %s', exc)
        raise GoogleAuthError(f'Failed to exchange authorization code: {exc}') from exc

    google_email = _fetch_google_email(credentials)

    expiry = credentials.expiry
    if expiry and timezone.is_naive(expiry):
        expiry = timezone.make_aware(expiry)

    return {
        'access_token': credentials.token or '',
        'refresh_token': credentials.refresh_token or '',
        'token_uri': credentials.token_uri or 'https://oauth2.googleapis.com/token',
        'scopes': list(credentials.scopes or SCOPES),
        'expiry': expiry,
        'google_email': google_email,
    }


def _fetch_google_email(credentials) -> str:
    """
    Retrieve the Google account email from the oauth2 userinfo endpoint.
    Returns empty string on any failure (non-critical).
    """
    try:
        from .google_calendar_service import build_oauth2_service
        service = build_oauth2_service(credentials)
        user_info = service.userinfo().get().execute()
        email = user_info.get('email', '')
        logger.info('[Calendar] Fetched Google email: %s', email)
        return email
    except Exception as exc:
        logger.warning('[Calendar] Could not fetch Google email: %s', exc)
        return ''


def save_connection(user, token_data: dict) -> 'GoogleCalendarConnection':
    """
    Persist (or update) a GoogleCalendarConnection for the given user.

    Args:
        user: Django user instance
        token_data: dict returned by exchange_code_for_tokens()

    Returns:
        GoogleCalendarConnection instance (created or updated)
    """
    connection, created = GoogleCalendarConnection.objects.update_or_create(
        user=user,
        defaults={
            'access_token': token_data['access_token'],
            'refresh_token': token_data['refresh_token'],
            'token_uri': token_data['token_uri'],
            'scopes': token_data['scopes'],
            'expiry': token_data['expiry'],
            'google_email': token_data['google_email'],
        },
    )
    action = 'created' if created else 'updated'
    logger.info('[Calendar] GoogleCalendarConnection %s for user %s', action, user.id)
    return connection


def disconnect(user) -> None:
    """Remove the Google Calendar connection for a user."""
    deleted, _ = GoogleCalendarConnection.objects.filter(user=user).delete()
    logger.info('[Calendar] Disconnected Google Calendar for user %s (deleted=%d)', user.id, deleted)
