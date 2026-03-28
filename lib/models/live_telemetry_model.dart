/// نموذج بيانات الاستشعار اللحظي عالي التردد
/// يُرسَل عبر MQTT كل 3-5 ثوانٍ
class LiveTelemetryModel {
  final String uid;
  final GpsPoint? gps;
  final BatterySnapshot battery;
  final bool screenActive;
  final DateTime timestamp;

  const LiveTelemetryModel({
    required this.uid,
    this.gps,
    required this.battery,
    required this.screenActive,
    required this.timestamp,
  });

  // ── MQTT Payload Serialization ────────────────────────────────

  Map<String, dynamic> toGpsPayload() => {
    'uid': uid,
    'lat': gps?.lat,
    'lng': gps?.lng,
    'acc': gps?.accuracy,
    'spd': gps?.speed,
    'ts': timestamp.millisecondsSinceEpoch,
  };

  Map<String, dynamic> toBatteryPayload() => {
    'uid': uid,
    'pct': battery.percent,
    'chg': battery.isCharging,
    'health': battery.health,
    'ts': timestamp.millisecondsSinceEpoch,
  };

  Map<String, dynamic> toScreenPayload() => {
    'uid': uid,
    'active': screenActive,
    'ts': timestamp.millisecondsSinceEpoch,
  };

  // ── Deserialization ───────────────────────────────────────────

  static LiveTelemetryModel fromMqttPayloads({
    required String uid,
    Map<String, dynamic>? gpsPayload,
    Map<String, dynamic>? batteryPayload,
    Map<String, dynamic>? screenPayload,
  }) {
    GpsPoint? gps;
    if (gpsPayload != null &&
        gpsPayload['lat'] != null &&
        gpsPayload['lng'] != null) {
      gps = GpsPoint(
        lat: (gpsPayload['lat'] as num).toDouble(),
        lng: (gpsPayload['lng'] as num).toDouble(),
        accuracy: (gpsPayload['acc'] as num?)?.toDouble() ?? 0,
        speed: (gpsPayload['spd'] as num?)?.toDouble() ?? 0,
      );
    }

    final battery = BatterySnapshot(
      percent: (batteryPayload?['pct'] as num?)?.toInt() ?? -1,
      isCharging: (batteryPayload?['chg'] as bool?) ?? false,
      health: batteryPayload?['health'] as String? ?? 'unknown',
    );

    return LiveTelemetryModel(
      uid: uid,
      gps: gps,
      battery: battery,
      screenActive: (screenPayload?['active'] as bool?) ?? false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (batteryPayload?['ts'] ?? gpsPayload?['ts'] ?? screenPayload?['ts'] ??
            DateTime.now().millisecondsSinceEpoch) as int,
      ),
    );
  }

  LiveTelemetryModel copyWith({
    GpsPoint? gps,
    BatterySnapshot? battery,
    bool? screenActive,
    DateTime? timestamp,
  }) => LiveTelemetryModel(
    uid: uid,
    gps: gps ?? this.gps,
    battery: battery ?? this.battery,
    screenActive: screenActive ?? this.screenActive,
    timestamp: timestamp ?? this.timestamp,
  );
}

class GpsPoint {
  final double lat;
  final double lng;
  final double accuracy; // meters
  final double speed;    // m/s

  const GpsPoint({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.speed,
  });

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'acc': accuracy,
    'spd': speed,
  };

  factory GpsPoint.fromMap(Map<String, dynamic> m) => GpsPoint(
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
    accuracy: (m['acc'] as num?)?.toDouble() ?? 0,
    speed: (m['spd'] as num?)?.toDouble() ?? 0,
  );
}

class BatterySnapshot {
  final int percent;       // 0–100, -1 = unknown
  final bool isCharging;
  final String health;     // 'good' | 'cold' | 'dead' | 'overheat' | 'unknown'

  const BatterySnapshot({
    required this.percent,
    required this.isCharging,
    required this.health,
  });

  Map<String, dynamic> toMap() => {
    'percent': percent,
    'isCharging': isCharging,
    'health': health,
  };

  factory BatterySnapshot.fromMap(Map<String, dynamic> m) => BatterySnapshot(
    percent: (m['percent'] as num?)?.toInt() ?? -1,
    isCharging: (m['isCharging'] as bool?) ?? false,
    health: m['health'] as String? ?? 'unknown',
  );

  static const BatterySnapshot unknown = BatterySnapshot(
    percent: -1,
    isCharging: false,
    health: 'unknown',
  );
}

// ── MQTT Topic Helpers ────────────────────────────────────────

class MqttTopics {
  static const String _base = 'panopticon';

  static String gps(String uid)     => '$_base/$uid/gps';
  static String battery(String uid) => '$_base/$uid/battery';
  static String screen(String uid)  => '$_base/$uid/screen';
  static String pulse(String uid)   => '$_base/$uid/pulse';

  // Wildcard subscriptions for leader (receive all participants)
  static const String allGps     = 'panopticon/+/gps';
  static const String allBattery = 'panopticon/+/battery';
  static const String allScreen  = 'panopticon/+/screen';
  static const String allPulse   = 'panopticon/+/pulse';

  /// Extract UID from topic like 'panopticon/{uid}/gps'
  static String? extractUid(String topic) {
    final parts = topic.split('/');
    if (parts.length >= 3 && parts[0] == _base) return parts[1];
    return null;
  }

  /// Extract metric from topic
  static String? extractMetric(String topic) {
    final parts = topic.split('/');
    if (parts.length >= 3) return parts[2];
    return null;
  }
}
