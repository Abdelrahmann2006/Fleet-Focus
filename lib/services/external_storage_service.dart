import 'dart:io';
import 'package:flutter/foundation.dart';
import 'telegram_storage_service.dart';
import 'sheets_logging_service.dart';
import 'youtube_upload_service.dart';
import 'ipfs_service.dart';

export 'telegram_storage_service.dart';
export 'sheets_logging_service.dart';
export 'youtube_upload_service.dart';
export 'ipfs_service.dart';

/// ExternalStorageService — واجهة موحّدة للتخزين الخارجي المجاني
///
/// يُوجّه الملفات تلقائياً إلى المستودع المناسب حسب نوعها:
///
///   📷  صور (Snap Check-in, دليل المهمة)  → Telegram + IPFS (نسخة احتياطية)
///   🎬  فيديو قصير (≤ 50MB)               → Telegram
///   🎬  فيديو طويل (تحقق / التزام)         → YouTube (Unlisted)
///   🔊  صوت                                → Telegram + IPFS
///   📄  JSON / تقارير / سجلات             → Google Sheets (تاريخي) + IPFS (أرشيف)
///
/// الاستخدام من الـ UI:
/// ```dart
/// final storage = ExternalStorageService();
/// storage.configure(
///   telegramToken:  'BOT_TOKEN',
///   telegramChannel: '-100xxx',
///   sheetsWebAppUrl: 'https://script.google.com/macros/s/...',
///   sheetsId:        '1BxiMVs0...',
///   pinataJwt:       'eyJhbGci...',
/// );
///
/// // رفع صورة
/// final result = await storage.uploadPhoto(uid: uid, file: photoFile);
/// print(result.telegramFileId);   // مرجع خفيف في Firestore
///
/// // أرشفة بيانات استشعار
/// await storage.archiveTelemetry(uid: uid, data: telemetryMap);
/// ```
class ExternalStorageService {
  static final ExternalStorageService _instance = ExternalStorageService._();
  factory ExternalStorageService() => _instance;
  ExternalStorageService._();

  final _telegram = TelegramStorageService();
  final _sheets   = SheetsLoggingService();
  final _youtube  = YouTubeUploadService();
  final _ipfs     = IPFSService();

  bool _configured = false;

  // ── Configuration ─────────────────────────────────────────────

  void configure({
    // Telegram (مطلوب)
    required String telegramToken,
    required String telegramChannel,

    // Google Sheets (مطلوب)
    required String sheetsWebAppUrl,
    required String sheetsId,

    // YouTube (اختياري — للفيديو الطويل)
    String? youtubeAccessToken,

    // IPFS / Pinata (اختياري — للتخزين الاحتياطي اللامركزي)
    String? pinataJwt,
    String? pinataGateway,
  }) {
    _telegram.configure(
      botToken:  telegramToken,
      channelId: telegramChannel,
    );

    _sheets.configure(
      webAppUrl:     sheetsWebAppUrl,
      spreadsheetId: sheetsId,
    );

    if (youtubeAccessToken != null) {
      _youtube.setAccessToken(youtubeAccessToken);
    }

    if (pinataJwt != null) {
      _ipfs.configure(
        pinataJwt:     pinataJwt,
        customGateway: pinataGateway,
      );
    }

    _configured = true;
    debugPrint('[ExternalStorage] ✓ All services configured');
  }

  // ══════════════════════════════════════════════════════════════
  // Smart Upload Routing
  // ══════════════════════════════════════════════════════════════

  /// رفع صورة (Snap Check-in / دليل مهمة)
  /// → Telegram أساسي + IPFS نسخة احتياطية (إن كان مُفعَّلاً)
  Future<PhotoUploadResult> uploadPhoto({
    required String uid,
    required File   photo,
    String? caption,
    TelegramFileCategory category = TelegramFileCategory.snapCheckin,
    bool alsoToIPFS = false,
  }) async {
    _assertConfigured();

    final tg = await _telegram.uploadPhoto(
      participantUid: uid,
      photo:          photo,
      caption:        caption,
      category:       category,
    );

    IPFSUploadResult? ipfs;
    if (alsoToIPFS) {
      try {
        ipfs = await _ipfs.uploadFile(
          participantUid: uid,
          file:           photo,
          category:       IPFSFileCategory.photo,
        );
      } catch (e) {
        debugPrint('[ExternalStorage] IPFS backup failed (non-critical): $e');
      }
    }

    return PhotoUploadResult(
      telegramFileId: tg.fileId,
      telegramMsgId:  tg.messageId,
      ipfsCid:        ipfs?.cid,
      ipfsUrl:        ipfs?.url,
    );
  }

  /// رفع تسجيل شاشة قصير (≤ 50MB) → Telegram
  Future<TelegramUploadResult> uploadScreenRecording({
    required String uid,
    required File   video,
    String? caption,
  }) async {
    _assertConfigured();
    return _telegram.uploadVideo(
      participantUid: uid,
      video:          video,
      caption:        caption,
      category:       TelegramFileCategory.screenRecording,
    );
  }

