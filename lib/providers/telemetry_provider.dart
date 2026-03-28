import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/live_telemetry_model.dart';
import '../models/device_state_model.dart';
import '../repositories/telemetry_repository.dart';
import '../services/mqtt_service.dart';

/// TelemetryProvider — يُغذّي واجهة القائد ببيانات الاستشعار الحية
///
/// يدمج مصدرين:
///   1. MQTT — بيانات عالية التردد (GPS, Battery, Screen)
///   2. RTDB — بيانات متوسطة التردد (Heartbeat, Job, Progress)
///
/// الاستخدام:
///   context.watch<TelemetryProvider>().getLiveTelemetry(uid)
///   context.watch<TelemetryProvider>().getRtdbState(uid)
///   context.watch<TelemetryProvider>().mqttStatus
class TelemetryProvider extends ChangeNotifier {
  final _repo = TelemetryRepository();

  // ── State ──────────────────────────────────────────────────────

  /// بيانات MQTT المدمجة لكل مشارك
  final Map<String, LiveTelemetryModel> _liveMap = {};

  /// بيانات RTDB لكل مشارك
  final Map<String, DeviceStateModel> _rtdbMap = {};

  MqttConnectionState _mqttStatus = MqttConnectionState.disconnected;
  bool _initialized = false;

  StreamSubscription? _mqttSub;
  StreamSubscription? _rtdbSub;
  final Map<String, StreamSubscription> _perParticipantRtdb = {};

  // ── Getters ───────────────────────────────────────────────────

  MqttConnectionState get mqttStatus => _mqttStatus;
  bool get isMqttConnected => _mqttStatus == MqttConnectionState.connected;
  bool get isInitialized => _initialized;

  /// بيانات MQTT للمشارك
  LiveTelemetryModel? getLiveTelemetry(String uid) => _liveMap[uid];

  /// بيانات RTDB للمشارك
  DeviceStateModel? getRtdbState(String uid) => _rtdbMap[uid];

  /// نبضة مدمجة: MQTT له أولوية، RTDB كـ fallback
  String computedPulse(String uid) {
    final live = _liveMap[uid];
    if (live != null) {
      final diff = DateTime.now().difference(live.timestamp);
      if (diff.inSeconds < 10)  return 'active';
      if (diff.inSeconds < 30)  return 'idle';
    }
    return _rtdbMap[uid]?.computedPulse ?? 'offline';
  }

  /// بطارية المشارك (أولوية MQTT ثم RTDB)
  int? batteryPercent(String uid) {
    final mqtt = _liveMap[uid]?.battery.percent;
    if (mqtt != null && mqtt >= 0) return mqtt;
    return _rtdbMap[uid]?.batteryPct;
  }

  /// حالة الشاشة
  bool? screenActive(String uid) {
    final mqtt = _liveMap[uid]?.screenActive;
    if (mqtt != null) return mqtt;
    return _rtdbMap[uid]?.screenActive;
  }

  /// تقدم المهمة (RTDB)
  double? taskProgress(String uid) => _rtdbMap[uid]?.taskProgress;

  /// المهمة الحالية (RTDB)
  String? currentJob(String uid) => _rtdbMap[uid]?.currentJob;

  /// موقع GPS (MQTT فقط)
  GpsPoint? gps(String uid) => _liveMap[uid]?.gps;

  /// جودة الاتصال (RTDB)
  String? connectionQuality(String uid) => _rtdbMap[uid]?.connectionQuality;

  /// قائمة UIDs النشطة عبر MQTT
  List<String> get activeMqttUids => _liveMap.keys.toList();

  /// عدد المشاركين النشطين
  int get activeCount =>
      _rtdbMap.values.where((s) => s.computedPulse == 'active').length;

  // ── Leader Initialization ─────────────────────────────────────

  /// يُستدعى بعد تسجيل دخول القائد
  Future<void> initForLeader(String leaderUid) async {
    if (_initialized) return;
    _initialized = true;

    // مراقبة حالة اتصال MQTT
    _mqttSub = _repo.mqttConnectionStream.listen((state) {
      _mqttStatus = state;
      notifyListeners();
    });

    // بدء الاستماع (MQTT + RTDB)
    await _repo.startSubscribing(leaderUid);

    // الاستماع للحزم المدمجة من Repository
    _rtdbSub = _repo.allParticipantsStream.listen((map) {
      _liveMap
        ..clear()
        ..addAll(map);
      notifyListeners();
    });

    debugPrint('[TelemetryProvider] Leader initialized: $leaderUid');
  }

  /// مراقبة مشارك بعينه عبر RTDB (للقائد)
  void watchParticipantRtdb(String uid) {
    if (_perParticipantRtdb.containsKey(uid)) return;
    _perParticipantRtdb[uid] = _repo.watchParticipant(uid).listen((state) {
      _rtdbMap[uid] = state;
      notifyListeners();
    });
  }

  void stopWatchingParticipant(String uid) {
    _perParticipantRtdb[uid]?.cancel();
    _perParticipantRtdb.remove(uid);
  }

  // ── Participant Initialization ────────────────────────────────

  /// يُستدعى بعد تسجيل دخول المشارك
  Future<void> initForParticipant(String uid) async {
    if (_initialized) return;
    _initialized = true;

    // مراقبة حالة اتصال MQTT
    _mqttSub = _repo.mqttConnectionStream.listen((state) {
      _mqttStatus = state;
      notifyListeners();
    });

    // بدء النشر
    await _repo.startPublishing(uid);
    debugPrint('[TelemetryProvider] Participant initialized: $uid');
  }

  // ── Leader Commands ───────────────────────────────────────────

  /// إرسال أمر عبر RTDB (للقائد)
  Future<void> sendCommand(String uid, String command,
      [Map<String, dynamic>? payload]) =>
      _repo.sendRtdbCommand(uid, command, payload);

  // ── Cleanup ───────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    _mqttSub?.cancel();
    _rtdbSub?.cancel();
    for (final sub in _perParticipantRtdb.values) sub.cancel();
    await _repo.dispose();
    super.dispose();
  }
}
