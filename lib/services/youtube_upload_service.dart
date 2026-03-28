import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// YouTubeUploadService — مستودع الفيديو الضخم المجاني
///
/// يرفع مقاطع الفيديو الطويلة (تسجيلات التحقق، وثائق الالتزام)
/// مباشرةً إلى قناة YouTube الخاصة بالقائد بصيغة "Unlisted"
/// ويحفظ فقط videoId الخفيف في Firestore.
///
/// يستخدم YouTube Data API v3 مع OAuth 2.0 (Resumable Upload).
///
/// التدفق:
///   1. طلب "resumable session URI" من YouTube
///   2. رفع الملف chunk بـ chunk (يدعم استئناف الرفع عند الانقطاع)
///   3. حفظ videoId في Firestore تحت telegram_refs/{uid}/videos
///
/// الإعداد المطلوب:
///   - accessToken: OAuth 2.0 token للقناة (يُجدَّد تلقائياً)
///   - channelId: معرّف قناة YouTube الخاصة
///   - يجب تفعيل YouTube Data API v3 في Google Cloud Console
///   - Scopes: https://www.googleapis.com/auth/youtube.upload
class YouTubeUploadService {
  static final YouTubeUploadService _instance = YouTubeUploadService._();
  factory YouTubeUploadService() => _instance;
  YouTubeUploadService._();

  static const String _uploadUrl =
      'https://www.googleapis.com/upload/youtube/v3/videos'
      '?uploadType=resumable&part=snippet,status';

  static const Duration _initTimeout   = Duration(seconds: 30);
  static const Duration _chunkTimeout  = Duration(minutes: 3);
  static const int      _chunkSize     = 5 * 1024 * 1024; // 5 MB per chunk

  final _firestore = FirebaseFirestore.instance;

  String _accessToken = '';

  /// يُزوَّد بـ access token محدَّث قبل كل عملية رفع
  void setAccessToken(String token) => _accessToken = token;

  // ══════════════════════════════════════════════════════════════
  // Upload
  // ══════════════════════════════════════════════════════════════

  /// رفع فيديو تحقق للمشارك إلى YouTube كـ Unlisted
  ///
  /// [videoFile]       — ملف الفيديو المحلي (mp4, mov, avi)
  /// [participantUid]  — معرّف المشارك (يُضاف في الوصف)
  /// [title]           — عنوان الفيديو على YouTube
  /// [description]     — وصف اختياري
  /// [onProgress]      — callback للتقدم (0.0 → 1.0)
  ///
  /// يُعيد [YouTubeUploadResult] يحتوي على videoId
  Future<YouTubeUploadResult> uploadVideo({
    required File   videoFile,
    required String participantUid,
    required String title,
    String description   = '',
    String category      = '22',   // People & Blogs
    Function(double)? onProgress,
  }) async {
    _assertConfigured();

    final fileSize = videoFile.lengthSync();
    debugPrint('[YouTube] رفع: $title ($fileSize bytes)');

    // الخطوة 1: الحصول على Resumable Session URI
    final sessionUri = await _initResumableUpload(
      title:          title,
      description:    _buildDescription(participantUid, description),
      categoryId:     category,
      fileSize:       fileSize,
      mimeType:       _detectMime(videoFile.path),
    );

    // الخطوة 2: رفع البيانات chunk بـ chunk
    final videoId = await _resumableUpload(
      sessionUri:  sessionUri,
      videoFile:   videoFile,
      fileSize:    fileSize,
      onProgress:  onProgress,
    );

    final result = YouTubeUploadResult(
      videoId:  videoId,
      title:    title,
      url:      'https://youtu.be/$videoId',
      fileSize: fileSize,
    );

    await _saveRef(participantUid, result);
    debugPrint('[YouTube] ✓ رُفع: https://youtu.be/$videoId');
    return result;
  }

  // ══════════════════════════════════════════════════════════════
  // Retrieval
  // ══════════════════════════════════════════════════════════════

  /// جلب قائمة الفيديوهات لمشارك من Firestore
  Future<List<YouTubeVideoRef>> getParticipantVideos(
      String participantUid) async {
    final snap = await _firestore
        .collection('youtube_refs')
        .doc(participantUid)
        .collection('videos')
        .orderBy('uploadedAt', descending: true)
        .get();

    return snap.docs
        .map((d) => YouTubeVideoRef.fromFirestore(d.data()))
        .toList();
  }

  /// رابط المشاهدة لفيديو
  String watchUrl(String videoId) => 'https://youtu.be/$videoId';

  /// رابط التضمين (embed) لفيديو
  String embedUrl(String videoId) =>
      'https://www.youtube.com/embed/$videoId';

  // ══════════════════════════════════════════════════════════════
  // Resumable Upload Protocol
  // ══════════════════════════════════════════════════════════════

