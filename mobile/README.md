# ProductiveAI — Flutter Mobile App

A Flutter mobile app that connects to your existing Django backend.

---

## FOLDER STRUCTURE

```
mobile/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart        ← Dio + JWT interceptor
│   │   │   └── api_endpoints.dart     ← All backend URLs
│   │   ├── routes/
│   │   │   └── app_router.dart        ← GoRouter with auth redirect
│   │   ├── shell/
│   │   │   └── main_shell.dart        ← Bottom navigation bar
│   │   ├── storage/
│   │   │   └── secure_storage.dart    ← JWT token storage
│   │   └── theme/
│   │       └── app_theme.dart         ← Dark cyber theme
│   ├── features/
│   │   ├── auth/                      ← Login, Register, OTP, Password
│   │   ├── dashboard/                 ← Home screen with stats
│   │   ├── routines/                  ← Log + edit daily routines
│   │   ├── ai_assistant/              ← AI chat (Groq)
│   │   ├── analytics/                 ← Charts + habit rates
│   │   ├── calendar/                  ← Calendar heatmap view
│   │   └── profile/                   ← User settings + logout
│   └── shared/
│       └── widgets/
│           └── gradient_card.dart
├── android/                           ← Android config (ready to build)
├── pubspec.yaml                       ← All dependencies
└── README.md
```

---

## STEP 1 — INSTALL FLUTTER

If you don't have Flutter installed:

1. Download: https://docs.flutter.dev/get-started/install
2. Add Flutter to PATH
3. Run: `flutter doctor`

Fix any issues shown by `flutter doctor` before continuing.

---

## STEP 2 — ADD THIS FOLDER TO YOUR PROJECT

Place the `mobile/` folder at the root of your project:

```
ai-productivity-tracker-new/
├── client/         ← React frontend (existing)
├── server/         ← Django backend (existing)
├── mobile/         ← Flutter app (NEW — paste here)
└── README.md
```

---

## STEP 3 — INSTALL DEPENDENCIES

```bash
cd mobile
flutter pub get
```

---

## STEP 4 — SET YOUR BACKEND URL

Open `lib/core/api/api_client.dart` and change `kBaseUrl`:

```dart
// Android Emulator (uses 10.0.2.2 instead of localhost)
const String kBaseUrl = 'http://10.0.2.2:8000/api';

// Physical Android device (use your PC's local IP)
const String kBaseUrl = 'http://192.168.1.5:8000/api';

// iOS Simulator
const String kBaseUrl = 'http://127.0.0.1:8000/api';

// Production (deployed)
const String kBaseUrl = 'https://your-domain.com/api';
```

---

## STEP 5 — START YOUR DJANGO BACKEND

In a separate terminal, from your project root:

```bash
cd server
venv\Scripts\activate        # Windows
source venv/bin/activate     # Mac/Linux

python manage.py runserver 0.0.0.0:8000
```

The `0.0.0.0` makes Django accessible from your phone/emulator.

---

## STEP 6 — RUN THE APP

```bash
# List available devices
flutter devices

# Run on Android emulator
flutter run

# Run on specific device
flutter run -d <device_id>

# Run in release mode (faster)
flutter run --release
```

---

## STEP 7 — BUILD APK (for sharing/testing)

```bash
flutter build apk --release
```

APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

---

## SCREENS & FEATURES

| Screen | Description |
|---|---|
| Login | Email + password login with JWT |
| Register | 3-step: Email → OTP → Password |
| Dashboard | Streak, XP, today's score, quick actions |
| Routine Tracker | List all logs with edit/delete |
| Add/Edit Routine | Form with habits, hours, sleep, notes |
| AI Chat | Full chat UI connected to Groq backend |
| Analytics | Bar chart, line chart, habit completion rates |
| Calendar | Calendar heatmap with colour-coded scores |
| Profile | User info + logout |

---

## API URLS USED

All connect to your existing Django backend:

```
POST /api/auth/login
POST /api/auth/send-otp
POST /api/auth/verify-otp
POST /api/auth/complete-registration
GET  /api/auth/me
POST /api/auth/forgot-password
GET  /api/routines
POST /api/routines
PUT  /api/routines/:id
DELETE /api/routines/:id
GET  /api/analytics/full
GET  /api/analytics/weekly
POST /api/ai/chat
```

---

## TROUBLESHOOTING

### "Connection refused" error
- Make sure Django is running: `python manage.py runserver 0.0.0.0:8000`
- On Android emulator, use `10.0.2.2` not `localhost`
- On physical device, use your PC's IP (run `ipconfig` on Windows, `ifconfig` on Mac)

### "cleartext HTTP not permitted"
- Already handled in `android/app/src/main/res/xml/network_security_config.xml`
- For production, switch to HTTPS

### "flutter pub get" fails
- Run `flutter doctor` and fix all issues first
- Make sure you're inside the `mobile/` folder

### JWT token expired
- The app auto-refreshes tokens via the `_AuthInterceptor` in `api_client.dart`
- If refresh fails, user is logged out and redirected to login

---

## DEPENDENCIES USED

| Package | Purpose |
|---|---|
| `dio` | HTTP client with interceptors |
| `flutter_riverpod` | State management |
| `go_router` | Navigation + deep linking |
| `flutter_secure_storage` | JWT token storage |
| `fl_chart` | Bar & line charts |
| `table_calendar` | Calendar widget |
| `google_fonts` | Space Grotesk font |
| `intl` | Date formatting |

---

## PRODUCTION CHECKLIST

- [ ] Change `kBaseUrl` to your deployed Django URL (HTTPS)
- [ ] Set `android:usesCleartextTraffic="false"` in AndroidManifest.xml
- [ ] Generate a keystore for signing: `keytool -genkey -v -keystore upload-keystore.jks`
- [ ] Create `android/key.properties` with keystore details
- [ ] Update `android/app/build.gradle` to use the keystore
- [ ] Run `flutter build appbundle` for Play Store upload

---

## PROJECT STRUCTURE AFTER ADDING MOBILE

```
ai-productivity-tracker-new/
├── client/             React + Vite frontend
├── server/             Django REST Framework backend  
├── mobile/             Flutter mobile app  ← NEW
├── .env.example
└── README.md
```
