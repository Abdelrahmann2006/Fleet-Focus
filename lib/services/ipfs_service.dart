import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// IPFSService — التخزين اللامركزي الثانوي عبر Pinata
///
/// يُستخدم كمستودع ثانوي للصور والملفات الصوتية القصيرة.
/// يرفع الملفات إلى IPFS عبر Pinata API ويحفظ الـ CID (Content ID)
/// الخفيف في Firestore.
///
/// مزايا IPFS:
///   • لا مركزية — الملفات لا تُحذف ما دامت مُثبَّتة (pinned)
///   • Pinata مجانية حتى 1 GB
///   • رابط عام دائم عبر gateway.pinata.cloud أو ipfs.io
///
/// الإعداد المطلوب:
///   - pinataJwt: JWT token من لوحة Pinata (app.pinata.cloud)
///   - pinataGateway: (اختياري) Custom Gateway URL من Pinata
///
/// بديل: Web3.Storage (w3s.link) — مجاني تماماً — مذكور في التعليقات
class IPFSService {
  static final IPFSService _instance = IPFSService._();
  factory IPFSService() => _instance;
  IPFSService._();

  // ── Pinata API ────────────────────────────────────────────────
  static const String _pinataUploadUrl  = 'https://api.pinata.cloud/pinning/pinFileToIPFS';
  static const String _pinataJsonUrl    = 'https://api.pinata.cloud/pinning/pinJSONToIPFS';
  static const String _pinataListUrl    = 'https://api.pinata.cloud/data/pinList';
  static const String _pinataUnpinUrl   = 'https://api.pinata.cloud/pinning/unpin/';
  static const String _defaultGateway   = 'https://gateway.pinata.cloud/ipfs/';

  static const Duration _uploadTimeout  = Duration(minutes: 5);
  static const Duration _stdTimeout     = Duration(seconds: 20);
  static const int _maxFileSizeMB       = 100;

  final _firestore = FirebaseFirestore.instance;

  String _pinataJwt     = '';
  String _gatewayUrl    = _defaultGateway;

