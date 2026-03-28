import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// RedOverlayService — خدمة الطبقة الحمراء العقابية
///
/// تستخدم SYSTEM_ALERT_WINDOW لرسم طبقة حمراء فوق جميع التطبيقات.
/// تُفعَّل عبر MethodChannel 'panopticon/red_overlay'.
///
/// المتطلب: تفعيل "الرسم فوق التطبيقات الأخرى" من الإعدادات.
class RedOverlayService {
  static const _channel = MethodChannel('panopticon/red_overlay');

  /// عرض الطبقة الحمراء فوق جميع التطبيقات
  ///
  /// [message]: الرسالة العقابية المعروضة في منتصف الشاشة
  static Future<void> show({
    String message = 'انتهاك مرصود — خرق قواعد النظام',
  }) async {
    try {
      await _channel.invokeMethod('showRedOverlay', {'message': message});
    } on PlatformException catch (e) {
      debugPrint('[RedOverlay] show error: ${e.message}');
    } catch (e) {
      debugPrint('[RedOverlay] show exception: $e');
    }
  }

  /// إخفاء الطبقة الحمراء
  static Future<void> hide() async {
    try {
      await _channel.invokeMethod('hideRedOverlay');
    } on PlatformException catch (e) {
      debugPrint('[RedOverlay] hide error: ${e.message}');
    } catch (e) {
      debugPrint('[RedOverlay] hide exception: $e');
    }
  }
}
