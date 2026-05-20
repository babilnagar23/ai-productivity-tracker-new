# AI Productivity Tracker

A React productivity dashboard with a Django REST Framework backend, JWT authentication, SQLite/PostgreSQL-ready persistence, Gemini AI coaching, analytics APIs, and optional Google Calendar integration.

## Core Features

- React + Vite frontend with the existing dashboard, routines, analytics, customization, AI assistant, auth UI, animations, and charts.
- Django REST Framework API with SimpleJWT authentication.
- SQLite by default for development, PostgreSQL via environment variables for production.
- Routine tracking for study, exercise, ML learning, study hours, sleep/wake time, mobile usage, notes, productivity score, streaks, and XP.
- Gemini-powered plan generation, chat coaching, and habit analysis.
- Analytics endpoints for weekly trends, habit rates, streaks, score breakdowns, heatmaps, study vs mobile usage, and sleep consistency.
- Optional Google Calendar OAuth, reminder creation, and routine sync endpoints.
- Light/dark theme toggle in the top navbar.

## Technology Stack

| Component | Technology |
|---|---|
| Frontend | React, Vite, Tailwind CSS, Lucide Icons, Recharts, Framer Motion |
| Backend | Django, Django REST Framework, SimpleJWT |
| Database | SQLite for local development, PostgreSQL-ready |
| AI | Google Gemini through `google-generativeai` |
| Calendar | Google Calendar API |

## Project Architecture

```text
AI Productivity Tracker/
├── client/                 # React frontend
│   └── src/
│       ├── components/
│       ├── context/
│       ├── pages/
│       └── services/
├── server/                 # Django REST backend
│   ├── users/
│   ├── routines/
│   ├── analytics_app/
│   ├── ai_assistant/
│   ├── calendar_integration/
│   ├── productivity_ai/
│   ├── server/
│   └── manage.py
├── .env.example
├── package.json
└── README.md
```

## Local Setup

```bash
npm install
npm install --prefix client
server\venv\Scripts\python.exe -m pip install -r server\requirements.txt
server\venv\Scripts\python.exe server\manage.py migrate
npm run dev
```

Frontend: `http://localhost:5173`

Backend API: `http://127.0.0.1:8000/api`

## Environment

Create `.env` in the root or `server/` folder. Start from `.env.example`.

```env
PORT=8000
DJANGO_SECRET_KEY=your_django_secret_key
DEBUG=True
CORS_ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
JWT_ACCESS_MINUTES=60
JWT_REFRESH_DAYS=30
GEMINI_API_KEY=your_google_gemini_api_key_here
```

Leave `POSTGRES_DB` empty to use SQLite. Fill the `POSTGRES_*` values to use PostgreSQL.

## Main API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/auth/register` | Register a user |
| POST | `/api/auth/login` | Login and receive JWT tokens |
| POST | `/api/auth/token/refresh` | Refresh access token |
| GET | `/api/auth/me` | Fetch current user |
| PUT | `/api/auth/custom-config` | Update tracking configuration |
| GET/POST | `/api/routines` | List or create routine logs |
| PUT/DELETE | `/api/routines/:id` | Update or delete a routine log |
| GET | `/api/analytics/weekly` | Weekly chart data |
| GET | `/api/analytics/full` | Full analytics and behavioral data |
| POST | `/api/ai/generate-plan` | Gemini routine planner |
| POST | `/api/ai/analyze` | Gemini habit analysis |
| POST | `/api/ai/chat` | AI productivity mentor chat |
| GET | `/api/calendar/auth-url` | Google OAuth URL |
| POST | `/api/calendar/callback` | Save Google OAuth tokens |
| POST | `/api/calendar/sync` | Sync routine reminders |
