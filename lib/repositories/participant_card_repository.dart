import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/participant_card_model.dart';
import '../models/device_state_model.dart';
import '../models/live_telemetry_model.dart';
import '../services/firestore_service.dart';
import '../services/rtdb_service.dart';

/// ParticipantCardRepository — الجسر الحيوي الذي يصل البيانات بالواجهة
///
/// يدمج ثلاثة مصادر في نموذج ParticipantCardModel واحد:
///
///   Firestore (profiles)   → name, code, avatarUrl, applicationStatus
///   RTDB (device_states)   → pulse, battery, screen, adminShield, focusApp…
///   MQTT (LiveTelemetry)   → GPS, battery (أولوية أعلى), screenActive
///
/// يُستدعى من ParticipantStreamProvider الذي يُكشَف للـ UI.
///
/// ⚡ هذه الفئة تُصلح نقطة الإيقاف الميتة الرئيسية في النظام:
///    كانت Card UI تقرأ من mock data — الآن تقرأ من RTDB + Firestore حياً.
class ParticipantCardRepository {
  static final ParticipantCardRepository _i = ParticipantCardRepository._();
  factory ParticipantCardRepository() => _i;
  ParticipantCardRepository._();

  final _fs   = FirestoreService();
  final _rtdb = RtdbService();

  // Cache المهم — يمنع إعادة بناء الكارت في كل frame
  final Map<String, Map<String, dynamic>>  _profileCache = {};
  final Map<String, DeviceStateModel>      _rtdbCache    = {};
  final Map<String, LiveTelemetryModel>    _mqttCache    = {};

  StreamSubscription? _rtdbSub;
  StreamSubscription? _fsSub;

  final _participantsCtrl =
      StreamController<List<ParticipantCardModel>>.broadcast();
  final _pendingCtrl =
      StreamController<List<JoinRequestLive>>.broadcast();

  Stream<List<ParticipantCardModel>> get participantsStream =>
      _participantsCtrl.stream;
  Stream<List<JoinRequestLive>> get pendingRequestsStream =>
      _pendingCtrl.stream;

  // ── Initialization ────────────────────────────────────────────

  void start() {
    _startRtdbWatch();
    _startFirestoreWatch();
  }

  void stop() {
    _rtdbSub?.cancel();
    _fsSub?.cancel();
  }

  /// يُحدَّث من TelemetryProvider عند وصول حزمة MQTT جديدة
  void updateMqtt(String uid, LiveTelemetryModel data) {
    _mqttCache[uid] = data;
    _rebuild();
  }

  // ── RTDB Watch ────────────────────────────────────────────────

  void _startRtdbWatch() {
    _rtdbSub?.cancel();
    _rtdbSub = _rtdb.watchAll().listen((map) {
      _rtdbCache
        ..clear()
        ..addAll(map);
      _rebuild();
    }, onError: (e) {
      debugPrint('[ParticipantCardRepo] RTDB watch error: $e');
    });
  }

  // ── Firestore Watch ───────────────────────────────────────────

  void _startFirestoreWatch() {
    _fsSub?.cancel();
    // مراقبة طلبات الانضمام المعلقة
    _fsSub = _fs.watchPendingRequests().listen((list) {
      final requests = list
          .map((d) => JoinRequestLive.fromFirestore(d))
          .toList();
      _pendingCtrl.add(requests);
      debugPrint('[ParticipantCardRepo] ${requests.length} pending requests');
    }, onError: (e) {
      debugPrint('[ParticipantCardRepo] FS pending watch error: $e');
    });

    // قراءة المشاركين المعتمدين
    _loadApprovedParticipants();
  }

  Future<void> _loadApprovedParticipants() async {
    try {
      final list = await _fs.getAllParticipants();
      for (final p in list) {
        final uid = p['uid'] as String;
        _profileCache[uid] = p;
      }
      _rebuild();
    } catch (e) {
      debugPrint('[ParticipantCardRepo] Load participants error: $e');
    }
  }

  // ── Rebuild ───────────────────────────────────────────────────

