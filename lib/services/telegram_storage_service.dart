import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

/// TelegramStorageService — مستودع الوسائط المجاني عبر Telegram Bot API
///
/// يرفع الملفات الضخمة (صور، تسجيلات شاشة، ملفات JSON) مباشرةً
/// إلى قناة Telegram خاصة بدلاً من Firebase Storage.
///
/// التدفق:
///   1. رفع الملف إلى Telegram → يُعيد message_id + file_id
///   2. حفظ المرجع الخفيف (file_id فقط) في Firestore
///   3. استرجاع رابط التنزيل عند الطلب عبر getFileUrl()
///
/// الإعداد المطلوب:
///   - botToken: رمز البوت من @BotFather
///   - channelId: معرّف القناة الخاصة (مثال: @my_private_channel أو -100xxxxxxxxx)
///   - يجب إضافة البوت مشرفاً في القناة بصلاحية نشر الرسائل
class TelegramStorageService {
  static final TelegramStorageService _instance = TelegramStorageService._();
  factory TelegramStorageService() => _instance;
  TelegramStorageService._();

  static const String _baseUrl = 'https://api.telegram.org/bot';
  static const Duration _uploadTimeout   = Duration(minutes: 5);
  static const Duration _standardTimeout = Duration(seconds: 30);
  static const int _maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB حد Telegram Bot

  final _firestore = FirebaseFirestore.instance;

  // ── Configuration (يُملأ عند تهيئة التطبيق) ───────────────
  String _botToken  = '';
  String _channelId = '';

  void configure({required String botToken, required String channelId}) {
    _botToken  = botToken;
    _channelId = channelId;
  }

  String get _apiBase => '$_baseUrl$_botToken';

  // ══════════════════════════════════════════════════════════════
  // Upload Methods
  // ══════════════════════════════════════════════════════════════

  /// رفع صورة (selfie / snap check-in / دليل مهمة)
  /// يُعيد [TelegramUploadResult] يحتوي على file_id و message_id
  Future<TelegramUploadResult> uploadPhoto({
    required String participantUid,
    required File photo,
    String? caption,
    TelegramFileCategory category = TelegramFileCategory.snapCheckin,
  }) async {
    _assertConfigured();
    final compressed = await _compressToUnder50MB(photo);
    _assertFileSize(compressed);

    final uri = Uri.parse('$_apiBase/sendPhoto');
    final request = http.MultipartRequest('POST', uri)
      ..fields['chat_id'] = _channelId
      ..fields['caption'] = _buildCaption(participantUid, caption, category)
      ..files.add(await http.MultipartFile.fromPath(
        'photo', compressed.path,
        contentType: MediaType('image', _mimeSubtype(compressed.path)),
      ));

    final result = await _sendRequest(request, _uploadTimeout);
    final photoList = result['photo'] as List;
    final best = photoList.last as Map<String, dynamic>;

    final uploadResult = TelegramUploadResult(
      fileId:    best['file_id'] as String,
      messageId: result['message_id'] as int,
      category:  category,
      fileSize:  best['file_size'] as int? ?? 0,
    );

    await _saveRef(participantUid, uploadResult, category);
    return uploadResult;
  }

  /// رفع فيديو (تسجيل الشاشة — مدة قصيرة ≤ 50 MB)
  Future<TelegramUploadResult> uploadVideo({
    required String participantUid,
    required File video,
    String? caption,
    TelegramFileCategory category = TelegramFileCategory.screenRecording,
  }) async {
    _assertConfigured();
    // للفيديو: تحقق فقط — الضغط ليس ممكناً بدون تحويل codec
    _assertFileSize(video);

    final uri = Uri.parse('$_apiBase/sendVideo');
    final request = http.MultipartRequest('POST', uri)
      ..fields['chat_id']            = _channelId
      ..fields['caption']            = _buildCaption(participantUid, caption, category)
      ..fields['supports_streaming'] = 'true'
      ..files.add(await http.MultipartFile.fromPath(
        'video', video.path,
        contentType: MediaType('video', 'mp4'),
      ));

    final result = await _sendRequest(request, _uploadTimeout);
    final videoMeta = result['video'] as Map<String, dynamic>;

    final uploadResult = TelegramUploadResult(
      fileId:    videoMeta['file_id'] as String,
      messageId: result['message_id'] as int,
      category:  category,
      fileSize:  videoMeta['file_size'] as int? ?? 0,
    );

    await _saveRef(participantUid, uploadResult, category);
    return uploadResult;
  }

