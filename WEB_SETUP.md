# Flutter Web Setup Guide

## تفعيل الدعم للويب

### 1. تفعيل Flutter Web (مرة واحدة)
```bash
flutter config --enable-web
flutter devices  # يجب أن يظهر Chrome أو Web في القائمة
```

### 2. تشغيل على المتصفح
```bash
flutter run -d chrome
# أو
flutter run -d web-server --web-port=8080
```

### 3. بناء نسخة الإنتاج
```bash
flutter build web --release
# الناتج في: build/web/
```

### 4. نشر على Firebase Hosting
```bash
firebase init hosting
# اختر build/web كـ public directory
firebase deploy --only hosting
```

---

## التخطيط المتجاوب — Breakpoints

| الجهاز | العرض | التخطيط |
|--------|-------|---------|
| موبايل | < 768px | Stack كامل + AppBar + Drawer |
| تابلت | 768-1100px | Sidebar مضغوط (72px) + محتوى |
| ديسكتوب | > 1100px | Sidebar كامل (260px) + محتوى |

---

## الملفات الرئيسية للويب

| الملف | الوظيفة |
|-------|---------|
| `web/index.html` | نقطة دخول الويب + شاشة تحميل |
| `lib/layout/breakpoints.dart` | نقاط التكيّف |
| `lib/layout/responsive_scaffold.dart` | هيكل التخطيط المتجاوب |
| `lib/screens/leader/dashboard_screen.dart` | لوحة القائد (موبايل + ويب) |
| `lib/main.dart` | إعداد مشترك + شرط `kIsWeb` |

---

## ملاحظات مهمة
- `flutter_local_notifications` لا تعمل على الويب (محاطة بـ `!kIsWeb`)
- `local_auth` (Biometric) لا تعمل على الويب
- خط Tajawal يُحمَّل من Google Fonts في `web/index.html`