  void _rebuild() {
    // دمج المصادر الثلاثة
    final allUids = {
      ..._profileCache.keys,
      ..._rtdbCache.keys,
    };

    int rank = 0;
    final cards = allUids.map((uid) {
      rank++;
      final profile = _profileCache[uid] ?? {};
      final rtdb    = _rtdbCache[uid];
      final mqtt    = _mqttCache[uid];
      return _buildCard(uid, rank, profile, rtdb, mqtt);
    }).toList();

    // ترتيب: النشط أولاً ثم الخامل ثم الغائب
    cards.sort((a, b) {
      final order = {LivePulse.active: 0, LivePulse.idle: 1, LivePulse.offline: 2};
      final cmp = (order[a.livePulse] ?? 2).compareTo(order[b.livePulse] ?? 2);
      if (cmp != 0) return cmp;
      return b.batteryPercent?.compareTo(a.batteryPercent ?? 0) ?? 0;
    });

    _participantsCtrl.add(cards);
  }

  // ── Card Builder — قلب النظام ─────────────────────────────────

  ParticipantCardModel _buildCard(
    String uid,
    int rank,
    Map<String, dynamic> profile,
    DeviceStateModel? rtdb,
    LiveTelemetryModel? mqtt,
  ) {
    // ── النبضة الحية ──────────────────────────────────────────
    final pulseStr = _computePulse(rtdb, mqtt);
    final livePulse = switch (pulseStr) {
      'active' => LivePulse.active,
      'idle'   => LivePulse.idle,
      _        => LivePulse.offline,
    };

    // ── البطارية (MQTT أولوية ثم RTDB) ───────────────────────
    final batteryPct = (mqtt?.battery.percent != null && mqtt!.battery.percent >= 0)
        ? mqtt.battery.percent
        : rtdb?.batteryPct;

    final batteryHealth = _batteryHealth(batteryPct);

    // ── التخزين ───────────────────────────────────────────────
    final storagePct = rtdb?.storageFreePct?.round();

    // ── جودة الاتصال ──────────────────────────────────────────
    final connQ = _connectionQuality(rtdb?.connectionQuality, mqtt);

    // ── نشاط الجهاز ───────────────────────────────────────────
    final activityStr = rtdb?.activityState;
    final activityState = switch (activityStr) {
      'active'   => ActivityState.active,
      'idle'     => ActivityState.idle,
      'sleeping' => ActivityState.sleeping,
      _          => null,
    };

    // ── آخر ظهور ──────────────────────────────────────────────
    final lastSeen = mqtt?.timestamp ?? rtdb?.lastSeen;

    // ── درع المشرف ────────────────────────────────────────────
    final adminShield = rtdb?.adminShield;

    // ── مخزون / انتهاء ────────────────────────────────────────
    final inventoryExpiryRaw = profile['inventoryExpiryDate'];
    DateTime? inventoryExpiry;
    if (inventoryExpiryRaw is int) {
      inventoryExpiry = DateTime.fromMillisecondsSinceEpoch(inventoryExpiryRaw);
    }

    // ── Module 2: حساب مقاييس الأسطول المتقدمة ─────────────────
    final bsCount     = rtdb?.backspaceCount;
    final stressIdx   = rtdb?.stressIndex   ?? _deriveStressIndex(rtdb, bsCount);
    final sleepDebtH  = rtdb?.sleepDebt     ?? _deriveSleepDebt(rtdb);
    final stamina     = _derivePhysicalStamina(stressIdx, batteryPct, rtdb);
    final emoVol      = _deriveEmotionalVolatility(stressIdx, bsCount);
    final noiseDb     = rtdb?.ambientNoise;
    final dlpAlerts   = rtdb?.dlpAlertCount ?? 0;

    return ParticipantCardModel(
      uid:             uid,
      name:            (profile['fullName'] ?? profile['displayName'] ?? 'مشارك') as String,
      code:            (profile['linkedLeaderCode'] ?? profile['code'] ?? '----') as String,
      avatarUrl:       profile['avatarUrl'] as String?,
      currentJob:      rtdb?.currentJob ?? profile['currentJob'] as String?,
      livePulse:       livePulse,
      batteryPercent:  batteryPct,
      batteryHealth:   batteryHealth,
      obedienceGrade:  (profile['obedienceGrade'] as num?)?.toInt(),
      rebellionStatus: profile['rebellionStatus'] as bool?,
      focusApp:        rtdb?.focusApp,
      physicalPresence: null,
      ambientLight:    null,
      activityState:   activityState,
      storageHealth:   storagePct,
      adminShield:     adminShield,
      connectionQuality: connQ,
      credits:         (profile['credits'] as num?)?.toInt() ?? 0,
      stressIndex:     stressIdx,
      ambientNoise:    noiseDb,
      deviceOrientation: null,
      lightExposure:   null,
      rankPosition:    rank,
      geofenceName:    profile['geofenceName'] as String?,
      appUsagePulse:   null,
      physicalStamina: stamina,
      sleepDebt:       sleepDebtH,
      currentPosture:  null,
      liveBlur:        profile['liveBlur'] as bool?,
      backspaceCount:  bsCount,
      emotionalTone:   _deriveEmotionalTone(stressIdx, emoVol),
      antiCheatStatus: (adminShield == false || dlpAlerts > 0)
          ? AntiCheatStatus.suspicious
          : AntiCheatStatus.clean,
      lastCommunication: lastSeen,
      taskProgress:    rtdb?.taskProgress,
      nextJob:         profile['nextJob'] as String?,
      inventoryExpiry: inventoryExpiry,
      nextJobCountdown: null,
      classification:  null,
      loyaltyStreak:   (profile['loyaltyStreak'] as num?)?.toInt(),
      deceptionProbability: _deriveDeceptionProbability(bsCount, stressIdx, dlpAlerts),
      emotionalVolatility:  emoVol,
      cognitiveLoad:   stressIdx,
      spaceDistance:   _distanceFromGps(mqtt?.gps),
      debtToCreditRatio: null,
      pleadingQuota:   (profile['pleadingQuota'] as num?)?.toInt(),
      applicationStatus: (profile['applicationStatus'] as String?) ?? 'pending',
    );
  }