  /// رفع فيديو تحقق طويل → YouTube (Unlisted)
  Future<YouTubeUploadResult> uploadVerificationVideo({
    required String uid,
    required File   video,
    required String title,
    String? description,
    Function(double)? onProgress,
  }) async {
    _assertConfigured();
    return _youtube.uploadVideo(
      participantUid: uid,
      videoFile:      video,
      title:          title,
      description:    description ?? '',
      onProgress:     onProgress,
    );
  }

  /// رفع ملف صوتي
  /// → Telegram أساسي + IPFS نسخة احتياطية
  Future<AudioUploadResult> uploadAudio({
    required String uid,
    required File   audio,
    bool alsoToIPFS = true,
  }) async {
    _assertConfigured();

    final tg = await _telegram.uploadAudio(
      participantUid: uid,
      audio:          audio,
      category:       TelegramFileCategory.audioRecord,
    );

    IPFSUploadResult? ipfs;
    if (alsoToIPFS) {
      try {
        ipfs = await _ipfs.uploadFile(
          participantUid: uid,
          file:           audio,
          category:       IPFSFileCategory.audioRecord,
        );
      } catch (e) {
        debugPrint('[ExternalStorage] IPFS audio backup failed: $e');
      }
    }

    return AudioUploadResult(
      telegramFileId: tg.fileId,
      ipfsCid:        ipfs?.cid,
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Telemetry Archiving
  // ══════════════════════════════════════════════════════════════

  /// أرشفة بيانات استشعار → Google Sheets
  Future<void> archiveTelemetry({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _sheets.logTelemetry(
      participantUid:  uid,
      batteryPct:      (data['batteryPct']      as num?)?.toInt()  ?? -1,
      batteryCharging: (data['batteryCharging'] as bool?) ?? false,
      screenActive:    (data['screenActive']    as bool?) ?? false,
      pulse:           (data['pulse']           as String?) ?? 'unknown',
      lat:             (data['lat']             as double?),
      lng:             (data['lng']             as double?),
      storageFreePct:  (data['storageFreePct']  as double?),
      currentJob:      (data['currentJob']      as String?),
      taskProgress:    (data['taskProgress']    as double?),
    );
  }

  /// تسجيل حدث → Google Sheets
  Future<void> logEvent({
    required String uid,
    required String eventType,
    String? details,
    String? actorUid,
  }) => _sheets.logEvent(
    participantUid: uid,
    eventType:      eventType,
    details:        details,
    actorUid:       actorUid,
  );

  /// أرشفة سجل JSON كبير → Sheets + IPFS
  Future<void> archiveActivityLog({
    required String uid,
    required Map<String, dynamic> logData,
    File? localFile,
  }) async {
    _assertConfigured();

    // IPFS: أرشيف JSON لامركزي
    try {
      await _ipfs.uploadJson(
        participantUid: uid,
        data:           logData,
        category:       IPFSFileCategory.activityLog,
      );
    } catch (e) {
      debugPrint('[ExternalStorage] IPFS JSON upload failed: $e');
    }

    // Sheets: صف ملخص
    await _sheets.logEvent(
      participantUid: uid,
      eventType:      'activity_log_archived',
      details:        'IPFS archive: ${logData.keys.join(", ")}',
    );

    // Telegram: الملف الفعلي (إن كان موجوداً)
    if (localFile != null) {
      await _telegram.uploadDocument(
        participantUid: uid,
        document:       localFile,
        category:       TelegramFileCategory.activityLog,
      );
    }
  }

  /// تفريغ قائمة انتظار Sheets يدوياً
  Future<void> flushSheets() => _sheets.flush();

  // ══════════════════════════════════════════════════════════════
  // Direct Service Access (للاستخدام المتقدم)
  // ══════════════════════════════════════════════════════════════

  TelegramStorageService get telegram => _telegram;
  SheetsLoggingService   get sheets   => _sheets;
  YouTubeUploadService   get youtube  => _youtube;
  IPFSService            get ipfs     => _ipfs;

  // ── Internal ──────────────────────────────────────────────────

  void _assertConfigured() {
    if (!_configured) {
      throw StateError(
          'ExternalStorageService غير مُهيَّأ — استدعِ configure() أولاً');
    }
  }
}

// ── Composite Result Models ───────────────────────────────────

class PhotoUploadResult {
  final String  telegramFileId;
  final int     telegramMsgId;
  final String? ipfsCid;
  final String? ipfsUrl;

  const PhotoUploadResult({
    required this.telegramFileId,
    required this.telegramMsgId,
    this.ipfsCid,
    this.ipfsUrl,
  });
}

class AudioUploadResult {
  final String  telegramFileId;
  final String? ipfsCid;

  const AudioUploadResult({
    required this.telegramFileId,
    this.ipfsCid,
  });
}
