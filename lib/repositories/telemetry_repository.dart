import 'dart:async';
import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/live_telemetry_model.dart';
import '../models/device_state_model.dart';
import '../services/mqtt_service.dart';
import '../services/rtdb_service.dart';

/// TelemetryRepository — يدمج MQTT + RTDB في واجهة واحدة
///
/// مسؤوليات المشارك (publishMode):
///   • يجمع GPS + Battery + Screen State من الجهاز
///   • يُرسل GPS/Battery/Screen عبر MQTT كل 5/10 ثوانٍ
///   • يُرسل Heartbeat إلى RTDB كل 30 ثانية
///   • يُسجّل onDisconnect في RTDB
///
/// مسؤوليات القائد (subscribeMode):
///   • يشترك في MQTT لاستقبال البيانات اللحظية
///   • يفتح Stream من RTDB لكل المشاركين
///   • يدمج المصدرين في Map<uid, LiveTelemetryModel>
class TelemetryRepository {
  // ── Singleton ─────────────────────────────────────────────────
  static final TelemetryRepository _instance = TelemetryRepository._();
  factory TelemetryRepository() => _instance;
  TelemetryRepository._();

  final _mqtt = MqttService();
  final _rtdb = RtdbService();
  final _battery = Battery();

  // ── Internal State ────────────────────────────────────────────
  final Map<String, Map<String, dynamic>> _mqttPayloads = {};
  final Map<String, LiveTelemetryModel> _merged = {};
  final _mergedCtrl = StreamController<Map<String, LiveTelemetryModel>>.broadcast();

  StreamSubscription? _mqttSub;
  StreamSubscription? _rtdbSub;
  Timer? _gpsTimer;
  Timer? _batteryTimer;
  Timer? _heartbeatTimer;

  String? _participantUid;
  bool _publishMode = false;

  // ── Public Streams ────────────────────────────────────────────

  Stream<Map<String, LiveTelemetryModel>> get allParticipantsStream =>
      _mergedCtrl.stream;

  Stream<MqttConnectionState> get mqttConnectionStream =>
      _mqtt.connectionStream;

  // ── Participant Mode ──────────────────────────────────────────

  /// تهيئة وضع النشر — يُستدعى من ParticipantHomeScreen بعد تسجيل الدخول
  Future<void> startPublishing(String uid) async {
    if (_publishMode && _participantUid == uid) return;
    _participantUid = uid;
    _publishMode = true;

    // 1. اتصال MQTT
    await _mqtt.connect(uid: uid, isLeader: false);

    // 2. RTDB: تسجيل onDisconnect
    _rtdb.setOnDisconnect(uid);

    // 3. بدء loops
    _startGpsLoop(uid);
    _startBatteryLoop(uid);
    _startHeartbeatLoop(uid);

    debugPrint('[TelemetryRepo] Participant publishing started for $uid');
  }

  Future<void> stopPublishing() async {
    _publishMode = false;
    _gpsTimer?.cancel();
    _batteryTimer?.cancel();
    _heartbeatTimer?.cancel();
    if (_participantUid != null) {
      _rtdb.cancelOnDisconnect(_participantUid!);
      await _rtdb.heartbeat(_participantUid!, 'offline');
    }
    await _mqtt.disconnect();
    debugPrint('[TelemetryRepo] Publishing stopped');
  }

  // ── GPS Publishing Loop ───────────────────────────────────────

