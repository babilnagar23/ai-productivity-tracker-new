"""
Django settings for AI Productivity Tracker.

All configuration is driven by environment variables.
Required variables are validated at startup via validate_env().
"""
import os
import logging
from datetime import timedelta
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured
from dotenv import load_dotenv
import dj_database_url


BASE_DIR = Path(__file__).resolve().parent.parent

# Load .env from server/ directory
load_dotenv(BASE_DIR / '.env')

# ── Environment Validation ─────────────────────────────────────────
def validate_env():
    """
    Validate required environment variables at startup.

    Raises ImproperlyConfigured with a developer-friendly message
    if any required variable is missing or obviously invalid.
    Never runs in test mode (manage.py test / pytest).
    """
    import sys
    # Skip validation during test runs and manage.py check commands
    is_test = (
        'test' in sys.argv
        or 'pytest' in sys.modules
        or os.getenv('DJANGO_TESTING') == '1'
    )
    if is_test:
        return

    _debug = os.getenv('DEBUG', 'False').lower() == 'true'

    required = {
        'DJANGO_SECRET_KEY': 'A long random secret key for Django.',
    }

    # In production these are also required
    if not _debug:
        required.update({
            'DATABASE_URL': 'PostgreSQL connection string, e.g. postgresql://user:pass@host:5432/db',
            'EMAIL_HOST': 'SMTP server hostname.',
            'EMAIL_HOST_USER': 'SMTP login username / sender address.',
            'EMAIL_HOST_PASSWORD': 'SMTP password or app-specific password.',
            'GROQ_API_KEY': 'Groq API key from https://console.groq.com/keys',
            'GOOGLE_CLIENT_ID': 'Google OAuth2 client ID.',
            'GOOGLE_CLIENT_SECRET': 'Google OAuth2 client secret.',
            'GOOGLE_REDIRECT_URI': 'Authorised redirect URI registered in Google Cloud Console.',
            'ALLOWED_HOSTS': 'Comma-separated list of allowed hostnames.',
        })

    missing = []
    for var, hint in required.items():
        if not os.getenv(var, '').strip():
            missing.append(f"  • {var}: {hint}")

    if missing:
        lines = '\n'.join(missing)
        raise ImproperlyConfigured(
            f"\n\n{'='*60}\n"
            f"MISSING REQUIRED ENVIRONMENT VARIABLES\n"
            f"{'='*60}\n"
            f"{lines}\n\n"
            f"Add these to your server/.env file (or deployment environment).\n"
            f"See .env.example for the full list of supported variables.\n"
            f"{'='*60}\n"
        )

    # Production-specific sanity checks
    if not _debug:
        secret = os.getenv('DJANGO_SECRET_KEY', '')
        if len(secret) < 40:
            raise ImproperlyConfigured(
                "DJANGO_SECRET_KEY must be at least 40 characters long in production. "
                "Generate one with: python -c \"from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())\""
            )

        cors_all = os.getenv('CORS_ALLOW_ALL_ORIGINS', 'False').lower() == 'true'
        if cors_all:
            raise ImproperlyConfigured(
                "CORS_ALLOW_ALL_ORIGINS=True is not allowed in production (DEBUG=False). "
                "Set CORS_ALLOWED_ORIGINS to your specific frontend domain(s)."
            )


# Run validation immediately at import time
validate_env()

# ── Core Settings ──────────────────────────────────────────────────
_SECRET_KEY = os.getenv('DJANGO_SECRET_KEY')
if not _SECRET_KEY:
    # Only reached in development/test where validate_env() is skipped
    _SECRET_KEY = 'dev-only-insecure-key-change-in-production-immediately'

SECRET_KEY = _SECRET_KEY
DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'
ALLOWED_HOSTS = [h.strip() for h in os.getenv('ALLOWED_HOSTS', '127.0.0.1,localhost').split(',') if h.strip()]

# ── Celery ─────────────────────────────────────────────────────────
CELERY_BROKER_URL = os.getenv('REDIS_URL', 'redis://127.0.0.1:6379/0')
CELERY_RESULT_BACKEND = os.getenv('REDIS_URL', 'redis://127.0.0.1:6379/1')
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = 120
CELERY_TASK_SOFT_TIME_LIMIT = 100
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_WORKER_MAX_TASKS_PER_CHILD = 100  # Prevent memory leaks in long-running workers
CELERY_TASK_ACKS_LATE = True            # Only ack after successful execution
CELERY_WORKER_PREFETCH_MULTIPLIER = 1   # Fair task distribution

