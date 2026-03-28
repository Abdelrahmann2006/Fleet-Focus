import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'sheets_logging_service.dart';
import 'ipfs_service.dart';

/// LogBatchService — نظام الترتيب والضغط الدوري للسجلات
///
/// بدلاً من إرسال كل حدث منفرداً، يُجمع الأحداث محلياً ويرسلها دفعة واحدة
/// كل 15 دقيقة. هذا يُقلّل:
///   • استهلاك البطارية (أقل wake-ups)
///   • استهلاك البيانات (overhead أقل)
///   • تكلفة Firestore / Sheets (أقل writes)
///
/// التدفق:
///   1. enqueue(): يُضيف حدثاً إلى الـ queue المحلية
///   2. كل 15 دقيقة: flush() يُفرغ الـ queue
///   3. flush():
///      a. يكتب JSON محلياً في app data dir
///      b. يضغط إلى ZIP (أقل 60-80% من الحجم)
///      c. يرفع ZIP إلى Google Sheets (ملخص) + IPFS (أرشيف)
///      d. يحذف الملف المحلي
///
/// ملاحظة أداء:
///   • الـ queue تُحفظ في ذاكرة فقط (لا persistence بين الجلسات)
///   • للـ persistence بين الجلسات: أضف SharedPreferences queue بعد ذلك
class LogBatchService {
  static final LogBatchService _i = LogBatchService._();
  factory LogBatchService() => _i;
  LogBatchService._();

  static const Duration _flushInterval = Duration(minutes: 15);
  static const int      _maxQueueSize  = 500;   // حدّ الـ queue — تفريغ مبكر عند الامتلاء

  final _queue = <LogEntry>[];
  Timer?  _timer;
  bool    _flushing = false;
  String? _participantUid;

  final _sheets = SheetsLoggingService();
  final _ipfs   = IPFSService();

  // ── Setup ─────────────────────────────────────────────────────

  void setParticipantUid(String uid) => _participantUid = uid;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_flushInterval, (_) => flush());
    debugPrint('[LogBatch] Started — flushing every 15m');
  }

  void stop() {
    _timer?.cancel();
  }

  // ── Enqueue ───────────────────────────────────────────────────

  void enqueue(LogEntry entry) {
    _queue.add(entry);
    if (_queue.length >= _maxQueueSize) {
      debugPrint('[LogBatch] Queue full — triggering early flush');
      flush();
    }
  }

  void enqueueTelemetry({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    enqueue(LogEntry(
      type:  LogType.telemetry,
      uid:   uid,
      data:  data,
      ts:    DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void enqueueEvent({
    required String uid,
    required String event,
    String? details,
  }) {
    enqueue(LogEntry(
      type:  LogType.event,
      uid:   uid,
      data:  {'event': event, 'details': details},
      ts:    DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void enqueueCommand({
    required String leaderUid,
    required String targetUid,
    required String command,
    bool success = true,
  }) {
    enqueue(LogEntry(
      type: LogType.command,
      uid:  leaderUid,
      data: {
        'target':  targetUid,
        'command': command,
        'success': success,
      },
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  // ── Flush ─────────────────────────────────────────────────────

  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;

    final batch = List<LogEntry>.from(_queue);
    _queue.clear();

    debugPrint('[LogBatch] Flushing ${batch.length} entries…');

    try {
      // 1. تجميع الأحداث في JSON
      final json = jsonEncode(batch.map((e) => e.toJson()).toList());

      // 2. حفظ مؤقت في ملف محلي
      final tempFile = await _writeTempJson(json);

      // 3. ضغط إلى ZIP
      final zipFile = await _compressToZip(tempFile, batch.length);

      // 4. رفع إلى IPFS (أرشيف ضخم)
      await _uploadToIpfs(zipFile, batch.first.uid);

      // 5. إرسال ملخص إلى Sheets (صفوف خفيفة)
      await _pushSummaryToSheets(batch);

      // 6. تنظيف الملفات المحلية
      await _cleanup([tempFile, zipFile]);

      debugPrint('[LogBatch] ✓ Flushed ${batch.length} entries');
    } catch (e) {
      debugPrint('[LogBatch] Flush error: $e');
      // أعِد الإدخالات للـ queue إن فشل الإرسال
      _queue.insertAll(0, batch.take(_maxQueueSize ~/ 2));
    } finally {
      _flushing = false;
    }
  }

  // ── Internal ──────────────────────────────────────────────────

  Future<File> _writeTempJson(String json) async {
    final dir  = await getTemporaryDirectory();
    final ts   = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/log_batch_$ts.json');
    await file.writeAsString(json, encoding: utf8);
    return file;
  }

  Future<File> _compressToZip(File sourceFile, int entryCount) async {
    final dir     = await getTemporaryDirectory();
    final ts      = DateTime.now().millisecondsSinceEpoch;
    final zipPath = '${dir.path}/log_batch_$ts.zip';

    final archive  = Archive();
    final content  = await sourceFile.readAsBytes();
    archive.addFile(ArchiveFile(
      'log_batch_$ts.json',
      content.length,
      content,
    ));

    final zipData = ZipEncoder().encode(archive);
    final zipFile = File(zipPath)..writeAsBytesSync(zipData ?? []);

    final original = content.length;
    final compressed = zipFile.lengthSync();
    final ratio = original > 0
        ? ((1 - compressed / original) * 100).toStringAsFixed(0)
        : '0';

    debugPrint('[LogBatch] Compressed: $original → $compressed bytes ($ratio% saved)');
    return zipFile;
  }

  Future<void> _uploadToIpfs(File file, String uid) async {
    try {
      await _ipfs.uploadFile(
        participantUid: uid,
        file:           file,
        category:       IPFSFileCategory.activityLog,
        name:           'log_batch_${DateTime.now().toIso8601String()}.zip',
      );
    } catch (e) {
      debugPrint('[LogBatch] IPFS upload failed (non-critical): $e');
    }
  }

  Future<void> _pushSummaryToSheets(List<LogEntry> batch) async {
    // إرسال ملخص: عدد الأحداث لكل نوع
    final grouped = <String, int>{};
    for (final e in batch) grouped[e.type.name] = (grouped[e.type.name] ?? 0) + 1;

    final uid = _participantUid ?? batch.first.uid;
    await _sheets.logEvent(
      participantUid: uid,
      eventType:      'batch_flush',
      details:        grouped.entries.map((e) => '${e.key}:${e.value}').join(', '),
    );
  }

  Future<void> _cleanup(List<File> files) async {
    for (final f in files) {
      try { await f.delete(); } catch (_) {}
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

// ── Data Models ──────────────────────────────────────────────

enum LogType { telemetry, event, command, error }

class LogEntry {
  final LogType type;
  final String  uid;
  final Map<String, dynamic> data;
  final int     ts;

  const LogEntry({
    required this.type,
    required this.uid,
    required this.data,
    required this.ts,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'uid':  uid,
    'data': data,
    'ts':   ts,
  };
}
