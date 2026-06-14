# AI Productivity Tracker

A full-stack productivity platform with a React web frontend, Flutter mobile app, and a Django REST Framework backend — featuring Groq-powered AI coaching, JWT authentication, routine tracking, analytics, and optional Google Calendar integration.

## Core Features

- React + Vite frontend with dashboard, routines, analytics, AI assistant, and auth UI.
- Flutter mobile app (Android / iOS / Web) with the same feature set.
- Django REST Framework API with SimpleJWT authentication.
- SQLite by default for development, PostgreSQL-ready for production.
- Routine tracking: study, exercise, ML learning, study hours, sleep/wake time, mobile usage, notes, productivity score, streaks, and XP.
- **Groq-powered** plan generation, chat coaching, and habit analysis (model: `llama-3.3-70b-versatile`).
- Analytics endpoints: weekly trends, habit rates, streaks, score breakdowns, heatmaps, study vs mobile usage, and sleep consistency.
- Optional Google Calendar OAuth, reminder creation, and routine sync endpoints.

## Technology Stack

| Component | Technology |
|---|---|
| Web Frontend | React, Vite, Tailwind CSS, Lucide Icons, Recharts, Framer Motion |
| Mobile | Flutter 3.44+, Riverpod, GoRouter, Dio |
| Backend | Django 4.2, Django REST Framework, SimpleJWT |
| Database | SQLite (dev) / PostgreSQL (prod) |
| AI | Groq — `llama-3.3-70b-versatile` via `groq` SDK |
| Calendar | Google Calendar API (optional) |

## Project Architecture

```text
AI Productivity Tracker/
├── client/                 # React web frontend
│   └── src/
│       ├── components/
│       ├── context/
│       ├── pages/
│       └── services/
├── mobile/                 # Flutter mobile app
│   └── lib/
│       ├── core/
│       └── features/
├── server/                 # Django REST backend
│   ├── common/             # Shared utilities (Groq client)
│   ├── users/
│   ├── routines/
│   ├── analytics_app/
│   ├── ai_assistant/
│   ├── calendar_integration/
│   ├── server/
│   └── manage.py
├── .env.example
└── README.md
```

## Local Setup

### Backend

```bash
cd server
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

### Web Frontend

```bash
npm install --prefix client
npm run dev --prefix client
```

### Flutter Mobile

```bash
cd mobile
flutter pub get
flutter run
```

Frontend: `http://localhost:5173`  
Backend API: `http://127.0.0.1:8000/api`

## Environment Variables

Create `server/.env` (copy from `.env.example`):

```env
DJANGO_SECRET_KEY=your_django_secret_key
DEBUG=True
CORS_ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
JWT_ACCESS_MINUTES=60
JWT_REFRESH_DAYS=30

# Groq AI — get your key at https://console.groq.com/keys
GROQ_API_KEY=your_groq_api_key_here
```

Leave `POSTGRES_DB` empty to use SQLite. Fill the `POSTGRES_*` values for PostgreSQL.

## Production Deployment

This project is configured to be deployed across Render (Backend), Vercel (Frontend), and Supabase (Database).

### 1. Supabase (Database)
- Create a new project on Supabase.
- Go to Project Settings -> Database and copy the **Connection String (URI)**.
- Make sure you replace `[YOUR-PASSWORD]` with your database password.

### 2. Render (Django Backend)
- Connect your GitHub repository to Render and create a new **Blueprint Instance** (or Web Service).
- Render will automatically use the `render.yaml` configuration.
- Add the following Environment Variables in the Render dashboard:
  - `DATABASE_URL`: Your Supabase connection string.
  - `DJANGO_SECRET_KEY`: A secure random string.
  - `DEBUG`: `False`
  - `ALLOWED_HOSTS`: Your Render backend URL (e.g., `ai-productivity-backend.onrender.com`).
  - `CORS_ALLOWED_ORIGINS`: Your Vercel frontend URL (e.g., `https://my-frontend.vercel.app`).
  - `FRONTEND_URL`: Your Vercel frontend URL.

### 3. Vercel (React Frontend)
- Import the `client` directory as a new project in Vercel.
- The framework preset should be automatically detected as **Vite**.
- Add the following Environment Variable:
  - `VITE_API_URL`: Your Render backend URL (e.g., `https://ai-productivity-backend.onrender.com/api`).
- Deploy! Vercel will build the React app and automatically handle SPA routing using the `vercel.json` file.

> **Note on File Uploads**: Render uses ephemeral file systems. Any files (like avatars) uploaded to the local disk will be cleared on the next deploy. If your app relies heavily on file uploads, consider integrating an external object storage like Supabase Storage or AWS S3.

## Main API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/auth/register` | Register a user |
| POST | `/api/auth/login` | Login and receive JWT tokens |
| POST | `/api/auth/token/refresh` | Refresh access token |
| GET | `/api/auth/me` | Fetch current user |
| PUT | `/api/auth/custom-config` | Update tracking configuration |
| POST | `/api/auth/send-otp` | Send OTP for email verification |
| POST | `/api/auth/verify-otp` | Verify OTP |
| POST | `/api/auth/complete-registration` | Complete OTP registration |
| POST | `/api/auth/forgot-password` | Send password reset email |
| GET/POST | `/api/routines` | List or create routine logs |
| PUT/DELETE | `/api/routines/:id` | Update or delete a routine log |
| GET | `/api/analytics/weekly` | Weekly chart data |
| GET | `/api/analytics/full` | Full analytics and behavioral data |
| POST | `/api/ai/generate-plan` | AI routine planner (Groq) |
| POST | `/api/ai/analyze` | AI habit analysis (Groq) |
| POST | `/api/ai/chat` | AI productivity mentor chat (Groq) |
| GET | `/api/calendar/auth-url` | Google OAuth URL |
| POST | `/api/calendar/callback` | Save Google OAuth tokens |
| POST | `/api/calendar/sync` | Sync routine reminders |
| POST | `/api/calendar/ai-schedule` | AI-powered schedule generation (Groq) |
| GET/POST | `/api/calendar/insights` | AI productivity insights (Groq) |
