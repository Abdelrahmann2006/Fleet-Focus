import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// SheetsLoggingService — أرشفة البيانات التاريخية مجاناً عبر Google Apps Script
///
/// بدلاً من إغراق Firestore بالبيانات التاريخية، يرسل هذا السيرفس
/// البيانات مباشرةً إلى Google Apps Script Web App الذي يكتبها
/// في Google Sheets.
///
/// التدفق:
///   Flutter → POST → Apps Script Web App URL → Google Sheets
///
/// الإعداد المطلوب (مرة واحدة):
///   1. انشئ Google Apps Script جديد على script.google.com
///   2. الصق الكود الموجود في التعليق أدناه
///   3. انشر كـ "Web App" → Execute as "Me" → Access "Anyone"
///   4. انسخ رابط Web App وضعه في configure(webAppUrl: '...')
///
/// ─── كود Apps Script الجاهز ────────────────────────────────
/// ```javascript
/// function doPost(e) {
///   try {
///     const data = JSON.parse(e.postData.contents);
///     const sheetName = data.sheet || 'Telemetry';
///     const ss = SpreadsheetApp.openById(data.spreadsheetId || SPREADSHEET_ID);
///     const sheet = ss.getSheetByName(sheetName) || ss.insertSheet(sheetName);
///
///     if (Array.isArray(data.rows)) {
///       data.rows.forEach(row => sheet.appendRow(row));
///     } else if (data.row) {
///       sheet.appendRow(data.row);
///     }
///
///     return ContentService.createTextOutput(
///       JSON.stringify({ success: true, rowsAppended: data.rows?.length || 1 })
///     ).setMimeType(ContentService.MimeType.JSON);
///   } catch(err) {
///     return ContentService.createTextOutput(
///       JSON.stringify({ success: false, error: err.message })
///     ).setMimeType(ContentService.MimeType.JSON);
///   }
/// }
/// ```
/// ────────────────────────────────────────────────────────────
class SheetsLoggingService {
  static final SheetsLoggingService _instance = SheetsLoggingService._();
  factory SheetsLoggingService() => _instance;
  SheetsLoggingService._();

  static const Duration _timeout      = Duration(seconds: 15);
  static const int      _batchSize    = 50;   // صفوف لكل طلب
  static const int      _maxRetries   = 3;

  String _webAppUrl      = '';
  String _spreadsheetId  = '';

  /// قائمة انتظار محلية — تُفرغ دورياً أو عند اكتمال الـ batch
  final List<List<dynamic>> _pendingRows = [];

  void configure({
    required String webAppUrl,
    required String spreadsheetId,
  }) {
    _webAppUrl     = webAppUrl;
    _spreadsheetId = spreadsheetId;
  }

  // ══════════════════════════════════════════════════════════════
  // Telemetry Logging
  // ══════════════════════════════════════════════════════════════

  /// تسجيل بيانات استشعار مشارك واحد
  Future<void> logTelemetry({
    required String participantUid,
    required int    batteryPct,
    required bool   batteryCharging,
    required bool   screenActive,
    required String pulse,
    double? lat,
    double? lng,
    double? storageFreePct,
    String? currentJob,
    double? taskProgress,
  }) async {
    final row = [
      DateTime.now().toIso8601String(),   // A: Timestamp
      participantUid,                      // B: UID
      batteryPct,                          // C: Battery %
      batteryCharging ? 'يشحن' : 'لا يشحن', // D: Charging
      screenActive ? 'نشطة' : 'خاملة',   // E: Screen
      pulse,                               // F: Pulse
      lat ?? '',                           // G: Latitude
      lng ?? '',                           // H: Longitude
      storageFreePct?.toStringAsFixed(1) ?? '', // I: Storage %
      currentJob ?? '',                    // J: Current Job
      taskProgress?.toStringAsFixed(0) ?? '', // K: Progress %
    ];

    await _enqueue(row, sheet: 'Telemetry');
  }

  /// تسجيل حدث نشاط (انضمام، خروج، قبول طلب...)
  Future<void> logEvent({
    required String participantUid,
    required String eventType,
    String? details,
    String? actorUid,
  }) async {
    final row = [
      DateTime.now().toIso8601String(),
      participantUid,
      eventType,
      details ?? '',
      actorUid ?? '',
    ];

    await _enqueue(row, sheet: 'Events');
  }

