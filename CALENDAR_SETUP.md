# Google Calendar + AI Scheduling Ecosystem Setup Guide

To enable Google Calendar sync and OAuth authentication in Productivity Tracker, follow these steps to configure your Google Cloud Console project.

## 1. Create a Google Cloud Project
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Click the project dropdown and select **New Project**.
3. Name it "Productivity Tracker Calendar" and click **Create**.

## 2. Enable APIs
1. Navigate to **APIs & Services** > **Library**.
2. Search for and enable the following:
   - **Google Calendar API**
   - **Google People API** (or Google+ API for user info scopes)
   - **Google Docs API** (optional, if extending later)

## 3. Configure OAuth Consent Screen
1. Go to **APIs & Services** > **OAuth consent screen**.
2. Choose **External** (if making it public) or **Internal** (if in a Google Workspace) and click **Create**.
3. Fill in the App information:
   - App name: Productivity Tracker
   - User support email: your email
   - Developer contact info: your email
4. Add Scopes:
   - `.../auth/calendar.events`
   - `.../auth/calendar.readonly`
   - `.../auth/userinfo.email`
5. Save and continue. Add test users if in "Testing" mode.

## 4. Create Credentials
1. Go to **APIs & Services** > **Credentials**.
2. Click **Create Credentials** > **OAuth client ID**.
3. Select **Web application**.
4. Set the name to "Productivity Tracker Web Client".
5. Add Authorized Redirect URIs:
   - For local dev: `http://127.0.0.1:8000/api/calendar/callback`
   - For production: `https://your-backend.com/api/calendar/callback`
6. Click **Create**.
7. Copy your **Client ID** and **Client Secret**.

## 5. Update Environment Variables
Add the following to your `server/.env` file:
```env
GOOGLE_CLIENT_ID=your_client_id_here
GOOGLE_CLIENT_SECRET=your_client_secret_here
GOOGLE_REDIRECT_URI=http://127.0.0.1:8000/api/calendar/callback
```

## 6. Restart Server
Restart your Django server to pick up the new `.env` variables.

---

## Production Deployment Notes (Vercel/Render)
- Ensure you update the `GOOGLE_REDIRECT_URI` in both your production `.env` and the Google Cloud Console.
- Ensure `CORS_ALLOWED_ORIGINS` includes your Vercel URL.
- The webhook URL for real-time Google Calendar pushes must be an HTTPS URL. In local dev, the app falls back to polling via React Query / Axios.
