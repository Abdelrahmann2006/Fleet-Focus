# قائمة إعداد Firebase — نظام المنافسة

## الخطوة 1: إنشاء مشروع Firebase

1. افتح [console.firebase.google.com](https://console.firebase.google.com)
2. اضغط **"Add project"** وسمِّه مثلاً `competition-system`
3. فعّل **Google Analytics** (اختياري لكن مُوصى به)

---

## الخطوة 2: إضافة تطبيق Android

1. في Firebase Console → **Project Settings** → **Add app** → اختر Android
2. أدخل **Package name** بالضبط: `com.competition.app`
3. اضغط **Register app**
4. **حمّل ملف `google-services.json`**
5. **ضعه في المسار الصحيح:**
   ```
   flutter_competition_app/android/app/google-services.json
   ```
   > ⚠️ المسار يجب أن يكون `android/app/` وليس `android/`

---

## الخطوة 3: التحقق من build.gradle

### `android/build.gradle` (المستوى الأعلى)
تأكد من وجود:
```groovy
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

### `android/app/build.gradle` (مستوى التطبيق)
تأكد من وجود السطر **في نهاية الملف**:
```groovy
apply plugin: 'com.google.gms.google-services'
```
وتأكد من وجود dependencies:
```groovy
dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-firestore-ktx'
    implementation 'com.google.firebase:firebase-auth-ktx'
    // الموجودة بالفعل عبر flutter pub
}
```
> ملاحظة: إذا كنت تستخدم `cloud_firestore` و`firebase_auth` عبر Flutter pub فهي تُضيف هذه التبعيات تلقائياً. فقط `google-services` plugin هو المطلوب يدوياً.

---

## الخطوة 4: Firestore Database

1. Firebase Console → **Firestore Database** → **Create database**
2. اختر **Production mode** (لأن لدينا Security Rules)
3. اختر أقرب Region (مثل `europe-west3` أو `asia-south1`)

---

## الخطوة 5: نشر قواعد الأمان

ملف `firestore.rules` موجود في مجلد `flutter_competition_app/`.

**الطريقة 1 (عبر Firebase CLI):**
```bash
cd flutter_competition_app
firebase deploy --only firestore:rules
```

**الطريقة 2 (عبر Firebase Console):**
1. Firestore → **Rules** tab
2. انسخ محتوى `firestore.rules` والصقه
3. اضغط **Publish**

---

## الخطوة 6: إعداد هيكل Firestore

أنشئ المجموعات التالية يدوياً أو ستُنشأ تلقائياً عند أول استخدام:

```
users/{uid}
  role: "leader" | "participant"
  email: "..."
  deviceSetupComplete: false

device_states/{uid}
  kioskMode: false
  blockedApps: []
  permissions: { deviceAdmin, accessibility, overlay, batteryOptimization }
  lastSeen: Timestamp

device_commands/{uid}
  command: ""
  payload: {}
  timestamp: Timestamp
  acknowledged: true
```

**مستند القائد (يدوياً):**
```
users/{leader-uid}
  role: "leader"
```

---

## الخطوة 7: Authentication

1. Firebase Console → **Authentication** → **Get started**
2. فعّل **Email/Password**
3. أنشئ حساب القائد يدوياً:
   - Authentication → Add user → أدخل بريد وكلمة مرور
   - انسخ uid المولّد
   - Firestore → users/{uid} → أضف `role: "leader"`

---

## ملاحظات مهمة

| الملف | المسار الصحيح |
|-------|--------------|
| `google-services.json` | `flutter_competition_app/android/app/` |
| `firestore.rules` | `flutter_competition_app/` |
| `firebase.json` (CLI) | `flutter_competition_app/` |

> بعد وضع `google-services.json` ابنِ التطبيق بـ:
> ```bash
> cd flutter_competition_app && flutter build apk
> ```
