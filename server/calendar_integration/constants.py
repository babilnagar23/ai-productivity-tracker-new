"""
Constants for Google Calendar integration.
"""

# Google OAuth scopes
SCOPES = [
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/userinfo.email',
    'openid',
]

# Internal color name → hex value
COLOR_MAP = {
    'blue': '#3B82F6',
    'purple': '#8B5CF6',
    'green': '#10B981',
    'pink': '#EC4899',
    'orange': '#F59E0B',
    'cyan': '#06B6D4',
    'red': '#EF4444',
}

# Internal color name → Google Calendar colorId
GOOGLE_COLOR_MAP = {
    'blue': '9',
    'purple': '3',
    'green': '2',
    'pink': '4',
    'orange': '6',
    'cyan': '7',
    'red': '11',
}

# Default event duration when creating reminders
DEFAULT_EVENT_DURATION_MINUTES = 30