  /// رفع مستند عام (JSON نشاط، PDF تقرير، ملف مضغوط)
  Future<TelegramUploadResult> uploadDocument({
    required String participantUid,
    required File document,
    String? caption,
    TelegramFileCategory category = TelegramFileCategory.activityLog,
  }) async {
    _assertConfigured();
    // للمستندات: الضغط يتم عبر ZIP في HiveBlackboxService مسبقاً
    _assertFileSize(document);

    final uri = Uri.parse('$_apiBase/sendDocument');
    final request = http.MultipartRequest('POST', uri)
      ..fields['chat_id'] = _channelId
      ..fields['caption'] = _buildCaption(participantUid, caption, category)
      ..files.add(await http.MultipartFile.fromPath(
        'document', document.path,
      ));

    final result = await _sendRequest(request, _uploadTimeout);
    final docMeta = result['document'] as Map<String, dynamic>;

    final uploadResult = TelegramUploadResult(
      fileId:    docMeta['file_id'] as String,
      messageId: result['message_id'] as int,
      category:  category,
      fileSize:  docMeta['file_size'] as int? ?? 0,
    );

    await _saveRef(participantUid, uploadResult, category);
    return uploadResult;
  }

  /// رفع ملف صوتي (تسجيل صوتي قصير)
  Future<TelegramUploadResult> uploadAudio({
    required String participantUid,
    required File audio,
    String? caption,
    TelegramFileCategory category = TelegramFileCategory.audioRecord,
  }) async {
    _assertConfigured();
    _assertFileSize(audio);

    final uri = Uri.parse('$_apiBase/sendAudio');
    final request = http.MultipartRequest('POST', uri)
      ..fields['chat_id'] = _channelId
      ..fields['caption'] = _buildCaption(participantUid, caption, category)
      ..files.add(await http.MultipartFile.fromPath(
        'audio', audio.path,
        contentType: MediaType('audio', _mimeSubtype(audio.path)),
      ));

    final result = await _sendRequest(request, _uploadTimeout);
    final audioMeta = result['audio'] as Map<String, dynamic>;

    final uploadResult = TelegramUploadResult(
      fileId:    audioMeta['file_id'] as String,
      messageId: result['message_id'] as int,
      category:  category,
      fileSize:  audioMeta['file_size'] as int? ?? 0,
    );

    await _saveRef(participantUid, uploadResult, category);
    return uploadResult;
  }

  // ══════════════════════════════════════════════════════════════
  // Retrieval Methods
  // ══════════════════════════════════════════════════════════════

  /// الحصول على رابط تنزيل مباشر من file_id
  /// ملاحظة: الرابط مؤقت (يصلح 60 دقيقة)
  Future<String> getFileUrl(String fileId) async {
    _assertConfigured();

    final resp = await http
        .get(Uri.parse('$_apiBase/getFile?file_id=$fileId'))
        .timeout(_standardTimeout);

    final body = _parseResponse(resp);
    final path = body['file_path'] as String;
    return 'https://api.telegram.org/file/bot$_botToken/$path';
  }

