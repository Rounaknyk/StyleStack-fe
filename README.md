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
- Weather-aware AI outfit suggestions with occasion controls
- Recently-worn exclusion and one-tap wear-history logging
- City, timezone, and morning notification preferences
- Firebase Cloud Messaging device registration
- Multi-photo, multi-garment AI detection with swipe-to-review selection
- Editable AI category, color, season, formality, description, and tag chips
- Permission-based automatic city detection
- Closet Sync ecommerce import from supported Gmail order messages

## Closet Sync development setup

1. Enable the Gmail API in the Google Cloud project used by StyleStack.
2. Configure the OAuth consent screen and add your Gmail account as a test user.
3. Add iOS and Android OAuth client IDs for the app bundle/package IDs.
4. Download refreshed Firebase configuration files after enabling Google
   Sign-In. The iOS file must include `CLIENT_ID` and `REVERSED_CLIENT_ID`; add
   the reversed client ID as a Runner URL scheme in Xcode.

Closet Sync requests Gmail read-only access only after a clear consent dialog.
Its access token and email contents are not stored by StyleStack. Gmail
read-only is a restricted Google scope, so public production use requires
Google OAuth verification and may require a security assessment. Keep it to
configured OAuth test users until that review is complete.

## V1 services

The backend must have the updated `supabase/schema.sql` applied and these environment variables configured:

```env
OPENWEATHER_API_KEY=your-openweather-api-key
GROQ_API_KEY=your-groq-api-key
```

The Outfits tab uses the saved city or a city entered on screen. The Profile tab controls the morning notification schedule. Push notifications require a physical device; for iOS, upload an APNs authentication key under Firebase Console **Project Settings > Cloud Messaging** and enable Push Notifications for the signed Runner target.

## Validation

```bash
flutter analyze
flutter test
```
