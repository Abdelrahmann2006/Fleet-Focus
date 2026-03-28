import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/live_telemetry_model.dart';
import '../utils/encryption_util.dart';

/// حالة اتصال MQTT
enum MqttConnectionState { disconnected, connecting, connected, error }

/// حزمة بيانات استشعار واردة من MQTT (بعد فك التشفير)
class MqttTelemetryPacket {
  final String uid;
  final String metric;       // 'gps' | 'battery' | 'screen' | 'pulse'
  final Map<String, dynamic> payload;
  final DateTime receivedAt;

  const MqttTelemetryPacket({
    required this.uid,
    required this.metric,
    required this.payload,
    required this.receivedAt,
  });
}

/// MqttService — عميل MQTT موحَّد مع تشفير AES-256-CBC كامل
///
/// ┌─────────────────────────────────────────────────────────────────┐
/// │  طبقة الأمان                                                   │
/// │                                                                 │
/// │  HiveMQ Public Broker → يمكن لأي شخص الاشتراك في المواضيع    │
/// │  لذا: كل حمولة JSON تُشفَّر بـ AES-256-CBC قبل الإرسال       │
/// │                                                                 │
/// │  المشارك: encryptPayload(map) → base64 → MQTT                 │
/// │  القائد:  MQTT → base64 → decryptPayload → map               │
/// │                                                                 │
/// │  ما يرى المخترق على الـ Broker: base64 مشفر غير قابل للقراءة │
/// └─────────────────────────────────────────────────────────────────┘
///
/// المواضيع:
///   panopticon/{uid}/gps      → GPS (كل 5 ث)
///   panopticon/{uid}/battery  → بطارية (كل 10 ث)
///   panopticon/{uid}/screen   → حالة الشاشة (عند التغيير)
///   panopticon/{uid}/pulse    → نبضة حية (كل 30 ث) [retained]
class MqttService {
  // ── Singleton ─────────────────────────────────────────────────
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  // ── Config ────────────────────────────────────────────────────
  static const String _broker     = 'a98182cd96de43da9f0f70586b5e006b.s1.eu.hivemq.cloud';
  static const int    _port       = 8883; // TLS
  static const String _username   = 'Abdelrahman123';
  static const String _password   = '321!456?987@aA';
  static const int    _keepAlive  = 30;
  static const int    _retryDelaySec = 5;

  // ── State ──────────────────────────────────────────────────────
  MqttServerClient? _client;
  String? _clientId;
  bool _isLeader = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  final _connectionStateCtrl = StreamController<MqttConnectionState>.broadcast();
  final _telemetryCtrl       = StreamController<MqttTelemetryPacket>.broadcast();

  MqttConnectionState _state = MqttConnectionState.disconnected;

  // ── Public Streams ────────────────────────────────────────────

  Stream<MqttConnectionState> get connectionStream => _connectionStateCtrl.stream;
  Stream<MqttTelemetryPacket> get telemetryStream  => _telemetryCtrl.stream;
  MqttConnectionState get connectionState => _state;
  bool get isConnected => _state == MqttConnectionState.connected;

  // ── Connect ───────────────────────────────────────────────────