  /// جلب كل مراجع الملفات لمشارك معين من Firestore
  Future<List<TelegramFileRef>> getParticipantFiles(
      String participantUid, {
      TelegramFileCategory? category,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('telegram_refs')
        .doc(participantUid)
        .collection('files')
        .orderBy('uploadedAt', descending: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    final snap = await query.get();
    return snap.docs
        .map((d) => TelegramFileRef.fromFirestore(d.data()))
        .toList();
  }

  // ══════════════════════════════════════════════════════════════
  // Compression Engine — <50 MB Enforcement
  // ══════════════════════════════════════════════════════════════

  /// يضغط الملف تدريجياً حتى يصبح حجمه أقل من 50 MB.
  /// للصور (JPEG/PNG/WEBP): يقلل الجودة من 90% نزولاً حتى 30%.
  /// لغير الصور: يُعيد الملف بدون تعديل.
  Future<File> _compressToUnder50MB(File file) async {
    final sizeBytes = await file.length();
    if (sizeBytes <= _maxFileSizeBytes) return file; // أقل من 50 MB — لا حاجة

    final ext = file.path.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
    if (!isImage) return file; // فيديو/مستند — لا ضغط

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = '${dir.path}/compressed_$timestamp.jpg';

    // ضغط تدريجي: جودة 85 → 70 → 55 → 40 → 30
    for (final quality in [85, 70, 55, 40, 30]) {
      try {
        final result = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          quality: quality,
          format: CompressFormat.jpeg,
        );

        if (result == null) break;
        final compressedFile = File(result.path);
        final compressedSize = await compressedFile.length();

        debugPrint('[TelegramStorage] ضغط بجودة $quality: '
            '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB → '
            '${(compressedSize / 1024 / 1024).toStringAsFixed(1)} MB');

        if (compressedSize <= _maxFileSizeBytes) return compressedFile;
      } catch (e) {
        debugPrint('[TelegramStorage] فشل الضغط بجودة $quality: $e');
        break;
      }
    }

    // fallback: أعِد الملف الأصلي وسيرفع _assertFileSize خطأ واضحاً
    return file;
  }

  // ══════════════════════════════════════════════════════════════
  // Internal Helpers
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _sendRequest(
      http.MultipartRequest request, Duration timeout) async {
    try {
      final streamed = await request.send().timeout(timeout);
      final resp     = await http.Response.fromStream(streamed);
      return _parseResponse(resp);
    } on SocketException catch (e) {
      throw TelegramStorageException('خطأ في الشبكة: ${e.message}');
    } on TimeoutException {
      throw TelegramStorageException('انتهت مهلة الرفع — الملف كبير جداً أو الاتصال بطيء');
    }
  }

  Map<String, dynamic> _parseResponse(http.Response resp) {
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['ok'] != true) {
      final desc = body['description'] ?? 'خطأ غير معروف';
      throw TelegramStorageException('Telegram API: $desc (code: ${body['error_code']})');
    }
    return body['result'] as Map<String, dynamic>;
  }

  Future<void> _saveRef(
      String uid,
      TelegramUploadResult result,
      TelegramFileCategory category) async {
    await _firestore
        .collection('telegram_refs')
        .doc(uid)
        .collection('files')
        .add({
      'fileId':     result.fileId,
      'messageId':  result.messageId,
      'category':   category.name,
      'fileSize':   result.fileSize,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[TelegramStorage] Ref saved for $uid — category: ${category.name}');
  }

  void _assertConfigured() {
    if (_botToken.isEmpty || _channelId.isEmpty) {
      throw TelegramStorageException(
          'TelegramStorageService غير مُهيَّأ — استدعِ configure() أولاً');
    }
  }

  void _assertFileSize(File file) {
    final size = file.lengthSync();
    if (size > _maxFileSizeBytes) {
      throw TelegramStorageException(
          'حجم الملف ($size bytes) يتجاوز الحد المسموح (50 MB)');
    }
  }

  String _buildCaption(String uid, String? custom, TelegramFileCategory cat) {
    final ts = DateTime.now().toIso8601String();
    return custom ?? '[${cat.label}] uid:$uid — $ts';
  }

  String _mimeSubtype(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'jpeg',
      'png'  => 'png',
      'webp' => 'webp',
      'mp3'  => 'mpeg',
      'ogg'  => 'ogg',
      'm4a'  => 'mp4',
      _      => 'octet-stream',
    };
  }
}

// ── Data Models ──────────────────────────────────────────────

enum TelegramFileCategory {
  snapCheckin(label: 'Snap Check-in'),
  screenRecording(label: 'تسجيل الشاشة'),
  taskProof(label: 'دليل المهمة'),
  activityLog(label: 'سجل النشاط'),
  audioRecord(label: 'تسجيل صوتي'),
  document(label: 'مستند');

  final String label;
  const TelegramFileCategory({required this.label});
}

class TelegramUploadResult {
  final String fileId;
  final int    messageId;
  final TelegramFileCategory category;
  final int    fileSize;

  const TelegramUploadResult({
    required this.fileId,
    required this.messageId,
    required this.category,
    required this.fileSize,
  });
}

class TelegramFileRef {
  final String fileId;
  final int    messageId;
  final String category;
  final int    fileSize;
  final DateTime? uploadedAt;

  const TelegramFileRef({
    required this.fileId,
    required this.messageId,
    required this.category,
    required this.fileSize,
    this.uploadedAt,
  });

  factory TelegramFileRef.fromFirestore(Map<String, dynamic> d) {
    return TelegramFileRef(
      fileId:    d['fileId']    as String,
      messageId: d['messageId'] as int,
      category:  d['category']  as String,
      fileSize:  (d['fileSize'] as num?)?.toInt() ?? 0,
      uploadedAt: (d['uploadedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class TelegramStorageException implements Exception {
  final String message;
  const TelegramStorageException(this.message);
  @override
  String toString() => 'TelegramStorageException: $message';
}
