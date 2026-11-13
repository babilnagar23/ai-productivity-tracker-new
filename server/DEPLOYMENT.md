# Deployment Guide

## Environment Variables Reference

All variables go in `server/.env` (local) or your deployment platform's environment settings.

| Variable | Required | Description |
|----------|----------|-------------|
| `DJANGO_SECRET_KEY` | ✅ Always | Long random secret. Generate with `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"` |
| `DATABASE_URL` | ✅ Always | PostgreSQL connection string: `postgresql://user:pass@host:5432/db` |
| `DEBUG` | ✅ Always | `False` in production |
| `ALLOWED_HOSTS` | ✅ Prod | Comma-separated hostnames, e.g. `myapi.onrender.com` |
| `CORS_ALLOWED_ORIGINS` | ✅ Prod | Frontend URL(s), e.g. `https://myapp.vercel.app` |
| `EMAIL_HOST` | ⚠️ Prod | SMTP hostname, e.g. `smtp.gmail.com` |
| `EMAIL_HOST_USER` | ⚠️ Prod | SMTP username / sender email |
| `EMAIL_HOST_PASSWORD` | ⚠️ Prod | SMTP password or app-specific password |
| `GROQ_API_KEY` | ⚠️ Prod | Groq API key from console.groq.com |
| `GROQ_MODEL` | Optional | Groq model identifier (default: `openai/gpt-oss-20b`) |
| `GOOGLE_CLIENT_ID` | ⚠️ Prod | Google OAuth2 client ID |
| `GOOGLE_CLIENT_SECRET` | ⚠️ Prod | Google OAuth2 client secret |
| `GOOGLE_REDIRECT_URI` | ⚠️ Prod | Authorised redirect URI |
| `REDIS_URL` | ⚠️ Celery | Redis connection string |
| `FRONTEND_URL` | Optional | Base URL of web frontend |
| `JWT_ACCESS_MINUTES` | Optional | JWT access token TTL (default: 60) |
| `JWT_REFRESH_DAYS` | Optional | JWT refresh token TTL (default: 30) |
| `APP_VERSION` | Optional | Shown in `/health/` response |

> [!WARNING]
> Django will raise `ImproperlyConfigured` and **refuse to start** if `DJANGO_SECRET_KEY` or `DATABASE_URL` are missing. In production, `EMAIL_HOST`, `GROQ_API_KEY`, and `GOOGLE_CLIENT_*` are also required.

---

## Health Endpoint

`GET /health/` — public, no authentication required.

Use this URL for deployment platform health checks:

```
https://your-api-domain.com/health/
```

**Healthy response (HTTP 200):**
```json
{
  "status": "healthy",
  "database": "connected",
  "redis": "connected",
  "email": "configured",
  "google_calendar": "configured",
  "ai": "configured",
  "environment": "ok",
  "disk": "ok (42%)",
  "memory": "ok (61%)",
  "version": "1.0.0"
}
```

**Degraded response (HTTP 503):**
```json
{
  "status": "degraded",
  "database": "error: connection refused",
  ...
}
```

---

## Render (Backend)

1. Connect your GitHub repo → New **Web Service**
2. Set **Build Command**: `pip install -r requirements.txt && python manage.py migrate && python manage.py collectstatic --noinput`
3. Set **Start Command**: `gunicorn server.wsgi:application --bind 0.0.0.0:$PORT`
4. Set environment variables (see table above)
5. Set **Health Check Path**: `/health/`

> [!TIP]
> Render also supports `render.yaml` for infrastructure-as-code deployment. The existing `render.yaml` in this repo already configures the web service.

---

## Railway (Backend)

1. Create a new project → **Deploy from GitHub**
2. Add a **PostgreSQL** plugin → copy the `DATABASE_URL`
3. Add a **Redis** plugin → copy the URL as `REDIS_URL`
4. Set environment variables in the Railway dashboard
5. Railway auto-detects the `Procfile` or uses the start command

---

## Docker (Self-hosted)

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server/ .

ENV DJANGO_SETTINGS_MODULE=server.settings
ENV PORT=8000

RUN python manage.py collectstatic --noinput

CMD ["gunicorn", "server.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

```yaml
# docker-compose.yml
version: '3.8'
services:
  web:
    build: .
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://postgres:password@db:5432/productivity
      REDIS_URL: redis://redis:6379/0
    depends_on:
      - db
      - redis

  db:
    image: postgres:15
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: productivity

  redis:
    image: redis:7-alpine

  celery:
    build: .
    command: celery -A server worker --loglevel=info
    environment:
      DATABASE_URL: postgresql://postgres:password@db:5432/productivity
      REDIS_URL: redis://redis:6379/0
    depends_on:
      - db
      - redis
```

---

## Supabase (PostgreSQL)

1. Create a Supabase project
2. Go to **Settings → Database → Connection String (URI)**
3. Copy the URI and set it as `DATABASE_URL`

```
DATABASE_URL=postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres
```

> [!NOTE]
> Supabase uses connection pooling via PgBouncer on port 6543. For Django, use the **direct connection** on port 5432 (not the pooler) to avoid prepared statement conflicts.

---

## Running Tests

```bash
cd server
pip install -r requirements.txt
DJANGO_TESTING=1 pytest -v
```

With coverage:
```bash
DJANGO_TESTING=1 pytest --cov=. --cov-report=html -v
```

---

## Post-Deployment Checklist

- [ ] `DEBUG=False`
- [ ] `DJANGO_SECRET_KEY` is long (≥40 chars) and random
- [ ] `DATABASE_URL` points to PostgreSQL (not SQLite)
- [ ] `ALLOWED_HOSTS` contains your domain
- [ ] `CORS_ALLOWED_ORIGINS` contains your frontend URL
- [ ] `EMAIL_HOST_USER` and `EMAIL_HOST_PASSWORD` are set
- [ ] `GROQ_API_KEY` is set
- [ ] `REDIS_URL` is set if using Celery
- [ ] `GET /health/` returns HTTP 200
- [ ] Static files are served (`collectstatic` was run)
- [ ] Migrations are applied (`migrate` was run)
