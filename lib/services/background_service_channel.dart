import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// BackgroundServiceChannel
///
/// واجهة Dart للتواصل مع CommandListenerService (Kotlin Foreground Service).
/// تستدعي القناة الأصيلة لتشغيل/إيقاف الخدمة في الخلفية.
///
/// الاستخدام:
///   await BackgroundServiceChannel.start(uid: 'firebase-uid');
///   await BackgroundServiceChannel.stop();
class BackgroundServiceChannel {
  static const _channel = MethodChannel(
    'com.competition.app/background_service',
  );

  /// يُشغّل CommandListenerService كـ Foreground Service.
  /// يُخزّن [uid] في SharedPreferences للإعادة التلقائية بعد الإيقاف.
  static Future<bool> start({required String uid}) async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'startListenerService',
        {'uid': uid},
      );
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('BackgroundServiceChannel.start خطأ: ${e.message}');
      return false;
    }
  }

  /// يوقف CommandListenerService ويمسح UID المحفوظ.
  static Future<bool> stop() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('stopListenerService');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('BackgroundServiceChannel.stop خطأ: ${e.message}');
      return false;
    }
  }
}
