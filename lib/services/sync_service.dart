import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'hive_blackbox_service.dart';

/// SyncService — خدمة المزامنة عند استعادة الاتصال
///
/// تستمع لتغيرات الشبكة عبر [connectivity_plus].
/// عند الاتصال بالإنترنت:
///   1. تُصدّر السجلات المعلقة كـ JSON مضغوط
///   2. ترفعها لـ Firestore (compliance_assets/{uid}/sync_dumps)
///   3. تُحدد السجلات كـ "مُرفوعة"
///   4. تُنظف السجلات القديمة
///
/// الاستخدام:
///   SyncService.instance.start(uid: uid);
class SyncService {
  SyncService._();
  static final instance = SyncService._();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  String _uid = '';

  // ── تشغيل الخدمة ─────────────────────────────────────────

  void start({required String uid}) {
    _uid = uid;
    _connectivitySub?.cancel();

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    // فحص فوري عند التشغيل
    _checkAndSync();
  }

  void stop() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  void updateUid(String uid) {
    _uid = uid;
  }

  // ── الاستجابة لتغير الاتصال ──────────────────────────────

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isConnected = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);

    if (isConnected) {
      _checkAndSync();
    }
  }

  // ── منطق المزامنة الأساسي ────────────────────────────────

  Future<void> _checkAndSync() async {
    if (_isSyncing || _uid.isEmpty) return;

    final pending = HiveBlackboxService.pendingLogs;
    if (pending == 0) return;

    _isSyncing = true;

    try {
      // تحقق من الاتصال الفعلي
      final result = await Connectivity().checkConnectivity();
      final isOnline = result.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);

      if (!isOnline) {
        _isSyncing = false;
        return;
      }

      // تصدير السجلات المعلقة
      final zipFile = await HiveBlackboxService.exportCompressedLogs(_uid);
      final keys = HiveBlackboxService.getPendingSyncKeys();

      // رفع الملف المضغوط لـ Firestore
      if (zipFile != null && zipFile.existsSync()) {
        final zipBytes = await zipFile.readAsBytes();
        final base64Zip = _bytesToBase64(zipBytes);

        await FirebaseFirestore.instance
            .collection('compliance_assets')
            .doc(_uid)
            .collection('sync_dumps')
            .add({
          'uid': _uid,
          'timestamp': FieldValue.serverTimestamp(),
          'logCount': pending,
          'compressedData': base64Zip,
          'sizeBytes': zipBytes.length,
          'source': 'hive_blackbox',
        });

        await zipFile.delete();
      }

      // تحديث حالة الجهاز
      await FirebaseFirestore.instance
          .collection('device_states')
          .doc(_uid)
          .update({
        'lastSyncAt': FieldValue.serverTimestamp(),
        'pendingLogsCount': 0,
      });

      // تحديد السجلات كمُرفوعة
      await HiveBlackboxService.markSynced(keys);

      // تنظيف السجلات القديمة
      await HiveBlackboxService.pruneOldSyncedLogs();

    } catch (e) {
      // فشل صامت — يُعاد المحاولة في الاتصال التالي
    } finally {
      _isSyncing = false;
    }
  }

  // ── إجبار على المزامنة ─────────────────────────────────

  Future<void> forceSync() async {
    _isSyncing = false; // إعادة تعيين قفل الانتظار
    await _checkAndSync();
  }

  // ── حالة الخدمة ──────────────────────────────────────────

  bool get isSyncing => _isSyncing;
  int get pendingCount => HiveBlackboxService.pendingLogs;

  // ── helpers ──────────────────────────────────────────────

  String _bytesToBase64(List<int> bytes) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      result.write(chars[(b0 >> 2) & 0x3F]);
      result.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      result.write(i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      result.write(i + 2 < bytes.length ? chars[b2 & 0x3F] : '=');
    }
    return result.toString();
  }
}