  // ── Fleet Health Derivation Engine ───────────────────────────

  /// مؤشر التوتر — يُستخرج من RTDB مباشرةً أو يُحسب من البيانات الوكيلة
  int? _deriveStressIndex(DeviceStateModel? rtdb, int? bsCount) {
    if (rtdb == null) return null;
    // الحساب المنطقي: البطارية المنخفضة + حذف مرتفع = توتر أعلى
    int stress = 30; // قاعدة متوسطة
    final bat = rtdb.batteryPct;
    if (bat != null && bat < 20) stress += 25;
    if (bsCount != null && bsCount > 20) stress += (bsCount.clamp(0, 100) * 0.4).round();
    if (rtdb.activityState == 'sleeping') stress = (stress * 0.5).round();
    return stress.clamp(0, 100);
  }

  /// عجز النوم بالساعات — مُستخرج من RTDB أو مشتق من نمط النشاط
  double? _deriveSleepDebt(DeviceStateModel? rtdb) {
    if (rtdb == null) return null;
    final lastS = rtdb.lastSeen;
    if (lastS == null) return null;
    final hoursSinceLastSeen = DateTime.now().difference(lastS).inHours;
    // إذا لم يظهر الجهاز لفترة طويلة يُعاد احتساب العجز
    if (hoursSinceLastSeen > 8) {
      return (hoursSinceLastSeen - 8.0).clamp(0.0, 4.0);
    }
    // النشاط المستمر يراكم عجز النوم
    if (rtdb.activityState == 'active' && hoursSinceLastSeen < 1) {
      return 0.5;
    }
    return 0.0;
  }

  /// القدرة البدنية — عكسية للتوتر مع معامل البطارية
  int? _derivePhysicalStamina(int? stressIdx, int? batteryPct, DeviceStateModel? rtdb) {
    if (stressIdx == null && batteryPct == null) return null;
    final stressFactor   = 100 - (stressIdx ?? 50);
    final batteryFactor  = batteryPct ?? 50;
    // متوسط مرجح: 60% من عكس التوتر + 40% من البطارية
    return ((stressFactor * 0.6) + (batteryFactor * 0.4)).round().clamp(0, 100);
  }

