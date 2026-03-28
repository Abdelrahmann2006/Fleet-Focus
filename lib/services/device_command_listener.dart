import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_state_service.dart';
import 'focus_service.dart';
import 'permission_service.dart';

/// DeviceCommandListener
///
/// يعمل على جهاز المشارك — يستمع لمستند device_commands/{uid}
/// ويُنفّذ الأوامر الواردة من القائد فور وصولها.
///
/// الاستخدام:
///   DeviceCommandListener.start(uid);   ← في initState أو AuthProvider
///   DeviceCommandListener.stop();       ← عند تسجيل الخروج

class DeviceCommandListener {
  static const _systemChannel =
      MethodChannel('com.competition.app/system_control');

  static Stream<DocumentSnapshot>? _stream;
  static bool _running = false;

  // ──────────────────────────────────────────────────────────
  //  بدء الاستماع
  // ──────────────────────────────────────────────────────────

  static void start(String uid) {
    if (_running) return;
    _running = true;

    _stream = DeviceStateService.watchCommands(uid);
    _stream!.listen((snap) async {
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      final acknowledged = data['acknowledged'] as bool? ?? true;
      if (acknowledged) return; // أمر سبق تنفيذه

      final command = data['command'] as String? ?? '';
      final payload = data['payload'] as Map<String, dynamic>? ?? {};

      debugPrint('DeviceCommandListener: ← أمر وارد "$command"');

      await _execute(command, payload);
      await DeviceStateService.acknowledgeCommand(uid);

      // أبلغ السيرفر بحالة الصلاحيات بعد التنفيذ
      await _reportPermissions(uid);
    });

    // إبلاغ أولي عند بدء الاستماع
    _reportPermissions(uid);
  }

  static void stop() {
    _running = false;
    _stream = null;
  }

  // ──────────────────────────────────────────────────────────
  //  تنفيذ الأوامر
  // ──────────────────────────────────────────────────────────

  static Future<void> _execute(
    String command,
    Map<String, dynamic> payload,
  ) async {
    switch (command) {

      case DeviceCommand.enableKiosk:
        await _enableKiosk();

      case DeviceCommand.disableKiosk:
        await _disableKiosk();

      case DeviceCommand.updateBlockedApps:
        final packages = List<String>.from(payload['packages'] ?? []);
        await FocusService.updateBlockedApps(packages);

      case DeviceCommand.lockScreen:
        await _lockScreen();

      default:
        debugPrint('DeviceCommandListener: أمر غير معروف "$command"');
    }
  }

  // ── تفعيل Kiosk ─────────────────────────────────────────

  static Future<void> _enableKiosk() async {
    // 1. تفعيل قائمة الحجب الكاملة
    await FocusService.updateBlockedApps(_allKioskBlockList);
    debugPrint('DeviceCommandListener: ✓ Kiosk mode مُفعَّل');
  }

  // ── تعطيل Kiosk ─────────────────────────────────────────

  static Future<void> _disableKiosk() async {
    // استعادة قائمة الحجب الافتراضية
    await FocusService.updateBlockedApps(FocusService.defaultBlockedApps);
    debugPrint('DeviceCommandListener: ✓ Kiosk mode مُعطَّل');
  }

  // ── قفل الشاشة ───────────────────────────────────────────

  static Future<void> _lockScreen() async {
    try {
      await _systemChannel.invokeMethod('lockScreen');
      debugPrint('DeviceCommandListener: ✓ الشاشة مُقفَلة');
    } on PlatformException catch (e) {
      debugPrint('DeviceCommandListener: ✗ قفل الشاشة فشل: ${e.message}');
    }
  }

  // ── رفع حالة الصلاحيات ──────────────────────────────────

  static Future<void> _reportPermissions(String uid) async {
    if (kIsWeb) return; // الصلاحيات خاصة بالموبايل
    try {
      final perms = await PermissionService.getAllPermissionsStatus();
      await DeviceStateService.reportDeviceState(uid, permissions: perms);
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────
  //  قائمة التطبيقات المحجوبة في وضع Kiosk الكامل
  // ──────────────────────────────────────────────────────────

  static const List<String> _allKioskBlockList = [
    'com.instagram.android',
    'com.twitter.android',
    'com.facebook.katana',
    'com.snapchat.android',
    'com.zhiliaoapp.musically',
    'com.tiktok.android',
    'com.youtube.android',
    'com.google.android.youtube',
    'com.reddit.frontpage',
    'com.linkedin.android',
    'com.pinterest',
    'com.telegram.messenger',
    'org.telegram.messenger',
    'com.whatsapp',
    'com.google.android.apps.messaging',
    'com.samsung.android.messaging',
  ];
}
