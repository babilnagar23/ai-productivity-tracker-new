"""
Health check views.

GET /health/  — returns system status for deployment platform monitoring.

Response shape:
  {
    "status": "healthy" | "degraded",
    "database": "connected" | "error: ...",
    "redis": "connected" | "error: ...",
    "email": "configured" | "not_configured",
    "google_calendar": "configured" | "not_configured",
    "ai": "configured" | "not_configured",
    "environment": "ok" | "missing: VAR1, VAR2",
    "disk": "ok (X%)" | "warning (X%)" | "error: ...",
    "memory": "ok (X%)" | "warning (X%)" | "error: ...",
    "version": "1.0.0"
  }

Returns HTTP 200 when healthy, HTTP 503 when any critical check fails.
"""
import logging
import os

from django.conf import settings
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

logger = logging.getLogger('health')

_CRITICAL_VARS = [
    'DJANGO_SECRET_KEY',
    'DATABASE_URL',
]
_PRODUCTION_VARS = [
    'EMAIL_HOST_USER',
    'EMAIL_HOST_PASSWORD',
    'GROQ_API_KEY',
    'GOOGLE_CLIENT_ID',
    'GOOGLE_CLIENT_SECRET',
]

DISK_WARNING_PCT = 85
DISK_CRITICAL_PCT = 95
MEMORY_WARNING_PCT = 85
MEMORY_CRITICAL_PCT = 95


# ── Individual checks ─────────────────────────────────────────────

def _check_database() -> tuple[str, bool]:
    """Return (status_string, is_healthy)."""
    try:
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
        return 'connected', True
    except Exception as exc:
        return f'error: {exc}', False


def _check_redis() -> tuple[str, bool]:
    """Return (status_string, is_healthy)."""
    redis_url = getattr(settings, 'CELERY_BROKER_URL', '')
    if not redis_url:
        return 'not_configured', True  # Not a critical failure if Redis not needed

    try:
        import redis
        client = redis.from_url(redis_url, socket_connect_timeout=3)
        client.ping()
        return 'connected', True
    except ImportError:
        return 'redis package not installed', False
    except Exception as exc:
        return f'error: {exc}', False


def _check_email() -> tuple[str, bool]:
    """Return (status_string, is_healthy). Email misconfiguration is non-critical."""
    if os.getenv('EMAIL_HOST_USER') and os.getenv('EMAIL_HOST_PASSWORD'):
        return 'configured', True
    return 'not_configured', True  # Warning but not critical


def _check_google_calendar() -> tuple[str, bool]:
    """Return (status_string, is_healthy). Calendar config is non-critical."""
    if os.getenv('GOOGLE_CLIENT_ID') and os.getenv('GOOGLE_CLIENT_SECRET'):
        return 'configured', True
    return 'not_configured', True


def _check_ai() -> tuple[str, bool]:
    """Return (status_string, is_healthy). AI config is non-critical."""
    if os.getenv('GROQ_API_KEY'):
        return 'configured', True
    return 'not_configured', True


def _check_environment() -> tuple[str, bool]:
    """Verify critical environment variables are present."""
    missing = [v for v in _CRITICAL_VARS if not os.getenv(v, '').strip()]
    if missing:
        return f"missing: {', '.join(missing)}", False
    return 'ok', True


def _check_disk() -> tuple[str, bool]:
    """Return disk usage status. psutil is optional."""
    try:
        import psutil
        usage = psutil.disk_usage('/').percent
        if usage >= DISK_CRITICAL_PCT:
            return f'critical ({usage:.0f}%)', False
        if usage >= DISK_WARNING_PCT:
            return f'warning ({usage:.0f}%)', True
        return f'ok ({usage:.0f}%)', True
    except ImportError:
        return 'psutil not installed', True
    except Exception as exc:
        return f'error: {exc}', True


def _check_memory() -> tuple[str, bool]:
    """Return memory usage status. psutil is optional."""
    try:
        import psutil
        usage = psutil.virtual_memory().percent
        if usage >= MEMORY_CRITICAL_PCT:
            return f'critical ({usage:.0f}%)', False
        if usage >= MEMORY_WARNING_PCT:
            return f'warning ({usage:.0f}%)', True
        return f'ok ({usage:.0f}%)', True
    except ImportError:
        return 'psutil not installed', True
    except Exception as exc:
        return f'error: {exc}', True


# ── View ──────────────────────────────────────────────────────────

class HealthCheckView(APIView):
    """
    Public health check endpoint for deployment platforms.

    Returns 200 when all critical checks pass, 503 otherwise.
    """
    permission_classes = [AllowAny]
    authentication_classes = []  # No auth overhead for health checks

    # Map of check_name → (check_function, is_critical)
    _CHECKS = [
        ('database', _check_database, True),
        ('redis', _check_redis, True),
        ('email', _check_email, False),
        ('google_calendar', _check_google_calendar, False),
        ('ai', _check_ai, False),
        ('environment', _check_environment, True),
        ('disk', _check_disk, False),
        ('memory', _check_memory, False),
    ]

    def get(self, request):
        results = {}
        all_healthy = True

        checks = [
            ('database', _check_database, True),
            ('redis', _check_redis, True),
            ('email', _check_email, False),
            ('google_calendar', _check_google_calendar, False),
            ('ai', _check_ai, False),
            ('environment', _check_environment, True),
            ('disk', _check_disk, False),
            ('memory', _check_memory, False),
        ]

        for name, check_fn, is_critical in checks:
            try:
                status_str, healthy = check_fn()
            except Exception as exc:
                status_str = f'error: {exc}'
                healthy = False

            results[name] = status_str

            if not healthy and is_critical:
                all_healthy = False
                logger.error('[Health] Critical check failed — %s: %s', name, status_str)
            elif not healthy:
                logger.warning('[Health] Non-critical check failed — %s: %s', name, status_str)

        overall = 'healthy' if all_healthy else 'degraded'
        results['status'] = overall
        results['version'] = getattr(settings, 'APP_VERSION', '1.0.0')

        http_status = 200 if all_healthy else 503
        logger.info('[Health] Check completed — status=%s', overall)
        return Response(results, status=http_status)