  void configure({
    required String pinataJwt,
    String? customGateway,
  }) {
    _pinataJwt  = pinataJwt;
    _gatewayUrl = customGateway ?? _defaultGateway;
  }

  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer $_pinataJwt',
  };

  // ══════════════════════════════════════════════════════════════
  // Upload Methods
  // ══════════════════════════════════════════════════════════════

  /// رفع ملف ثنائي (صورة، صوت، PDF) إلى IPFS عبر Pinata
  ///
  /// يُعيد [IPFSUploadResult] يحتوي على CID والرابط العام
  Future<IPFSUploadResult> uploadFile({
    required String participantUid,
    required File   file,
    String?  name,
    IPFSFileCategory category = IPFSFileCategory.photo,
    Map<String, String>? metadata,
  }) async {
    _assertConfigured();
    _assertFileSize(file);

    final fileName = name ?? _buildFileName(participantUid, category, file.path);
    final mimeType = _detectMime(file.path);

    final request = http.MultipartRequest('POST', Uri.parse(_pinataUploadUrl))
      ..headers.addAll(_authHeaders)
      ..files.add(await http.MultipartFile.fromPath(
        'file', file.path,
        filename:    fileName,
        contentType: MediaType.parse(mimeType),
      ))
      ..fields['pinataMetadata'] = jsonEncode({
        'name': fileName,
        'keyvalues': {
          'participantUid': participantUid,
          'category':       category.name,
          'uploadedAt':     DateTime.now().toIso8601String(),
          ...?metadata,
        },
      })
      ..fields['pinataOptions'] = jsonEncode({
        'cidVersion': 1,   // CIDv1 — أقصر وأحدث
      });

    final streamed = await request.send().timeout(_uploadTimeout);
    final resp     = await http.Response.fromStream(streamed);
    _assertHttpOk(resp, context: 'رفع الملف');

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final cid  = body['IpfsHash'] as String;
    final size = (body['PinSize'] as num?)?.toInt() ?? 0;

    final result = IPFSUploadResult(
      cid:       cid,
      url:       '$_gatewayUrl$cid',
      pinSize:   size,
      fileName:  fileName,
      category:  category,
    );

    await _saveRef(participantUid, result);
    debugPrint('[IPFS] ✓ Pinned: $cid (${size ~/ 1024} KB)');
    return result;
  }

  /// رفع JSON مباشرةً إلى IPFS (سجلات نشاط، بيانات منظّمة)
  Future<IPFSUploadResult> uploadJson({
    required String participantUid,
    required Map<String, dynamic> data,
    String? name,
    IPFSFileCategory category = IPFSFileCategory.activityLog,
  }) async {
    _assertConfigured();

    final fileName = name ?? _buildFileName(participantUid, category, 'json');

    final resp = await http.post(
      Uri.parse(_pinataJsonUrl),
      headers: {
        ..._authHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'pinataContent':  data,
        'pinataMetadata': {
          'name': fileName,
          'keyvalues': {
            'participantUid': participantUid,
            'category':       category.name,
            'uploadedAt':     DateTime.now().toIso8601String(),
          },
        },
        'pinataOptions': {'cidVersion': 1},
      }),
    ).timeout(_stdTimeout);

    _assertHttpOk(resp, context: 'رفع JSON');

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final cid  = body['IpfsHash'] as String;

    final result = IPFSUploadResult(
      cid:       cid,
      url:       '$_gatewayUrl$cid',
      pinSize:   (body['PinSize'] as num?)?.toInt() ?? 0,
      fileName:  fileName,
      category:  category,
    );

    await _saveRef(participantUid, result);
    debugPrint('[IPFS] ✓ JSON Pinned: $cid');
    return result;
  }

  // ══════════════════════════════════════════════════════════════
  // Retrieval
  // ══════════════════════════════════════════════════════════════

  /// رابط محتوى من CID
  String contentUrl(String cid) => '$_gatewayUrl$cid';

  /// رابط بديل عبر ipfs.io (عام)
  String publicUrl(String cid) => 'https://ipfs.io/ipfs/$cid';

  /// جلب مراجع الملفات لمشارك من Firestore
  Future<List<IPFSFileRef>> getParticipantFiles(
      String participantUid, {
      IPFSFileCategory? category,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('ipfs_refs')
        .doc(participantUid)
        .collection('files')
        .orderBy('uploadedAt', descending: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    final snap = await query.get();
    return snap.docs
        .map((d) => IPFSFileRef.fromFirestore(d.data()))
        .toList();
  }

  /// إلغاء تثبيت (unpin) ملف من Pinata لتحرير المساحة
  Future<void> unpin(String cid) async {
    _assertConfigured();
    final resp = await http.delete(
      Uri.parse('$_pinataUnpinUrl$cid'),
      headers: _authHeaders,
    ).timeout(_stdTimeout);

    if (resp.statusCode != 200) {
      debugPrint('[IPFS] Unpin failed for $cid: ${resp.statusCode}');
    } else {
      debugPrint('[IPFS] Unpinned: $cid');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Internal Helpers
  // ══════════════════════════════════════════════════════════════

  Future<void> _saveRef(String uid, IPFSUploadResult result) async {
    await _firestore
        .collection('ipfs_refs')
        .doc(uid)
        .collection('files')
        .add({
      'cid':        result.cid,
      'url':        result.url,
      'pinSize':    result.pinSize,
      'fileName':   result.fileName,
      'category':   result.category.name,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
  }

  void _assertConfigured() {
    if (_pinataJwt.isEmpty) {
      throw IPFSException('IPFSService غير مُهيَّأ — استدعِ configure() أولاً');
    }
  }

  void _assertFileSize(File file) {
    final sizeMB = file.lengthSync() / (1024 * 1024);
    if (sizeMB > _maxFileSizeMB) {
      throw IPFSException(
          'حجم الملف (${sizeMB.toStringAsFixed(1)} MB) يتجاوز ${_maxFileSizeMB}MB');
    }
  }

  void _assertHttpOk(http.Response resp, {required String context}) {
    if (resp.statusCode != 200) {
      throw IPFSException(
          'Pinata API ($context): HTTP ${resp.statusCode} — ${resp.body}');
    }
  }

  String _buildFileName(String uid, IPFSFileCategory cat, String pathOrExt) {
    final ext = pathOrExt.contains('.') ? pathOrExt.split('.').last : pathOrExt;
    final ts  = DateTime.now().millisecondsSinceEpoch;
    return '${cat.name}_${uid.substring(0, 8)}_$ts.$ext';
  }

  String _detectMime(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'  => 'image/png',
      'webp' => 'image/webp',
      'mp3'  => 'audio/mpeg',
      'ogg'  => 'audio/ogg',
      'm4a'  => 'audio/mp4',
      'pdf'  => 'application/pdf',
      'json' => 'application/json',
      _      => 'application/octet-stream',
    };
  }
}

// ── Data Models ──────────────────────────────────────────────

enum IPFSFileCategory {
  photo,
  audioRecord,
  activityLog,
  document,
  other;
}

class IPFSUploadResult {
  final String          cid;
  final String          url;
  final int             pinSize;
  final String          fileName;
  final IPFSFileCategory category;

  const IPFSUploadResult({
    required this.cid,
    required this.url,
    required this.pinSize,
    required this.fileName,
    required this.category,
  });
}

class IPFSFileRef {
  final String  cid;
  final String  url;
  final int     pinSize;
  final String  fileName;
  final String  category;
  final DateTime? uploadedAt;

  const IPFSFileRef({
    required this.cid,
    required this.url,
    required this.pinSize,
    required this.fileName,
    required this.category,
    this.uploadedAt,
  });

  factory IPFSFileRef.fromFirestore(Map<String, dynamic> d) => IPFSFileRef(
    cid:        d['cid']      as String,
    url:        d['url']      as String,
    pinSize:    (d['pinSize'] as num?)?.toInt() ?? 0,
    fileName:   d['fileName'] as String,
    category:   d['category'] as String,
    uploadedAt: (d['uploadedAt'] as Timestamp?)?.toDate(),
  );
}

class IPFSException implements Exception {
  final String message;
  const IPFSException(this.message);
  @override
  String toString() => 'IPFSException: $message';
}
