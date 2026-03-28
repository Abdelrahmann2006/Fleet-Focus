import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

/// HiveBlackboxService — الصندوق الأسود المحلي
///
/// يُخزّن سجلات الامتثال محلياً عبر Hive عندما يكون الجهاز غير متصل.
/// تُستخدم هذه السجلات بواسطة [SyncService] لرفعها فور استعادة الاتصال.
///
/// Box المستخدم: "blackbox_logs"
/// كل سجل:
///   { "type": string, "data": Map, "timestamp": int, "uid": string }
class HiveBlackboxService {
  static const String _boxName = 'blackbox_logs';
  static const String _metaBoxName = 'blackbox_meta';

  static Box<Map>? _box;
  static Box<dynamic>? _metaBox;

  // ── تهيئة الخدمة ─────────────────────────────────────────

  /// يجب استدعاؤه مرة واحدة في [main()] بعد Hive.initFlutter()
  static Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<Map>(_boxName);
    _metaBox = await Hive.openBox(_metaBoxName);
  }

  // ── كتابة سجل جديد ───────────────────────────────────────

  /// يُضيف سجلاً جديداً للصندوق الأسود
  static Future<void> log({
    required String type,
    required Map<String, dynamic> data,
    required String uid,
  }) async {
    await _ensureOpen();
    final entry = {
      'type': type,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'uid': uid,
      'synced': false,
    };
    await _box!.add(entry);
  }

  // ── استرجاع السجلات غير المُرفوعة ───────────────────────

  static List<Map> getPendingSyncLogs() {
    _ensureOpenSync();
    return _box!.values
        .where((entry) => entry['synced'] != true)
        .cast<Map>()
        .toList();
  }

  static List<dynamic> getPendingSyncKeys() {
    _ensureOpenSync();
    return _box!.keys
        .where((k) => _box!.get(k)?['synced'] != true)
        .toList();
  }

  // ── تحديد السجلات كـ "مُرفوعة" ──────────────────────────

  static Future<void> markSynced(List<dynamic> keys) async {
    await _ensureOpen();
    for (final key in keys) {
      final entry = Map.from(_box!.get(key) ?? {});
      entry['synced'] = true;
      await _box!.put(key, entry);
    }
  }

  // ── تصدير السجلات كـ JSON مضغوط ─────────────────────────

  /// يُنشئ ملف ZIP يحتوي JSON لكل السجلات المعلقة
  /// يُستخدم لرفعها لـ Telegram/IPFS
  static Future<File?> exportCompressedLogs(String uid) async {
    await _ensureOpen();
    final pending = getPendingSyncLogs();
    if (pending.isEmpty) return null;

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final jsonFile = File('${dir.path}/blackbox_${uid}_$timestamp.json');
      final zipFile = File('${dir.path}/blackbox_${uid}_$timestamp.zip');

      // كتابة JSON
      final jsonContent = jsonEncode({
        'uid': uid,
        'exportedAt': timestamp,
        'totalLogs': pending.length,
        'logs': pending,
      });
      await jsonFile.writeAsString(jsonContent);

      // ضغط ZIP
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFile(jsonFile);
      encoder.close();

      // حذف الملف المؤقت
      await jsonFile.delete();

      return zipFile;
    } catch (e) {
      return null;
    }
  }

  // ── إحصاءات ─────────────────────────────────────────────

  static int get totalLogs => _box?.length ?? 0;

  static int get pendingLogs =>
      _box?.values.where((e) => e['synced'] != true).length ?? 0;

  static int get syncedLogs =>
      _box?.values.where((e) => e['synced'] == true).length ?? 0;

  /// حذف السجلات المُرفوعة منذ أكثر من 7 أيام
  static Future<void> pruneOldSyncedLogs() async {
    await _ensureOpen();
    final sevenDaysAgo =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;

    final keysToDelete = _box!.keys.where((k) {
      final entry = _box!.get(k);
      if (entry == null) return false;
      final isSynced = entry['synced'] == true;
      final ts = entry['timestamp'] as int? ?? 0;
      return isSynced && ts < sevenDaysAgo;
    }).toList();

    await _box!.deleteAll(keysToDelete);
  }

  // ── helpers ──────────────────────────────────────────────

  static Future<void> _ensureOpen() async {
    if (_box == null || !_box!.isOpen) await init();
  }

  static void _ensureOpenSync() {
    if (_box == null || !_box!.isOpen) {
      throw StateError('HiveBlackboxService غير مُهيَّأ — استدعِ init() أولاً');
    }
  }
}