# ── Installed Apps ─────────────────────────────────────────────────
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'corsheaders',
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    # Project apps
    'users',
    'routines',
    'analytics_app',
    'ai_assistant',
    'calendar_integration',
    'productivity_ai',
    'common',
    'todos',
    'focus',
    'notifications',
    'health',
]

# ── Middleware ─────────────────────────────────────────────────────
# CorsMiddleware MUST be before CommonMiddleware and SessionMiddleware.
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# ── CORS ───────────────────────────────────────────────────────────
CORS_ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        'CORS_ALLOWED_ORIGINS',
        'http://localhost:5173,http://127.0.0.1:5173,http://localhost:3000,'
        'http://127.0.0.1:3000,http://localhost:8080,http://localhost:52000,http://localhost:52001',
    ).split(',')
    if origin.strip()
]
CORS_ALLOW_ALL_ORIGINS = os.getenv('CORS_ALLOW_ALL_ORIGINS', 'False').lower() == 'true'
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_HEADERS = [
    'accept',
    'authorization',
    'content-type',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
]

CSRF_TRUSTED_ORIGINS = CORS_ALLOWED_ORIGINS

APPEND_SLASH = False

ROOT_URLCONF = 'server.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'server.wsgi.application'

# ── Database ───────────────────────────────────────────────────────
DATABASES = {
    'default': dj_database_url.config(
        default=os.getenv('DATABASE_URL') or f'sqlite:///{BASE_DIR / "db.sqlite3"}',
        conn_max_age=60,            # Persistent connections (pool-like behaviour)
        conn_health_checks=True,    # Verify connection health before reuse
    )
}

if DATABASES['default'].get('ENGINE') == 'django.db.backends.sqlite3':
    _db_path = Path(DATABASES['default']['NAME'])
    if not _db_path.is_absolute():
        DATABASES['default']['NAME'] = str(BASE_DIR / _db_path.name)

# ── Password Validation ────────────────────────────────────────────
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
        'OPTIONS': {'min_length': 8},
    },
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = os.getenv('TIME_ZONE', 'Asia/Kolkata')
USE_I18N = True
USE_TZ = True

# ── Static Files ───────────────────────────────────────────────────
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ── Django REST Framework ──────────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '60/min',
        'user': '300/min',
        'ai_chat': '10/min',
        'ai_plan': '5/min',
        'login': '5/15min',
        'otp': '5/10min',
    },
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 50,
}

# ── Simple JWT ─────────────────────────────────────────────────────
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=int(os.getenv('JWT_ACCESS_MINUTES', '60'))),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=int(os.getenv('JWT_REFRESH_DAYS', '30'))),
    'AUTH_HEADER_TYPES': ('Bearer',),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN': True,
    'AUTH_COOKIE': 'refresh_token',
    'AUTH_COOKIE_DOMAIN': None,
    'AUTH_COOKIE_SECURE': not DEBUG,
    'AUTH_COOKIE_HTTP_ONLY': True,
    'AUTH_COOKIE_PATH': '/api/auth/',
    'AUTH_COOKIE_SAMESITE': 'None' if not DEBUG else 'Lax',
}

# ── Groq AI ────────────────────────────────────────────────────────
GROQ_API_KEY = os.getenv('GROQ_API_KEY', '')
GROQ_MODEL = os.getenv('GROQ_MODEL', 'openai/gpt-oss-20b')

# ── Google OAuth / Calendar ────────────────────────────────────────
GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID', '')
GOOGLE_CLIENT_SECRET = os.getenv('GOOGLE_CLIENT_SECRET', '')
GOOGLE_REDIRECT_URI = os.getenv(
    'GOOGLE_REDIRECT_URI',
    'http://127.0.0.1:8000/api/calendar/callback',
)

# ── Email Settings ────────────────────────────────────────────────
_email_configured = bool(os.getenv('EMAIL_HOST_USER') and os.getenv('EMAIL_HOST_PASSWORD'))

if _email_configured:
    EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
elif DEBUG:
    # Console backend is acceptable during local development
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
else:
    # Production without credentials: fail loudly rather than silently swallow emails
    EMAIL_BACKEND = 'django.core.mail.backends.dummy.EmailBackend'
    import warnings
    warnings.warn(
        "EMAIL_HOST_USER / EMAIL_HOST_PASSWORD are not set. "
        "Emails will be silently discarded (DummyBackend). "
        "Set SMTP credentials to send real emails.",
        RuntimeWarning,
        stacklevel=2,
    )

