# دليل إعداد مشروع Flutter - نظام المنافسة

## 1. المتطلبات الأساسية
- Flutter SDK 3.24+ (https://docs.flutter.dev/get-started/install)
- Android Studio + NDK
- JDK 17+

---

## 2. إعداد Firebase (خطوات حرجة)

### أ) أضف ملف google-services.json
- افتح Firebase Console → مشروع panopticon-afbec
- الإعدادات ← تطبيق Android ← نزّل `google-services.json`
- انسخه إلى: `android/app/google-services.json`

### ب) شغّل FlutterFire CLI لتوليد firebase_options.dart
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=panopticon-afbec
```
سيستبدل `lib/firebase_options.dart` تلقائياً بالقيم الصحيحة.

---

## 3. تثبيت الحزم
```bash
flutter pub get
```

---

## 4. إضافة خط Tajawal
في `pubspec.yaml` أضف تحت `dependencies`:
```yaml
google_fonts: ^6.2.1
```
أو نزّل الخط يدوياً من Google Fonts:
- انشئ مجلد `assets/fonts/`
- نزّل Tajawal-Regular.ttf, Tajawal-Bold.ttf
- أضف في pubspec.yaml:
```yaml
fonts:
  - family: Tajawal
    fonts:
      - asset: assets/fonts/Tajawal-Regular.ttf
      - asset: assets/fonts/Tajawal-Bold.ttf
        weight: 700
```

---

## 5. إعداد تسجيل الدخول بـ Google

### في Firebase Console:
- Authentication → Sign-in providers → Google → Enable
- أضف SHA-1 و SHA-256 من مشروع Android Studio:
```bash
cd android && ./gradlew signingReport
```

### في google-services.json:
تأكد من وجود `client_type: 3` مع `client_id` لـ Android.

---

## 6. بناء وتشغيل المشروع
```bash
# Debug
flutter run

# Release APK
flutter build apk --release

# Release AAB (Google Play)
flutter build appbundle --release
```

---

## 7. هيكل الملفات الكامل

```
flutter_competition_app/
├── lib/
│   ├── main.dart                          ← نقطة الدخول + Notifications init
│   ├── app_router.dart                    ← GoRouter navigation
│   ├── firebase_options.dart              ← يولّده FlutterFire CLI
│   ├── constants/
│   │   └── colors.dart                   ← ألوان التصميم
│   ├── providers/
│   │   └── auth_provider.dart            ← Firebase Auth + Firestore
│   ├── services/
│   │   └── permission_service.dart       ← MethodChannel → Kotlin
│   ├── widgets/
│   │   ├── stage_light_background.dart   ← أنيميشن الأضواء
│   │   ├── gold_button.dart
│   │   └── gold_input.dart
│   └── screens/
│       ├── splash_screen.dart
│       ├── auth/
│       │   ├── leader_login_screen.dart
│       │   └── participant_login_screen.dart
│       ├── leader/
│       │   ├── dashboard_screen.dart
│       │   ├── participants_screen.dart
│       │   └── participant_detail_screen.dart
│       ├── participant/
│       │   ├── home_screen.dart
│       │   ├── device_setup_screen.dart   ← 7 خطوات + MethodChannel
│       │   └── application_screen.dart
│       └── form/
│           ├── section1_basic_info.dart
│           ├── section2_health_profile.dart
│           ├── section3_psych_profile.dart
│           ├── section4_skills.dart
│           ├── section5_socioeconomic.dart
│           ├── section6_behavioral.dart
│           ├── section7_consent.dart
│           ├── section8_red_lines.dart
│           ├── section9_advanced_psych.dart
│           └── section10_verification.dart
└── android/app/src/main/
    ├── AndroidManifest.xml
    ├── res/xml/
    │   ├── accessibility_service_config.xml
    │   ├── device_admin_policies.xml
    │   └── file_paths.xml
    └── kotlin/com/competition/app/
        ├── MainActivity.kt               ← يهيّئ PermissionMethodChannel
        ├── PermissionMethodChannel.kt    ← كل منطق الصلاحيات النيتف
        ├── MyAccessibilityService.kt     ← Foreground Sticky Notification
        └── MyDeviceAdminReceiver.kt      ← Device Admin policies

```

---

## 8. MethodChannel — كيف يعمل

```
Flutter (Dart)                    ↔        Android (Kotlin)
─────────────────                          ────────────────────────
PermissionService.isDeviceAdminActive() → PermissionMethodChannel.kt
                                           → DevicePolicyManager.isAdminActive()
                                           ← returns true/false

PermissionService.openDeviceAdminSettings() → DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN
```

القناة: `com.competition.app/permissions`

---

## 9. Firestore Collections

```
users/{uid}
  role: "leader" | "participant"
  leaderCode: "L-XXXXXXX"        (leader only)
  linkedLeaderCode: "L-XXXXXXX"  (participant only)
  applicationStatus: "pending" | "submitted" | "approved"
  deviceSetupComplete: bool

leader_codes/{code}
  leaderUid: string
  leaderName: string
  active: bool

participants/{uid}
  basic_info: {...}
  health_profile: {...}
  psych_profile: {...}
  skills: {...}
  socioeconomic: {...}
  behavioral: {...}
  consent: {...}
  red_lines: {...}
  advanced_psych: {...}
  verification: {...}
  submittedAt: Timestamp
```
