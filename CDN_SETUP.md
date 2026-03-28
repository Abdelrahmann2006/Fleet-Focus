# CDN Setup Guide — JSDelivr + GitHub

## الهدف
استضافة الأصول الثابتة (صور، أصوات) على GitHub مجاناً وتوزيعها عبر JSDelivr CDN
لتجنب تكاليف Firebase Storage bandwidth.

## الخطوات

### 1. أنشئ مستودعاً عاماً على GitHub
```
اسم المستودع المقترح: competition-assets
الرؤية: Public (ضروري لـ JSDelivr)
```

### 2. بنية المجلدات المطلوبة
```
competition-assets/
└── assets/
    ├── images/
    │   ├── logo.png
    │   ├── splash_bg.png
    │   ├── leader_icon.png
    │   └── participant_icon.png
    └── audio/
        ├── buzzer.mp3
        ├── success.mp3
        ├── alert.mp3
        ├── countdown_beep.mp3
        └── elimination.mp3
```

### 3. ارفع الملفات
```bash
git clone https://github.com/Abdelrahmann2006/competition-assets.git
# ضع الملفات في المجلدات المناسبة
git add .
git commit -m "Add competition assets"
git push origin main
```

### 4. حدّث cdn_service.dart
```dart
// في lib/services/cdn_service.dart — سطر 16-17
static const String _githubUsername = 'YOUR_ACTUAL_USERNAME';  // ← غيّر هذا
static const String _githubRepo     = 'competition-assets';    // ← أو اسم مستودعك
```

### 5. اختبر الرابط
```
https://cdn.jsdelivr.net/gh/Abdelrahmann2006/competition-assets@main/assets/images/logo.png
```

## روابط CDN الناتجة
```
صورة:  https://cdn.jsdelivr.net/gh/{user}/{repo}@main/assets/images/{file}
صوت:   https://cdn.jsdelivr.net/gh/{user}/{repo}@main/assets/audio/{file}
```

## ملاحظات
- JSDelivr يكيّش الملفات لمدة 7 أيام تلقائياً
- لتحديث ملف: استخدم tag بدلاً من main → `@v1.1`
- الحد الأقصى لحجم الملف: 50MB لكل ملف
- لا يوجد حد للنطاق الترددي (مجاني تماماً)
