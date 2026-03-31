# Competition Management App (Panopticon)

## Overview
A Flutter web application for competition management with Leader and Participant roles. The app is built in Arabic (RTL layout) with a dark gold-themed design.

## Tech Stack
- **Framework**: Flutter 3.32.0 (web target)
- **Backend Services**: Firebase (Auth, Firestore, Realtime Database, Storage)
- **Server**: Python 3.11 HTTP server
- **Build Output**: `build/web/`

## Project Structure
```
/
├── lib/                    # Flutter Dart source code
│   ├── main.dart           # App entry point
│   ├── app_router.dart     # GoRouter navigation
│   ├── firebase_options.dart  # Firebase configuration (web + android + iOS)
│   ├── constants/          # App colors and constants
│   ├── providers/          # State management (Provider)
│   ├── screens/            # UI screens
│   ├── services/           # Business logic services
│   ├── widgets/            # Reusable UI components
│   ├── models/             # Data models
│   ├── repositories/       # Data repositories
│   └── utils/              # Utilities
├── web/                    # Flutter web template (index.html)
├── android/                # Android native code
├── build/web/              # Built Flutter web output (served by Python)
├── serve.py                # Python HTTP server (port 5000)
└── pubspec.yaml            # Flutter dependencies
```

## Running the App

### Development
The workflow runs `python3 serve.py` which serves the pre-built Flutter web app on port 5000.

To rebuild after code changes:
```bash
flutter build web
```

### Build System
- Flutter SDK 3.32.0
- Build command: `flutter build web`
- Serve command: `python3 serve.py`
- Port: 5000

## Firebase Configuration
- Project: `panopticon-afbec`
- Firebase Auth (Email/Password, Google Sign-In)
- Firestore Database
- Realtime Database
- Firebase Storage

The `firebase_options.dart` includes web platform support. The actual Firebase web app credentials (appId) should be updated with the correct web app ID from the Firebase Console for full authentication functionality.

## Key Dependencies
- firebase_core, firebase_auth, cloud_firestore, firebase_database, firebase_storage
- go_router (navigation)
- provider (state management)
- mqtt_client (MQTT messaging)
- flutter_animate (animations)
- hive/hive_flutter (local storage - mobile only)

## Notes
- Hive local storage is disabled on web (mobile only)
- flutter_local_notifications is disabled on web
- local_auth (biometric) is not available on web
- `setPersistenceEnabled()` throws on web - handled with try/catch
