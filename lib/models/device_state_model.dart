/// نموذج حالة الجهاز — يُخزَّن في Firebase Realtime DB
/// يتحدث بتردد متوسط (~30 ثانية) من خدمة الخلفية
class DeviceStateModel {
  final String uid;
  final String pulse;           // 'active' | 'idle' | 'offline'
  final int? batteryPct;
  final bool? batteryCharging;
  final bool? screenActive;
  final String? currentJob;
  final double? taskProgress;   // 0.0–1.0
  final String? connectionQuality; // 'excellent' | 'good' | 'poor' | 'offline'
  final String? activityState;     // 'active' | 'idle' | 'sleeping'
  final String? focusApp;
  final bool? adminShield;
  final bool? accessibilityEnabled;
  final bool? overlayPermission;
  final bool? batteryOptimizationIgnored;
  final DateTime? lastSeen;
  final double? storageFreePct;

  // ── Module 2: Advanced Telemetry — حقول مباشرة من RTDB ────────
  final int? backspaceCount;    // عدد مسح المدخلات لهذه الجلسة
  final int? stressIndex;       // 0–100 (مُحسوب من TelemetryPublisherService)
  final double? sleepDebt;      // ساعات العجز في النوم (مُحسوب)
  final int? ambientNoise;      // dB مستوى الضوضاء المحيطة
  final int? dlpAlertCount;     // عدد تحذيرات DLP المتراكمة

  const DeviceStateModel({
    required this.uid,
    required this.pulse,
    this.batteryPct,
    this.batteryCharging,
    this.screenActive,
    this.currentJob,
    this.taskProgress,
    this.connectionQuality,
    this.activityState,
    this.focusApp,
    this.adminShield,
    this.accessibilityEnabled,
    this.overlayPermission,
    this.batteryOptimizationIgnored,
    this.lastSeen,
    this.storageFreePct,
    this.backspaceCount,
    this.stressIndex,
    this.sleepDebt,
    this.ambientNoise,
    this.dlpAlertCount,
  });

  // ── RTDB Path ─────────────────────────────────────────────────
  static String rtdbPath(String uid) => 'device_states/$uid';

  // ── Serialization ─────────────────────────────────────────────

  Map<String, dynamic> toRtdb() {
    return {
      'pulse': pulse,
      if (batteryPct != null)       'batteryPct': batteryPct,
      if (batteryCharging != null)  'batteryCharging': batteryCharging,
      if (screenActive != null)     'screenActive': screenActive,
      if (currentJob != null)       'currentJob': currentJob,
      if (taskProgress != null)     'taskProgress': taskProgress,
      if (connectionQuality != null) 'connectionQuality': connectionQuality,
      if (activityState != null)    'activityState': activityState,
      if (focusApp != null)         'focusApp': focusApp,
      if (adminShield != null)      'adminShield': adminShield,
      if (accessibilityEnabled != null) 'accessibilityEnabled': accessibilityEnabled,
      if (overlayPermission != null)    'overlayPermission': overlayPermission,
      if (batteryOptimizationIgnored != null) 'batteryOptimizationIgnored': batteryOptimizationIgnored,
      if (storageFreePct != null)   'storageFreePct': storageFreePct,
      if (backspaceCount != null)   'backspaceCount': backspaceCount,
      if (stressIndex != null)      'stressIndex': stressIndex,
      if (sleepDebt != null)        'sleepDebt': sleepDebt,
      if (ambientNoise != null)     'ambientNoise': ambientNoise,
      if (dlpAlertCount != null)    'dlpAlertCount': dlpAlertCount,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory DeviceStateModel.fromRtdb(String uid, Map<dynamic, dynamic> data) {
    final lastSeenRaw = data['lastSeen'];
    DateTime? lastSeen;
    if (lastSeenRaw is int) {
      lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenRaw);
    }

    return DeviceStateModel(
      uid: uid,
      pulse: data['pulse'] as String? ?? 'offline',
      batteryPct: (data['batteryPct'] as num?)?.toInt(),
      batteryCharging: data['batteryCharging'] as bool?,
      screenActive: data['screenActive'] as bool?,
      currentJob: data['currentJob'] as String?,
      taskProgress: (data['taskProgress'] as num?)?.toDouble(),
      connectionQuality: data['connectionQuality'] as String?,
      activityState: data['activityState'] as String?,
      focusApp: data['focusApp'] as String?,
      adminShield: data['adminShield'] as bool?,
      accessibilityEnabled: data['accessibilityEnabled'] as bool?,
      overlayPermission: data['overlayPermission'] as bool?,
      batteryOptimizationIgnored: data['batteryOptimizationIgnored'] as bool?,
      lastSeen: lastSeen,
      storageFreePct: (data['storageFreePct'] as num?)?.toDouble(),
      backspaceCount: (data['backspaceCount'] as num?)?.toInt(),
      stressIndex:    (data['stressIndex'] as num?)?.toInt(),
      sleepDebt:      (data['sleepDebt'] as num?)?.toDouble(),
      ambientNoise:   (data['ambientNoise'] as num?)?.toInt(),
      dlpAlertCount:  (data['dlpAlertCount'] as num?)?.toInt(),
    );
  }

  DeviceStateModel copyWith({
    String? pulse,
    int? batteryPct,
    bool? batteryCharging,
    bool? screenActive,
    String? currentJob,
    double? taskProgress,
    String? connectionQuality,
    String? activityState,
    String? focusApp,
    bool? adminShield,
    bool? accessibilityEnabled,
    bool? overlayPermission,
    bool? batteryOptimizationIgnored,
    DateTime? lastSeen,
    double? storageFreePct,
    int? backspaceCount,
    int? stressIndex,
    double? sleepDebt,
    int? ambientNoise,
    int? dlpAlertCount,
  }) => DeviceStateModel(
    uid: uid,
    pulse: pulse ?? this.pulse,
    batteryPct: batteryPct ?? this.batteryPct,
    batteryCharging: batteryCharging ?? this.batteryCharging,
    screenActive: screenActive ?? this.screenActive,
    currentJob: currentJob ?? this.currentJob,
    taskProgress: taskProgress ?? this.taskProgress,
    connectionQuality: connectionQuality ?? this.connectionQuality,
    activityState: activityState ?? this.activityState,
    focusApp: focusApp ?? this.focusApp,
    adminShield: adminShield ?? this.adminShield,
    accessibilityEnabled: accessibilityEnabled ?? this.accessibilityEnabled,
    overlayPermission: overlayPermission ?? this.overlayPermission,
    batteryOptimizationIgnored: batteryOptimizationIgnored ?? this.batteryOptimizationIgnored,
    lastSeen: lastSeen ?? this.lastSeen,
    storageFreePct: storageFreePct ?? this.storageFreePct,
    backspaceCount: backspaceCount ?? this.backspaceCount,
    stressIndex: stressIndex ?? this.stressIndex,
    sleepDebt: sleepDebt ?? this.sleepDebt,
    ambientNoise: ambientNoise ?? this.ambientNoise,
    dlpAlertCount: dlpAlertCount ?? this.dlpAlertCount,
  );

  /// يحدد حالة الإشارة الحية بناءً على آخر ظهور
  String get computedPulse {
    if (lastSeen == null) return 'offline';
    final diff = DateTime.now().difference(lastSeen!);
    if (diff.inSeconds < 15) return 'active';
    if (diff.inMinutes < 2)  return 'idle';
    return 'offline';
  }

  static const DeviceStateModel offline = DeviceStateModel(
    uid: '',
    pulse: 'offline',
  );
}