  /// التقلب العاطفي — مشتق من حذف المدخلات والتوتر
  int? _deriveEmotionalVolatility(int? stressIdx, int? bsCount) {
    if (stressIdx == null && bsCount == null) return null;
    final stressComp  = (stressIdx ?? 30) * 0.6;
    final bsComp      = ((bsCount ?? 0).clamp(0, 100)) * 0.4;
    return (stressComp + bsComp).round().clamp(0, 100);
  }

  /// النبرة العاطفية المشتقة
  EmotionalTone? _deriveEmotionalTone(int? stressIdx, int? emoVol) {
    if (stressIdx == null) return null;
    if (stressIdx > 70 || (emoVol ?? 0) > 70) return EmotionalTone.stressed;
    if (stressIdx > 45) return EmotionalTone.negative;
    if (stressIdx > 20) return EmotionalTone.neutral;
    return EmotionalTone.positive;
  }

  /// احتمالية الخداع — تزيد مع DLP alerts والبصمة البيهافيورية
  int? _deriveDeceptionProbability(int? bsCount, int? stressIdx, int dlpAlerts) {
    if (bsCount == null && stressIdx == null && dlpAlerts == 0) return null;
    int score = 0;
    if (bsCount != null && bsCount > 30) score += 25;
    if (stressIdx != null && stressIdx > 60) score += 20;
    if (dlpAlerts > 0) score += (dlpAlerts * 10).clamp(0, 50);
    return score.clamp(0, 100);
  }

  // ── Helper: Pulse ─────────────────────────────────────────────

  String _computePulse(DeviceStateModel? rtdb, LiveTelemetryModel? mqtt) {
    if (mqtt != null) {
      final diff = DateTime.now().difference(mqtt.timestamp);
      if (diff.inSeconds < 15) return 'active';
      if (diff.inSeconds < 45) return 'idle';
    }
    return rtdb?.computedPulse ?? 'offline';
  }

  // ── Helper: Battery Health ────────────────────────────────────

  BatteryHealth? _batteryHealth(int? pct) {
    if (pct == null) return null;
    if (pct > 50) return BatteryHealth.good;
    if (pct > 20) return BatteryHealth.fair;
    if (pct > 10) return BatteryHealth.poor;
    return BatteryHealth.critical;
  }

  // ── Helper: Connection Quality ────────────────────────────────

  ConnectionQuality _connectionQuality(
      String? rtdbStr, LiveTelemetryModel? mqtt) {
    if (mqtt != null) {
      final diff = DateTime.now().difference(mqtt.timestamp);
      if (diff.inSeconds < 10)  return ConnectionQuality.excellent;
      if (diff.inSeconds < 30)  return ConnectionQuality.good;
      if (diff.inSeconds < 120) return ConnectionQuality.poor;
    }
    return switch (rtdbStr) {
      'excellent' => ConnectionQuality.excellent,
      'good'      => ConnectionQuality.good,
      'poor'      => ConnectionQuality.poor,
      _           => ConnectionQuality.offline,
    };
  }

  // ── Helper: Distance ─────────────────────────────────────────

  double? _distanceFromGps(GpsPoint? gps) => gps?.accuracy;

  void dispose() {
    stop();
    _participantsCtrl.close();
    _pendingCtrl.close();
  }
}

// ── Live Join Request Model ───────────────────────────────────

class JoinRequestLive {
  final String uid;
  final String name;
  final String deviceModel;
  final String email;
  final DateTime requestedAt;
  final String status;

  const JoinRequestLive({
    required this.uid,
    required this.name,
    required this.deviceModel,
    required this.email,
    required this.requestedAt,
    required this.status,
  });

  factory JoinRequestLive.fromFirestore(Map<String, dynamic> d) {
    return JoinRequestLive(
      uid:         d['uid'] as String? ?? '',
      name:        (d['fullName'] ?? d['displayName'] ?? 'مشارك') as String,
      deviceModel: (d['deviceModel'] ?? 'Android') as String,
      email:       (d['email'] ?? '') as String,
      requestedAt: d['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(d['createdAt'] as int)
          : (d['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      status:      (d['applicationStatus'] ?? 'pending') as String,
    );
  }
}
