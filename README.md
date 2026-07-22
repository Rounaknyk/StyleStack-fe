# StyleStack Flutter

## Photo adjustment and beginner guide

Wardrobe photos can be cropped and rotated on-device before upload. This uses
the pure-Flutter `crop_image` editor and does not consume backend or AI calls.

The **StyleStack guide** is available from the help icon on Today and from
Profile > Help & guide. It has built-in illustrated fallbacks. To use real app
screenshots, add the four optional images documented in
`assets/images/help/README.md`; the UI adopts them automatically after rebuild.

After onboarding, a four-slide Quick Tour is shown once per signed-in account
on that device. Completion is stored locally using the Firebase UID, so changing
accounts does not incorrectly skip the tour. Profile > Help & guide > **Test
quick tour** replays the same screen without resetting its completion state.

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
- AdMob rewards after two free daily outfit refreshes and before the first
  Google Calendar connection

## AdMob rewarded ads

The app currently uses Google's official sample App IDs and rewarded ad-unit
IDs. These are safe for development and always show test inventory; they do not
earn revenue. Before the next store release:

1. Create Android and iOS apps in AdMob.
2. Create two rewarded units per platform: `daily_outfit` and
   `calendar_connection`.
3. Replace the sample App ID in `android/app/src/main/AndroidManifest.xml` and
   `ios/Runner/Info.plist`.
4. Provide the rewarded unit IDs when building:

```bash
flutter build appbundle \
  --dart-define=ADMOB_REWARDED_DAILY_ANDROID=ca-app-pub-.../... \
  --dart-define=ADMOB_REWARDED_CALENDAR_ANDROID=ca-app-pub-.../...
```

Use the corresponding `ADMOB_REWARDED_DAILY_IOS` and
`ADMOB_REWARDED_CALENDAR_IOS` values for iOS. A completed reward is required
before the first Calendar connection. Backend-managed testers bypass both
placements. Deliberately dismissing an available Calendar
ad keeps it disconnected; SDK, configuration, network, load, and show failures
fail open so an advertising outage does not block the user. On Today, the
initial outfit and two successful refreshes are free; each later refresh
requires an earned reward unless the user has a bypass.

Because this integration adds a native plugin and native App IDs, it requires a
new Play Store/App Store binary and cannot be introduced to an existing release
using only a Shorebird patch.

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

## Shorebird over-the-air updates

StyleStack is registered with Shorebird so Dart-only fixes can be delivered
without waiting for another Play Store review. The first store build for a
version must always be created with Shorebird:

```bash
shorebird release android \
  --dart-define=API_BASE_URL=https://stylestack-be.onrender.com/api/v1
```

Upload the generated
`build/app/outputs/bundle/release/app-release.aab` to Google Play. Only users
who install a Shorebird-built release can receive its patches; older standard
Flutter builds cannot be patched retroactively.

After changing Dart code, publish a patch for the latest Android release with:

```bash
shorebird patch android \
  --release-version=latest \
  --dart-define=API_BASE_URL=https://stylestack-be.onrender.com/api/v1
```

Use the same `--dart-define` values for the release and every patch. Shorebird
downloads a stable patch in the background and applies it on a later app
launch.

Create a new Play Store release instead of a patch when a change includes:

- native Android/iOS code or configuration
- a new or updated Flutter plugin
- assets, fonts, icons, or animations
- a Flutter/engine version change

Before publishing, run the normal analysis/tests and use `--dry-run` when a
patch needs validation without uploading:

```bash
shorebird patch android \
  --release-version=latest \
  --dry-run \
  --dart-define=API_BASE_URL=https://stylestack-be.onrender.com/api/v1
```