EMAIL_HOST = os.getenv('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT = int(os.getenv('EMAIL_PORT', '587'))
EMAIL_HOST_USER = os.getenv('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.getenv('EMAIL_HOST_PASSWORD', '')
EMAIL_USE_TLS = os.getenv('EMAIL_USE_TLS', 'True').lower() == 'true'
# Fixed: no spaces in domain name
DEFAULT_FROM_EMAIL = os.getenv(
    'DEFAULT_FROM_EMAIL',
    EMAIL_HOST_USER or 'noreply@productivitytracker.app',
)
SERVER_EMAIL = DEFAULT_FROM_EMAIL

# ── Frontend URL ──────────────────────────────────────────────────
FRONTEND_URL = os.getenv('FRONTEND_URL', 'http://localhost:5173')

# ── Security Headers (production only) ───────────────────────────
if not DEBUG:
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = 'DENY'
    # Enable HSTS only if your domain has full HTTPS coverage
    SECURE_HSTS_SECONDS = int(os.getenv('SECURE_HSTS_SECONDS', '0'))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = SECURE_HSTS_SECONDS > 0
    SECURE_HSTS_PRELOAD = SECURE_HSTS_SECONDS > 0
    # Redirect HTTP → HTTPS (set SECURE_SSL_REDIRECT=False behind a load balancer)
    SECURE_SSL_REDIRECT = os.getenv('SECURE_SSL_REDIRECT', 'False').lower() == 'true'
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True

# ── Version ───────────────────────────────────────────────────────
APP_VERSION = os.getenv('APP_VERSION', '1.0.0')

# ── Logging ───────────────────────────────────────────────────────
LOGS_DIR = BASE_DIR / 'logs'
LOGS_DIR.mkdir(exist_ok=True)

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,

    'formatters': {
        'verbose': {
            'format': '[{asctime}] [{levelname}] [{name}] [{process:d}] {message}',
            'style': '{',
            'datefmt': '%Y-%m-%d %H:%M:%S',
        },
        'simple': {
            'format': '[{levelname}] {name}: {message}',
            'style': '{',
        },
        'json_like': {
            'format': '[{asctime}] {levelname} {name} | {message}',
            'style': '{',
            'datefmt': '%Y-%m-%dT%H:%M:%S',
        },
    },

    'filters': {
        'require_debug_false': {
            '()': 'django.utils.log.RequireDebugFalse',
        },
        'require_debug_true': {
            '()': 'django.utils.log.RequireDebugTrue',
        },
    },

    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
        'file_general': {
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': str(LOGS_DIR / 'django.log'),
            'maxBytes': 10 * 1024 * 1024,   # 10 MB
            'backupCount': 5,
            'formatter': 'verbose',
            'encoding': 'utf-8',
        },
        'file_errors': {
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': str(LOGS_DIR / 'errors.log'),
            'maxBytes': 10 * 1024 * 1024,   # 10 MB
            'backupCount': 5,
            'level': 'ERROR',
            'formatter': 'verbose',
            'encoding': 'utf-8',
        },
    },

    'root': {
        'handlers': ['console', 'file_general'],
        'level': 'INFO',
    },

    'loggers': {
        # Django internals
        'django': {
            'handlers': ['console', 'file_general'],
            'level': 'INFO',
            'propagate': False,
        },
        'django.request': {
            'handlers': ['console', 'file_errors'],
            'level': 'WARNING',
            'propagate': False,
        },
        'django.db.backends': {
            'handlers': ['console'],
            'level': 'WARNING',    # Set to DEBUG to see raw SQL queries
            'propagate': False,
        },

        # Application loggers
        'users.auth': {
            'handlers': ['console', 'file_general'],
            'level': 'INFO',
            'propagate': False,
        },
        'users.otp': {
            'handlers': ['console', 'file_general'],
            'level': 'INFO',
            'propagate': False,
        },
        'users.email': {
            'handlers': ['console', 'file_general', 'file_errors'],
            'level': 'INFO',
            'propagate': False,
        },
        'users': {
            'handlers': ['console', 'file_general'],
            'level': 'INFO',
            'propagate': False,
        },
        'ai': {
            'handlers': ['console', 'file_general', 'file_errors'],
            'level': 'INFO',
            'propagate': False,
        },
        'celery.tasks': {
            'handlers': ['console', 'file_general', 'file_errors'],
            'level': 'INFO',
            'propagate': False,
        },
        'calendar': {
            'handlers': ['console', 'file_general', 'file_errors'],
            'level': 'INFO',
            'propagate': False,
        },
        'health': {
            'handlers': ['console', 'file_general'],
            'level': 'INFO',
            'propagate': False,
        },
        'security': {
            'handlers': ['console', 'file_errors'],
            'level': 'WARNING',
            'propagate': False,
        },
    },
}
