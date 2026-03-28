import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// FocusService — يستقبل أحداث إنفاذ التركيز من MyAccessibilityService
///
/// الأحداث المُستقبَلة من Kotlin:
///  • app_blocked      → تطبيق مقيَّد حاول الفتح وتم حجبه
///  • split_screen_blocked → محاولة Split-Screen/PiP تم إغلاقها
///
/// الأوامر المُرسَلة لـ Kotlin:
///  • updateBlockedApps → تحديث قائمة التطبيقات المحجوبة

class FocusService {
  static const _channel = MethodChannel('com.competition.app/focus_events');

  static FocusService? _instance;
  static FocusService get instance => _instance ??= FocusService._();
  FocusService._();

  // مستمعو الأحداث
  final _blockListeners       = <void Function(String packageName)>[];
  final _splitScreenListeners = <void Function()>[];

  bool _initialized = false;

  // ──────────────────────────────────────────────────────────
  //  تهيئة الاستماع (يُستدعى مرة واحدة في main.dart أو initState)
  // ──────────────────────────────────────────────────────────

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {

        case 'app_blocked':
          final pkg = (call.arguments as Map?)?['blockedPackage'] ?? 'unknown';
          final ts  = (call.arguments as Map?)?['timestamp']      ?? 0;
          debugPrint('FocusService: ⛔ حجب $pkg في $ts');
          for (final fn in _blockListeners) {
            fn(pkg as String);
          }

        case 'split_screen_blocked':
          debugPrint('FocusService: ⛔ Split-Screen/PiP تم إغلاقه');
          for (final fn in _splitScreenListeners) {
            fn();
          }

        default:
          debugPrint('FocusService: حدث غير معروف: ${call.method}');
      }
    });
  }

  // ──────────────────────────────────────────────────────────
  //  تسجيل مستمعين
  // ──────────────────────────────────────────────────────────

  /// يُستدعى عند حجب تطبيق مقيَّد — يُمرَّر اسم الحزمة
  void onAppBlocked(void Function(String packageName) listener) {
    _blockListeners.add(listener);
  }

  /// يُستدعى عند إغلاق Split-Screen أو PiP
  void onSplitScreenBlocked(void Function() listener) {
    _splitScreenListeners.add(listener);
  }

  void removeAppBlockedListener(void Function(String) listener) {
    _blockListeners.remove(listener);
  }

  void removeSplitScreenListener(void Function() listener) {
    _splitScreenListeners.remove(listener);
  }

  // ──────────────────────────────────────────────────────────
  //  تحديث قائمة التطبيقات المحجوبة
  // ──────────────────────────────────────────────────────────

  /// يُرسل قائمة محدَّثة من package names لـ Kotlin
  /// مثال: ['com.instagram.android', 'com.twitter.android']
  static Future<bool> updateBlockedApps(List<String> packages) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'updateBlockedApps',
        {'packages': packages},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('FocusService.updateBlockedApps: ${e.message}');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  //  قوائم التطبيقات الجاهزة
  // ──────────────────────────────────────────────────────────

  /// التطبيقات الافتراضية المحجوبة (تتطابق مع DEFAULT_BLOCKED_APPS في Kotlin)
  static const List<String> defaultBlockedApps = [
    'com.instagram.android',
    'com.twitter.android',
    'com.facebook.katana',
    'com.snapchat.android',
    'com.zhiliaoapp.musically',
    'com.tiktok.android',
  ];

  /// أسماء عرض مقروءة لكل حزمة
  static const Map<String, String> packageDisplayNames = {
    'com.instagram.android':    'Instagram',
    'com.twitter.android':      'Twitter / X',
    'com.facebook.katana':      'Facebook',
    'com.snapchat.android':     'Snapchat',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.tiktok.android':       'TikTok',
    'com.youtube.android':      'YouTube',
    'com.google.android.youtube': 'YouTube',
    'com.reddit.frontpage':     'Reddit',
  };

  static String displayName(String package_) =>
      packageDisplayNames[package_] ?? package_;
}
