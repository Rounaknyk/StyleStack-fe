# StyleStack Flutter

Flutter client for the StyleStack FastAPI backend with Firebase email/password authentication, camera uploads, and a wardrobe grid.

## Firebase

The project is configured for Firebase project `stylestack-9032f` and application ID `com.stylestack.stylestack` using:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Enable **Email/Password** in Firebase Console under **Authentication > Sign-in method** before running the app.

## Run locally

Start the FastAPI backend first. Then run Flutter from this directory:

```bash
flutter pub get
flutter run
```

Without configuration, Android emulators use `http://10.0.2.2:8000/api/v1` and iOS simulators use `http://127.0.0.1:8000/api/v1`.

For a physical device or deployed backend, supply its reachable base URL:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.onrender.com/api/v1
```

Do not use `localhost` from a physical phone. Use the computer's LAN IP for local testing and ensure the backend allows the device to reach it.

## Features

- Firebase email/password sign-up, login, persistent session, and logout
- Wardrobe, Outfits, and Profile bottom navigation
- Authenticated wardrobe loading with pull-to-refresh
- Camera capture, preview, retake, metadata, upload loading, and refresh
- Empty, loading, and error states
- Private Supabase images rendered through backend-generated signed URLs

## Validation

```bash
flutter analyze
flutter test
```
