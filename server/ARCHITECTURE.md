# Backend Architecture

## Overview

The Django backend follows a **service-oriented architecture** where views are thin HTTP handlers and all business logic lives in dedicated service modules.

## Request Flow

```
Client (React / Flutter)
    ↓  HTTP Request
DRF View (validate input)
    ↓  call service
Service Layer (business logic)
    ↓  query / mutate
Django ORM / Google API / Groq API
    ↓  result
Service Layer (format result)
    ↓  return dict/object
DRF View (return Response)
    ↑  JSON Response
Client
```

## App Structure

```
server/
├── server/               # Django project config
│   ├── settings.py       # All configuration, startup validation, logging
│   ├── urls.py           # Root URL routing
│   └── celery.py         # Celery app instance
│
├── health/               # Health check endpoint (GET /health/)
│   ├── views.py          # 8 subsystem checks → 200/503
│   └── urls.py
│
├── users/                # Authentication & user management
│   ├── models.py         # UserProfile, EmailOTP
│   ├── views.py          # Auth views (login, register, OTP, etc.)
│   ├── sync_views.py     # Bidirectional mobile/web sync
│   ├── email_utils.py    # SMTP email templates
│   ├── serializers.py    # DRF serializers
│   └── signals.py        # Auto-create UserProfile on user save
│
├── routines/             # Daily routine logging
│   ├── models.py         # Routine (with DB indexes)
│   └── serializers.py
│
├── calendar_integration/ # Google Calendar integration
│   ├── constants.py      # SCOPES, COLOR_MAP, GOOGLE_COLOR_MAP
│   ├── exceptions.py     # Typed exceptions hierarchy
│   ├── models.py         # CalendarEvent, GoogleCalendarConnection, etc.
│   ├── views.py          # Thin views (~300 lines, was 1030)
│   └── services/
│       ├── oauth_service.py          # OAuth2 flow, code exchange, token storage
│       ├── token_service.py          # Credential building, expiry detection
│       ├── google_calendar_service.py # Raw Google API calls
│       ├── sync_service.py           # Routine push + Google pull
│       ├── event_service.py          # CalendarEvent CRUD + serialization
│       ├── ai_schedule_service.py    # AI schedule generation + apply
│       └── insight_service.py        # AI productivity insights
│
├── ai_assistant/         # AI coaching
│   ├── models.py         # AiJob (async job queue)
│   ├── views.py          # generate-plan, analyze, chat, job-status
│   └── tasks.py          # Celery: process_ai_job
│
├── common/               # Shared utilities
│   └── groq_client.py    # Groq API client (all AI calls route here)
│
├── analytics_app/        # Analytics endpoints
├── todos/                # Todo management
├── focus/                # Focus session tracking
├── notifications/        # Notification records
└── productivity_ai/      # (Placeholder for future AI features)
```

## Logging Architecture

| Logger | Purpose | Handlers |
|--------|---------|----------|
| `users.auth` | Login, logout, registration | console + file |
| `users.otp` | OTP send/verify | console + file |
| `users.email` | Email send/fail | console + file + errors |
| `ai` | Groq API calls, prompts | console + file + errors |
| `celery.tasks` | Async job status | console + file + errors |
| `calendar` | OAuth, sync, events | console + file + errors |
| `health` | Health check results | console + file |
| `security` | Rate limits, auth events | console + errors |

Log files:
- `server/logs/django.log` — rotating, 10 MB × 5 backups (all INFO+)
- `server/logs/errors.log` — rotating, 10 MB × 5 backups (ERROR+ only)

## Database Indexes

| Model | Index | Purpose |
|-------|-------|---------|
| `EmailOTP` | `(email, is_verified)` | OTP lookup |
| `Routine` | `(user, -date)`, `(date)` | Analytics queries |
| `Todo` | `(user, completed)`, `(due_date)` | Task filtering |
| `CalendarEvent` | `(user, start_time)`, `(google_event_id)` | Date range queries |
| `AiJob` | `(user, status)`, `(user, -created_at)` | Job status polling |
| `NotificationRecord` | `(user, -created_at)`, `(user, read_at)` | Feed queries |
| `FocusSession` | `(user, -start_time)`, `(user, completed)` | Analytics |

## Rate Limiting

| Endpoint | Rate | Key |
|----------|------|-----|
| `POST /api/auth/login` | 5/15min | IP |
| `POST /api/auth/forgot-password` | 3/hour | IP |
| `POST /api/auth/send-otp` | 5/10min | IP |
| `POST /api/auth/verify-otp` | 5/10min | IP |
| `POST /api/ai/generate-plan` | 5/min | user or IP |
| `POST /api/ai/analyze` | 5/min | user or IP |
| `POST /api/ai/chat` | 10/min | user or IP |

## Security Headers (production)

```python
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
```

## Celery Configuration

- `CELERY_TASK_ACKS_LATE = True` — only ack after successful execution
- `CELERY_WORKER_MAX_TASKS_PER_CHILD = 100` — prevent memory leaks
- `CELERY_WORKER_PREFETCH_MULTIPLIER = 1` — fair distribution
- Exponential backoff: 5s → 25s → 125s on retry
