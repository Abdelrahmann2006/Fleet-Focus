import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// NativeServiceChannel — جسر MethodChannel بين Flutter وخدمات Kotlin
///
/// يُمكّن Flutter من:
///  • تشغيل/إيقاف CommandListenerService
///  • تشغيل/إيقاف TelemetryPublisherService
///  • الاستعلام عن حالة الخدمات
class NativeServiceChannel {
  static const MethodChannel _channel =
      MethodChannel('com.abdelrahman.panopticon/services');

  static final NativeServiceChannel _instance = NativeServiceChannel._();
  factory NativeServiceChannel() => _instance;
  NativeServiceChannel._();

  // ── CommandListenerService ────────────────────────────────────

  Future<void> startCommandListener(String uid) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('startCommandListener', {'uid': uid});
      debugPrint('[NativeChannel] CommandListenerService started');
    } catch (e) {
      debugPrint('[NativeChannel] startCommandListener error: $e');
    }
  }

  Future<void> stopCommandListener() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('stopCommandListener');
    } catch (e) {
      debugPrint('[NativeChannel] stopCommandListener error: $e');
    }
  }

  // ── TelemetryPublisherService ─────────────────────────────────

  Future<void> startTelemetryPublisher(String uid) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('startTelemetryPublisher', {'uid': uid});
      debugPrint('[NativeChannel] TelemetryPublisherService started');
    } catch (e) {
      debugPrint('[NativeChannel] startTelemetryPublisher error: $e');
    }
  }

  Future<void> stopTelemetryPublisher() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('stopTelemetryPublisher');
    } catch (e) {
      debugPrint('[NativeChannel] stopTelemetryPublisher error: $e');
    }
  }

  // ── تشغيل كلا الخدمتين ───────────────────────────────────────

  Future<void> startAllServices(String uid) async {
    await startCommandListener(uid);
    await startTelemetryPublisher(uid);
  }

  Future<void> stopAllServices() async {
    await stopCommandListener();
    await stopTelemetryPublisher();
  }

  // ── استعلام حالة الصلاحيات ───────────────────────────────────

  Future<Map<String, bool>> queryPermissions() async {
    if (kIsWeb) {
      return {
        'deviceAdmin': false,
        'accessibility': false,
        'overlay': false,
        'batteryOptimization': false,
      };
    }
    try {
      final result = await _channel.invokeMapMethod<String, bool>('queryPermissions');
      return result ?? {};
    } catch (e) {
      debugPrint('[NativeChannel] queryPermissions error: $e');
      return {};
    }
  }
}