  Future<Uri> _initResumableUpload({
    required String title,
    required String description,
    required String categoryId,
    required int    fileSize,
    required String mimeType,
  }) async {
    final metadata = jsonEncode({
      'snippet': {
        'title':       title,
        'description': description,
        'categoryId':  categoryId,
      },
      'status': {
        'privacyStatus': 'unlisted',   // غير مدرج — لا يظهر للعامة
      },
    });

    final resp = await http.post(
      Uri.parse(_uploadUrl),
      headers: {
        'Authorization':           'Bearer $_accessToken',
        'Content-Type':            'application/json; charset=UTF-8',
        'X-Upload-Content-Type':   mimeType,
        'X-Upload-Content-Length': fileSize.toString(),
      },
      body: metadata,
    ).timeout(_initTimeout);

    if (resp.statusCode != 200) {
      throw YouTubeUploadException(
          'فشل بدء الرفع: HTTP ${resp.statusCode} — ${resp.body}');
    }

    final location = resp.headers['location'];
    if (location == null) {
      throw YouTubeUploadException('لم يُعطِ YouTube رابط الجلسة');
    }
    return Uri.parse(location);
  }

  Future<String> _resumableUpload({
    required Uri      sessionUri,
    required File     videoFile,
    required int      fileSize,
    Function(double)? onProgress,
  }) async {
    final raf     = videoFile.openSync();
    int   offset  = 0;
    String? videoId;

    try {
      while (offset < fileSize) {
        final end     = (offset + _chunkSize).clamp(0, fileSize);
        final chunk   = raf.readSync(end - offset);
        final isLast  = end == fileSize;

        final resp = await http.put(
          sessionUri,
          headers: {
            'Authorization':  'Bearer $_accessToken',
            'Content-Range':  'bytes $offset-${end - 1}/$fileSize',
            'Content-Length': chunk.length.toString(),
          },
          body: chunk,
        ).timeout(_chunkTimeout);

        if (resp.statusCode == 308) {
          // Incomplete — YouTube طلب المزيد
          final range = resp.headers['range'];
          if (range != null) {
            offset = int.parse(range.split('-').last) + 1;
          } else {
            offset = end;
          }
          onProgress?.call(offset / fileSize);
        } else if (resp.statusCode == 200 || resp.statusCode == 201) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          videoId = body['id'] as String?;
          onProgress?.call(1.0);
          break;
        } else {
          throw YouTubeUploadException(
              'فشل رفع chunk: HTTP ${resp.statusCode} — ${resp.body}');
        }
      }
    } finally {
      raf.closeSync();
    }

    if (videoId == null || videoId.isEmpty) {
      throw YouTubeUploadException('لم يُعطِ YouTube معرّف الفيديو بعد الرفع');
    }
    return videoId;
  }

  // ══════════════════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════════════════

  Future<void> _saveRef(String uid, YouTubeUploadResult result) async {
    await _firestore
        .collection('youtube_refs')
        .doc(uid)
        .collection('videos')
        .add({
      'videoId':    result.videoId,
      'title':      result.title,
      'url':        result.url,
      'fileSize':   result.fileSize,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
  }

  String _buildDescription(String uid, String custom) {
    final ts = DateTime.now().toIso8601String();
    return 'المشارك: $uid\nالتاريخ: $ts\n\n$custom';
  }

  String _detectMime(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'mp4'  => 'video/mp4',
      'mov'  => 'video/quicktime',
      'avi'  => 'video/x-msvideo',
      'mkv'  => 'video/x-matroska',
      'webm' => 'video/webm',
      _      => 'video/mp4',
    };
  }

  void _assertConfigured() {
    if (_accessToken.isEmpty) {
      throw YouTubeUploadException(
          'YouTubeUploadService: access token مطلوب — استدعِ setAccessToken() أولاً');
    }
  }
}

// ── Data Models ──────────────────────────────────────────────

class YouTubeUploadResult {
  final String videoId;
  final String title;
  final String url;
  final int    fileSize;

  const YouTubeUploadResult({
    required this.videoId,
    required this.title,
    required this.url,
    required this.fileSize,
  });
}

class YouTubeVideoRef {
  final String  videoId;
  final String  title;
  final String  url;
  final int     fileSize;
  final DateTime? uploadedAt;

  const YouTubeVideoRef({
    required this.videoId,
    required this.title,
    required this.url,
    required this.fileSize,
    this.uploadedAt,
  });

  factory YouTubeVideoRef.fromFirestore(Map<String, dynamic> d) {
    return YouTubeVideoRef(
      videoId:    d['videoId']  as String,
      title:      d['title']    as String,
      url:        d['url']      as String,
      fileSize:   (d['fileSize'] as num?)?.toInt() ?? 0,
      uploadedAt: (d['uploadedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class YouTubeUploadException implements Exception {
  final String message;
  const YouTubeUploadException(this.message);
  @override
  String toString() => 'YouTubeUploadException: $message';
}
