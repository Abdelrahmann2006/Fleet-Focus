import 'package:flutter/services.dart';

/// PermissionService — يتواصل مع الكود النيتف عبر MethodChannel
/// يتحقق برمجياً من حالة:
///  - Device Admin
///  - Accessibility Service
///  - Draw Over Apps (Overlay)
///  - Battery Optimization exemption
///  - Wireless Debugging (ADB)
class PermissionService {
  static const MethodChannel _channel =
      MethodChannel('com.competition.app/permissions');

  /// تحقق من تفعيل مشرف الجهاز
  static Future<bool> isDeviceAdminActive() async {
    try {
      final bool result = await _channel.invokeMethod('isDeviceAdminActive');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// تحقق من تفعيل خدمة إمكانية الوصول
  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool result =
          await _channel.invokeMethod('isAccessibilityServiceEnabled');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// تحقق من إذن الرسم فوق التطبيقات
  static Future<bool> canDrawOverApps() async {
    try {
      final bool result = await _channel.invokeMethod('canDrawOverApps');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// تحقق من إعفاء تحسين البطارية
  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final bool result =
          await _channel.invokeMethod('isBatteryOptimizationIgnored');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// فتح إعدادات مشرف الجهاز
  static Future<void> openDeviceAdminSettings() async {
    try {
      await _channel.invokeMethod('openDeviceAdminSettings');
    } on PlatformException catch (e) {
      throw Exception('Failed to open device admin: ${e.message}');
    }
  }

  /// فتح إعدادات إمكانية الوصول
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      throw Exception('Failed to open accessibility: ${e.message}');
    }
  }

  /// فتح إعدادات الرسم فوق التطبيقات
  static Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } on PlatformException catch (e) {
      throw Exception('Failed to open overlay settings: ${e.message}');
    }
  }

  /// فتح إعدادات استثناء البطارية
  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } on PlatformException catch (e) {
      throw Exception('Failed to open battery settings: ${e.message}');
    }
  }

  /// فتح خيارات المطور للـ Wireless Debugging
  static Future<void> openDeveloperOptions() async {
    try {
      await _channel.invokeMethod('openDeveloperOptions');
    } on PlatformException catch (e) {
      throw Exception('Failed to open developer options: ${e.message}');
    }
  }

  /// فتح تفاصيل التطبيق (لـ "Allow restricted settings")
  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } on PlatformException catch (e) {
      throw Exception('Failed to open app settings: ${e.message}');
    }
  }

  // ─── التطبيق الافتراضي للـ SMS ─────────────────────────────

  /// هل التطبيق هو تطبيق الرسائل الافتراضي؟
  static Future<bool> isDefaultSmsApp() async {
    try {
      return await _channel.invokeMethod('isDefaultSmsApp') as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// طلب التعيين كتطبيق الرسائل الافتراضي (يفتح حوار Android)
  static Future<void> requestDefaultSmsApp() async {
    try {
      await _channel.invokeMethod('requestDefaultSmsApp');
    } on PlatformException catch (e) {
      throw Exception('Failed to request default SMS: ${e.message}');
    }
  }

  // ─── التطبيق الافتراضي للهاتف ───────────────────────────────

  /// هل التطبيق هو تطبيق الهاتف الافتراضي (Dialer)؟
  static Future<bool> isDefaultPhoneApp() async {
    try {
      return await _channel.invokeMethod('isDefaultPhoneApp') as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// طلب التعيين كتطبيق الهاتف الافتراضي (يفتح حوار Android)
  static Future<void> requestDefaultPhoneApp() async {
    try {
      await _channel.invokeMethod('requestDefaultPhoneApp');
    } on PlatformException catch (e) {
      throw Exception('Failed to request default phone: ${e.message}');
    }
  }

  /// الحصول على حالة جميع الصلاحيات دفعة واحدة
  static Future<Map<String, bool>> getAllPermissionsStatus() async {
    try {
      final Map<Object?, Object?> result =
          await _channel.invokeMethod('getAllPermissionsStatus');
      return result.map((k, v) => MapEntry(k.toString(), v as bool));
    } on PlatformException {
      return {
        'deviceAdmin':       false,
        'accessibility':     false,
        'overlay':           false,
        'batteryOptimization': false,
        'defaultSmsApp':     false,
        'defaultPhoneApp':   false,
      };
    }
  }

  /// هل التطبيق Device Owner حالياً؟
  static Future<bool> isDeviceOwnerApp() async {
    try {
      return await _channel.invokeMethod('isDeviceOwnerApp') as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// قائمة حسابات Google الموجودة على الجهاز
  static Future<List<String>> getGoogleAccounts() async {
    try {
      final List<Object?> result =
          await _channel.invokeMethod('getGoogleAccounts');
      return result.whereType<String>().toList();
    } on PlatformException {
      return [];
    }
  }

  /// فتح إعدادات الحسابات
  static Future<void> openSyncSettings() async {
    try {
      await _channel.invokeMethod('openSyncSettings');
    } on PlatformException {
      // تجاهل
    }
  }
}
