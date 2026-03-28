# دليل إعداد التكاملات الخارجية المجانية

## نظرة عامة على التوجيه التلقائي

| نوع الملف | المستودع الأساسي | النسخة الاحتياطية |
|-----------|-----------------|------------------|
| صور (Snap Check-in, دليل مهمة) | Telegram Bot | IPFS/Pinata |
| فيديو قصير ≤ 50MB (تسجيل شاشة) | Telegram Bot | — |
| فيديو طويل (تحقق، التزام) | YouTube (Unlisted) | — |
| صوت | Telegram Bot | IPFS/Pinata |
| JSON / سجلات نشاط | IPFS/Pinata | Google Sheets |
| بيانات استشعار تاريخية | Google Sheets | — |

جميع المراجع (file_id, videoId, CID) تُحفظ في Firestore فقط — لا رفع مباشر لـ Firebase Storage.

---

## 1. Telegram Bot API

### إعداد البوت:
1. افتح [@BotFather](https://t.me/BotFather) في Telegram
2. أرسل `/newbot` واتبع التعليمات
3. احفظ الـ **Bot Token** (مثال: `7123456789:AAF...`)
4. أنشئ قناة خاصة (`Private Channel`)
5. أضف البوت كـ **مشرف** بصلاحية نشر الرسائل
6. احصل على **Channel ID**: أرسل أي رسالة للقناة، ثم افتح:
   `https://api.telegram.org/bot<TOKEN>/getUpdates`
   وابحث عن `chat.id` (يبدأ بـ `-100`)

### كود Flutter:
```dart
ExternalStorageService().configure(
  telegramToken:   '7123456789:AAF....',
  telegramChannel: '-1001234567890',
  ...
);
```

### حدود Telegram Bot API:
- حجم الملف الأقصى: **50 MB** لكل ملف
- لا يوجد حد للتخزين الكلي
- مجاني تماماً

---

## 2. Google Apps Script + Sheets

### إنشاء Apps Script:
1. افتح [script.google.com](https://script.google.com) بحساب Google
2. أنشئ مشروعاً جديداً واحذف الكود الافتراضي
3. الصق الكود التالي:

```javascript
const SPREADSHEET_ID = 'YOUR_SPREADSHEET_ID_HERE';

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const sheetName = data.sheet || 'Telemetry';
    const ss = SpreadsheetApp.openById(data.spreadsheetId || SPREADSHEET_ID);
    let sheet = ss.getSheetByName(sheetName);
    if (!sheet) sheet = ss.insertSheet(sheetName);

    if (Array.isArray(data.rows)) {
      data.rows.forEach(row => sheet.appendRow(row));
    } else if (data.row) {
      sheet.appendRow(data.row);
    }

    return ContentService.createTextOutput(
      JSON.stringify({ success: true, rowsAppended: data.rows?.length || 1 })
    ).setMimeType(ContentService.MimeType.JSON);

  } catch(err) {
    return ContentService.createTextOutput(
      JSON.stringify({ success: false, error: err.message })
    ).setMimeType(ContentService.MimeType.JSON);
  }
}
```

4. احفظ المشروع
5. **Deploy** → **New Deployment** → نوع: **Web App**
   - Execute as: **Me**
   - Who has access: **Anyone**
6. انسخ **Web App URL** (يبدأ بـ `https://script.google.com/macros/s/...`)
7. افتح [Google Sheets](https://sheets.google.com) وانشئ جدولاً جديداً
8. انسخ **Spreadsheet ID** من الرابط:
   `https://docs.google.com/spreadsheets/d/`**`1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms`**`/edit`

### كود Flutter:
```dart
ExternalStorageService().configure(
  ...
  sheetsWebAppUrl: 'https://script.google.com/macros/s/AKfycb.../exec',
  sheetsId:        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms',
  ...
);
```

### الـ Sheets المُنشأة تلقائياً:
| اسم الشيت | المحتوى |
|-----------|---------|
| `Telemetry` | بطارية، GPS، شاشة، مهمة |
| `Events` | الأحداث (انضمام، خروج، قبول...) |
| `Commands` | أوامر القائد |
| `Sessions` | جلسات تسجيل الدخول |

---

## 3. YouTube Data API v3

### إعداد Google Cloud + OAuth:
1. افتح [Google Cloud Console](https://console.cloud.google.com)
2. أنشئ مشروعاً أو استخدم مشروعاً موجوداً
3. **APIs & Services** → **Enable APIs** → ابحث عن `YouTube Data API v3` → فعّله
4. **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
   - Application type: **Android** (أدخل package name: `com.abdelrahman.panopticon`)
5. للحصول على access token مبدئياً، استخدم [OAuth Playground](https://developers.google.com/oauthplayground):
   - Scope: `https://www.googleapis.com/auth/youtube.upload`
   - احصل على Access Token وRefresh Token
6. **تجديد Token تلقائياً**: استدعِ `setAccessToken()` قبل كل رفع

### كود Flutter:
```dart
// تجديد الـ token قبل الرفع
ExternalStorageService().youtube.setAccessToken(freshToken);

// رفع فيديو تحقق
await ExternalStorageService().uploadVerificationVideo(
  uid:         participantUid,
  video:       videoFile,
  title:       'توثيق المشارك — $participantName',
  onProgress:  (p) => setState(() => _progress = p),
);
```

### حدود YouTube:
- **الحجم الأقصى**: 128 GB أو 12 ساعة لكل فيديو
- **الحصة اليومية**: 10,000 وحدة (رفع واحد = 1,600 وحدة → ~6 رفعات/يوم)
- الفيديوهات تُرفع كـ **Unlisted** (لا تظهر للعامة)

---

## 4. IPFS عبر Pinata

### إعداد Pinata:
1. أنشئ حساباً على [app.pinata.cloud](https://app.pinata.cloud)
2. **API Keys** → **New Key**:
   - اختر: `pinFileToIPFS`, `pinJSONToIPFS`, `unpin`
   - انسخ **JWT Token**
3. (اختياري) في إعدادات Pinata أنشئ **Custom Gateway** لروابط أسرع

### كود Flutter:
```dart
ExternalStorageService().configure(
  ...
  pinataJwt:      'eyJhbGciOiJIUzI1NiIsIn...',
  pinataGateway:  'https://my-gateway.mypinata.cloud/ipfs/', // اختياري
);
```

### الخطة المجانية:
- **1 GB** تخزين مجاني
- **عدد غير محدود** من الطلبات
- روابط دائمة: `https://ipfs.io/ipfs/<CID>`

---

## تهيئة كاملة (مثال في main.dart):

```dart
// بعد Firebase.initializeApp()
ExternalStorageService().configure(
  telegramToken:      const String.fromEnvironment('TG_BOT_TOKEN'),
  telegramChannel:    const String.fromEnvironment('TG_CHANNEL_ID'),
  sheetsWebAppUrl:    const String.fromEnvironment('SHEETS_WEB_APP_URL'),
  sheetsId:           const String.fromEnvironment('SHEETS_ID'),
  youtubeAccessToken: const String.fromEnvironment('YT_ACCESS_TOKEN'),
  pinataJwt:          const String.fromEnvironment('PINATA_JWT'),
);
```

### تشغيل مع المتغيرات:
```bash
flutter run \
  --dart-define=TG_BOT_TOKEN=7123456789:AAF... \
  --dart-define=TG_CHANNEL_ID=-1001234567890 \
  --dart-define=SHEETS_WEB_APP_URL=https://script.google.com/... \
  --dart-define=SHEETS_ID=1BxiMVs0... \
  --dart-define=PINATA_JWT=eyJhbGci...
```

---

## هيكل Firestore للمراجع:

```
firestore/
├── telegram_refs/
│   └── {uid}/
│       └── files/
│           └── {docId}: { fileId, messageId, category, fileSize, uploadedAt }
│
├── youtube_refs/
│   └── {uid}/
│       └── videos/
│           └── {docId}: { videoId, title, url, fileSize, uploadedAt }
│
└── ipfs_refs/
    └── {uid}/
        └── files/
            └── {docId}: { cid, url, pinSize, fileName, category, uploadedAt }
```