  /// تسجيل أمر صادر من القائد
  Future<void> logCommand({
    required String leaderUid,
    required String targetUid,
    required String command,
    String? payload,
    bool success = true,
  }) async {
    final row = [
      DateTime.now().toIso8601String(),
      leaderUid,
      targetUid,
      command,
      payload ?? '',
      success ? 'نجح' : 'فشل',
    ];

    await _enqueue(row, sheet: 'Commands');
  }

  /// تسجيل تسجيل الدخول/الخروج
  Future<void> logSession({
    required String uid,
    required String role,
    required String action,   // 'login' | 'logout'
    String? deviceModel,
    String? androidVersion,
  }) async {
    final row = [
      DateTime.now().toIso8601String(),
      uid,
      role,
      action,
      deviceModel ?? '',
      androidVersion ?? '',
    ];

    await _enqueue(row, sheet: 'Sessions');
  }

  /// دفع بيانات تقرير يومي مخصص (صفوف متعددة)
  Future<SheetsWriteResult> pushReport({
    required String sheetName,
    required List<List<dynamic>> rows,
    List<dynamic>? headerRow,
  }) async {
    _assertConfigured();

    final allRows = [
      if (headerRow != null) headerRow,
      ...rows,
    ];

    return _sendBatch(allRows, sheetName: sheetName);
  }

  // ══════════════════════════════════════════════════════════════
  // Flush Queue
  // ══════════════════════════════════════════════════════════════

  /// تفريغ قائمة الانتظار يدوياً (استدعِه دورياً أو عند إغلاق التطبيق)
  Future<void> flush() async {
    if (_pendingRows.isEmpty) return;
    final batch = List<List<dynamic>>.from(_pendingRows);
    _pendingRows.clear();

    // تقسيم إلى chunks بحجم _batchSize
    for (var i = 0; i < batch.length; i += _batchSize) {
      final chunk = batch.sublist(i,
          (i + _batchSize).clamp(0, batch.length));
      await _sendBatch(chunk, sheetName: 'Telemetry');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Internal
  // ══════════════════════════════════════════════════════════════

  Future<void> _enqueue(List<dynamic> row, {required String sheet}) async {
    _pendingRows.add([...row, sheet]);   // نضيف اسم الشيت كعمود مؤقت

    // auto-flush عند امتلاء الـ batch
    if (_pendingRows.length >= _batchSize) {
      await flush();
    }
  }

  Future<SheetsWriteResult> _sendBatch(
      List<List<dynamic>> rows, {required String sheetName}) async {
    _assertConfigured();

    final payload = jsonEncode({
      'spreadsheetId': _spreadsheetId,
      'sheet':         sheetName,
      'rows':          rows,
    });

    Exception? lastError;
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final resp = await http
            .post(
              Uri.parse(_webAppUrl),
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(_timeout);

        if (resp.statusCode != 200) {
          throw HttpException('HTTP ${resp.statusCode}: ${resp.body}');
        }

        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['success'] != true) {
          throw Exception('Apps Script error: ${body['error']}');
        }

        debugPrint('[SheetsLogging] ✓ ${rows.length} rows → $sheetName');
        return SheetsWriteResult(
          rowsWritten: (body['rowsAppended'] as num?)?.toInt() ?? rows.length,
          sheetName:   sheetName,
        );
      } on TimeoutException {
        lastError = TimeoutException('انتهت مهلة الطلب');
        debugPrint('[SheetsLogging] Timeout attempt $attempt/$_maxRetries');
      } on SocketException catch (e) {
        lastError = e;
        debugPrint('[SheetsLogging] Network error attempt $attempt: ${e.message}');
      } catch (e) {
        lastError = Exception(e.toString());
        debugPrint('[SheetsLogging] Error attempt $attempt: $e');
        break; // لا تُعيد المحاولة للأخطاء المنطقية
      }

      if (attempt < _maxRetries) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    throw SheetsLoggingException(
        'فشل الإرسال بعد $_maxRetries محاولات: ${lastError?.toString()}');
  }

  void _assertConfigured() {
    if (_webAppUrl.isEmpty || _spreadsheetId.isEmpty) {
      throw SheetsLoggingException(
          'SheetsLoggingService غير مُهيَّأ — استدعِ configure() أولاً');
    }
  }
}

// ── Data Models ──────────────────────────────────────────────

class SheetsWriteResult {
  final int    rowsWritten;
  final String sheetName;
  const SheetsWriteResult({required this.rowsWritten, required this.sheetName});

  @override
  String toString() => 'SheetsWriteResult($rowsWritten rows → $sheetName)';
}

class SheetsLoggingException implements Exception {
  final String message;
  const SheetsLoggingException(this.message);
  @override
  String toString() => 'SheetsLoggingException: $message';
}