  Future<void> connect({required String uid, required bool isLeader}) async {
    if (_state == MqttConnectionState.connected) return;
    _isLeader = isLeader;
    _clientId = 'panopticon_${isLeader ? 'leader' : 'participant'}_$uid';

    // اختبار المفتاح عند أول اتصال
    if (kDebugMode) EncryptionUtil.selfTest();

    _setState(MqttConnectionState.connecting);

    _client = MqttServerClient.withPort(_broker, _clientId!, _port);
    _client!
      ..keepAlivePeriod  = _keepAlive
      ..autoReconnect    = false
      ..onConnected      = _onConnected
      ..onDisconnected   = _onDisconnected;
    _client!.onBadCertificate = (_) => true; // HiveMQ public broker
    _client!.secure = true;
    _client!.logging(on: false);

    _client!.securityContext = SecurityContext.defaultContext;

    // Will message — أيضاً مشفّرة
    final willPayload = EncryptionUtil.encryptPayload({
      'uid':   uid,
      'pulse': 'offline',
      'ts':    DateTime.now().millisecondsSinceEpoch,
    });

    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId!)
        .authenticateAs(_username, _password)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce)
        .withWillTopic(MqttTopics.pulse(uid))
        .withWillMessage(willPayload)
        .withWillRetain();

    try {
      await _client!.connect();
    } catch (e) {
      debugPrint('[MQTT] Connection error: $e');
      _setState(MqttConnectionState.error);
      _scheduleRetry(uid: uid, isLeader: isLeader);
    }
  }

  // ── Subscribe (Leader only) ───────────────────────────────────

  void _subscribeToAll() {
    if (!isConnected) return;
    for (final topic in [
      MqttTopics.allGps,
      MqttTopics.allBattery,
      MqttTopics.allScreen,
      MqttTopics.allPulse,
    ]) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      debugPrint('[MQTT] Subscribed: $topic');
    }
    _client!.updates!.listen(_onMessageReceived);
  }

  // ══════════════════════════════════════════════════════════════
  // Publish Methods (كل حمولة تُشفَّر قبل الإرسال)
  // ══════════════════════════════════════════════════════════════

  /// نشر بيانات GPS (مشفّرة)
  bool publishGps(String uid, GpsPoint gps) {
    return _publishEncrypted(
      topic: MqttTopics.gps(uid),
      payload: {
        'uid': uid,
        'lat': gps.lat,
        'lng': gps.lng,
        'acc': gps.accuracy,
        'spd': gps.speed,
        'ts':  DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// نشر حالة البطارية (مشفّرة)
  bool publishBattery(String uid, BatterySnapshot battery) {
    return _publishEncrypted(
      topic: MqttTopics.battery(uid),
      payload: {
        'uid':    uid,
        'pct':    battery.percent,
        'chg':    battery.isCharging,
        'health': battery.health,
        'ts':     DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// نشر حالة الشاشة (مشفّرة)
  bool publishScreen(String uid, bool isActive) {
    return _publishEncrypted(
      topic: MqttTopics.screen(uid),
      payload: {
        'uid':    uid,
        'active': isActive,
        'ts':     DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// نشر نبضة حية (مشفّرة + retained)
  bool publishPulse(String uid, String pulseState) {
    return _publishEncrypted(
      topic: MqttTopics.pulse(uid),
      payload: {
        'uid':   uid,
        'pulse': pulseState,
        'ts':    DateTime.now().millisecondsSinceEpoch,
      },
      retain: true,
    );
  }

  // ── Disconnect ────────────────────────────────────────────────

  Future<void> disconnect() async {
    _retryTimer?.cancel();
    _client?.disconnect();
    _setState(MqttConnectionState.disconnected);
    debugPrint('[MQTT] Disconnected manually');
  }

  // ══════════════════════════════════════════════════════════════
  // Internal — Encrypt-then-Publish
  // ══════════════════════════════════════════════════════════════

  bool _publishEncrypted({
    required String topic,
    required Map<String, dynamic> payload,
    bool retain = false,
  }) {
    if (!isConnected) return false;
    try {
      // ← تشفير الحمولة قبل الإرسال
      final encrypted = EncryptionUtil.encryptPayload(payload);
      final builder   = MqttClientPayloadBuilder()..addString(encrypted);
      _client!.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
        retain: retain,
      );
      return true;
    } catch (e) {
      debugPrint('[MQTT] Publish/Encrypt error on $topic: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Internal — Receive-then-Decrypt
  // ══════════════════════════════════════════════════════════════

  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final topic  = msg.topic;
      final uid    = MqttTopics.extractUid(topic);
      final metric = MqttTopics.extractMetric(topic);
      if (uid == null || metric == null) continue;

      try {
        final raw = MqttPublishPayload.bytesToStringAsString(
          (msg.payload as MqttPublishMessage).payload.message,
        );

        // ← فك تشفير الحمولة عند الاستقبال
        Map<String, dynamic> payload;
        try {
          payload = EncryptionUtil.decryptPayload(raw);
        } on EncryptionException catch (e) {
          debugPrint('[MQTT] Decryption failed on $topic: $e');
          // لا نُسرِّب بيانات غير مشفّرة — تجاهل الرسالة
          continue;
        }

        _telemetryCtrl.add(MqttTelemetryPacket(
          uid:        uid,
          metric:     metric,
          payload:    payload,
          receivedAt: DateTime.now(),
        ));
      } catch (e) {
        debugPrint('[MQTT] Message processing error on $topic: $e');
      }
    }
  }

  // ── Connection Callbacks ──────────────────────────────────────

  void _onConnected() {
    _retryCount = 0;
    _setState(MqttConnectionState.connected);
    debugPrint('[MQTT] ✓ Connected to $_broker (TLS + AES-256)');
    if (_isLeader) _subscribeToAll();
  }

  void _onDisconnected() {
    if (_state != MqttConnectionState.disconnected) {
      _setState(MqttConnectionState.error);
      debugPrint('[MQTT] ✗ Disconnected unexpectedly');
    }
  }

  void _scheduleRetry({required String uid, required bool isLeader}) {
    final delay = Duration(seconds: _retryDelaySec * (1 << _retryCount.clamp(0, 4)));
    _retryCount++;
    debugPrint('[MQTT] Retry in ${delay.inSeconds}s (attempt $_retryCount)');
    _retryTimer = Timer(delay, () => connect(uid: uid, isLeader: isLeader));
  }

  void _setState(MqttConnectionState s) {
    _state = s;
    _connectionStateCtrl.add(s);
  }

  void dispose() {
    _retryTimer?.cancel();
    _connectionStateCtrl.close();
    _telemetryCtrl.close();
    _client?.disconnect();
  }
}

// MqttTopics مُعرَّفة في lib/models/live_telemetry_model.dart
// لا تكرار هنا — يُستورَد عبر import أعلى الملف