  void _startGpsLoop(String uid) {
    _gpsTimer?.cancel();
    _gpsLoop(uid); // publish immediately
    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) => _gpsLoop(uid));
  }

  Future<void> _gpsLoop(String uid) async {
    try {
      final gps = await _collectGps();
      if (gps != null) {
        _mqtt.publishGps(uid, gps);
      }
    } catch (e) {
      debugPrint('[TelemetryRepo] GPS loop error: $e');
    }
  }

  // ── Battery Publishing Loop ───────────────────────────────────

  void _startBatteryLoop(String uid) {
    _batteryTimer?.cancel();
    _batteryLoop(uid);
    _batteryTimer = Timer.periodic(const Duration(seconds: 10), (_) => _batteryLoop(uid));
  }

  Future<void> _batteryLoop(String uid) async {
    try {
      final snap = await _collectBattery();
      _mqtt.publishBattery(uid, snap);

      // الشاشة — نشر عبر MQTT + RTDB
      final screenActive = snap.percent > 0; // تقريب: البطارية تتصاعد = شاشة نشطة
      _mqtt.publishScreen(uid, screenActive);

      // RTDB: تحديث نبضة البطارية
      await _rtdb.updateField(uid, 'batteryPct', snap.percent);
      await _rtdb.updateField(uid, 'batteryCharging', snap.isCharging);
    } catch (e) {
      debugPrint('[TelemetryRepo] Battery loop error: $e');
    }
  }

  // ── RTDB Heartbeat Loop ───────────────────────────────────────

  void _startHeartbeatLoop(String uid) {
    _heartbeatTimer?.cancel();
    _heartbeatLoop(uid);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) => _heartbeatLoop(uid));
  }

  Future<void> _heartbeatLoop(String uid) async {
    try {
      await _rtdb.heartbeat(uid, 'active');
      _mqtt.publishPulse(uid, 'active');
    } catch (e) {
      debugPrint('[TelemetryRepo] Heartbeat error: $e');
    }
  }

  // ── Participant RTDB State Push ───────────────────────────────

  /// الخدمة الأمامية Kotlin تستدعي هذا عبر MethodChannel
  /// لدفع البيانات التي لا تتوفر في Dart (Admin Shield, Accessibility...)
  Future<void> pushKotlinState(String uid, Map<String, dynamic> data) async {
    await _rtdb.updateParticipantState(
      uid: uid,
      state: DeviceStateModel.fromRtdb(uid, data),
    );
  }

  // ── Leader Mode ───────────────────────────────────────────────

  /// تهيئة وضع الاشتراك للقائد
  Future<void> startSubscribing(String leaderUid) async {
    // 1. اتصال MQTT + اشتراك
    await _mqtt.connect(uid: leaderUid, isLeader: true);

    // 2. الاستماع لحزم MQTT
    _mqttSub = _mqtt.telemetryStream.listen(_onMqttPacket);

    // 3. Stream RTDB لجميع المشاركين
    _rtdbSub = _rtdb.watchAll().listen(_onRtdbUpdate);

    debugPrint('[TelemetryRepo] Leader subscribing started');
  }

  Future<void> stopSubscribing() async {
    _mqttSub?.cancel();
    _rtdbSub?.cancel();
    await _mqtt.disconnect();
    debugPrint('[TelemetryRepo] Leader subscribing stopped');
  }

  // ── MQTT Packet Handler ───────────────────────────────────────

  void _onMqttPacket(MqttTelemetryPacket packet) {
    final uid = packet.uid;
    _mqttPayloads[uid] ??= {};
    _mqttPayloads[uid]![packet.metric] = packet.payload;

    // بناء LiveTelemetryModel من الحزم المجمَّعة
    final payloads = _mqttPayloads[uid]!;
    final model = LiveTelemetryModel.fromMqttPayloads(
      uid: uid,
      gpsPayload: payloads['gps'] as Map<String, dynamic>?,
      batteryPayload: payloads['battery'] as Map<String, dynamic>?,
      screenPayload: payloads['screen'] as Map<String, dynamic>?,
    );

    _merged[uid] = model;
    _mergedCtrl.add(Map.from(_merged));
  }

  // ── RTDB Update Handler ───────────────────────────────────────

  void _onRtdbUpdate(Map<String, DeviceStateModel> states) {
    for (final entry in states.entries) {
      final uid = entry.key;
      final state = entry.value;

      // دمج RTDB مع بيانات MQTT الموجودة
      final existing = _merged[uid];
      if (existing != null) {
        // MQTT له أولوية — نُحدّث فقط ما لا يوجد في MQTT
        _merged[uid] = existing.copyWith(
          battery: state.batteryPct != null && existing.battery.percent < 0
              ? BatterySnapshot(
                  percent: state.batteryPct!,
                  isCharging: state.batteryCharging ?? false,
                  health: 'unknown',
                )
              : null,
          screenActive: existing.screenActive == false && state.screenActive != null
              ? state.screenActive
              : null,
        );
      } else {
        // لا يوجد بيانات MQTT بعد — استخدم RTDB كـ fallback
        _merged[uid] = LiveTelemetryModel(
          uid: uid,
          battery: BatterySnapshot(
            percent: state.batteryPct ?? -1,
            isCharging: state.batteryCharging ?? false,
            health: 'unknown',
          ),
          screenActive: state.screenActive ?? false,
          timestamp: state.lastSeen ?? DateTime.now(),
        );
      }
    }
    _mergedCtrl.add(Map.from(_merged));
  }

  // ── Device Sensor Helpers ─────────────────────────────────────

  Future<GpsPoint?> _collectGps() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
      return GpsPoint(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        speed: pos.speed,
      );
    } catch (e) {
      debugPrint('[TelemetryRepo] GPS error: $e');
      return null;
    }
  }

  Future<BatterySnapshot> _collectBattery() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      return BatterySnapshot(
        percent: level,
        isCharging: state == BatteryState.charging || state == BatteryState.full,
        health: 'good',
      );
    } catch (e) {
      debugPrint('[TelemetryRepo] Battery error: $e');
      return BatterySnapshot.unknown;
    }
  }

  // ── Leader: Watch Single Participant RTDB ────────────────────

  Stream<DeviceStateModel> watchParticipant(String uid) =>
      _rtdb.watchParticipant(uid);

  // ── Leader: Send Command via RTDB ────────────────────────────

  Future<void> sendRtdbCommand(String uid, String command,
      [Map<String, dynamic>? payload]) =>
      _rtdb.pushCommand(uid, command: command, payload: payload);

  // ── Cleanup ───────────────────────────────────────────────────

  Future<void> dispose() async {
    await stopPublishing();
    await stopSubscribing();
    _mergedCtrl.close();
  }
}
