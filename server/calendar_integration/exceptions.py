"""
Custom exceptions for the calendar_integration app.

All exceptions here derive from CalendarBaseError so callers can catch
the entire family with a single except clause where appropriate.
"""


class CalendarBaseError(Exception):
    """Base class for all calendar integration errors."""


class GoogleAuthError(CalendarBaseError):
    """
    Raised when Google OAuth fails — e.g. invalid/expired code,
    missing credentials, or token exchange error.
    """


class CalendarSyncError(CalendarBaseError):
    """
    Raised when a sync operation fails — e.g. Google API error,
    network timeout, or invalid event data.
    """


class GoogleDependencyMissing(CalendarBaseError):
    """
    Raised when the google-api-python-client / google-auth-oauthlib
    packages are not installed.
    """


class EventNotFound(CalendarBaseError):
    """Raised when a CalendarEvent lookup returns no result."""


class AIScheduleError(CalendarBaseError):
    """Raised when AI schedule generation or application fails."""
