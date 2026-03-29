import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج بيانات بطاقة المشارك الكاملة
class ParticipantCardModel {
  final String uid;
  final String name;
  final String code;
  final String? avatarUrl;
  final String? currentJob;
  final LivePulse livePulse;
  final int? batteryPercent;
  final BatteryHealth? batteryHealth;
  final int? obedienceGrade;       // 0–100
  final bool? rebellionStatus;
  final String? focusApp;
  final PhysicalPresence? physicalPresence;
  final int? ambientLight;         // lux
  final ActivityState? activityState;
  final int? storageHealth;        // % free
  final bool? adminShield;
  final ConnectionQuality? connectionQuality;
  final int credits;
  final int? stressIndex;          // 0–100
  final int? ambientNoise;         // dB
  final OrientationMode? deviceOrientation;
  final LightExposure? lightExposure;
  final int rankPosition;
  final String? geofenceName;
  final int? appUsagePulse;        // apps/hr
  final int? physicalStamina;      // 0–100
  final double? sleepDebt;         // hours
  final Posture? currentPosture;
  final bool? liveBlur;
  final int? backspaceCount;       // /hr
  final EmotionalTone? emotionalTone;
  final AntiCheatStatus? antiCheatStatus;
  final DateTime? lastCommunication;
  final double? taskProgress;      // 0.0–1.0
  final String? nextJob;
  final DateTime? inventoryExpiry;
  final Duration? nextJobCountdown;
  final Classification? classification;
  final int? loyaltyStreak;        // days
  final int? deceptionProbability; // 0–100
  final int? emotionalVolatility;  // 0–100
  final int? cognitiveLoad;        // 0–100
  final double? spaceDistance;     // meters
  final double? debtToCreditRatio;
  final int? pleadingQuota;        // 0–100
  final String applicationStatus;  // pending / submitted / approved / rejected

  const ParticipantCardModel({
    required this.uid,
    required this.name,
    required this.code,
    this.avatarUrl,
    this.currentJob,
    required this.livePulse,
    this.batteryPercent,
    this.batteryHealth,
    this.obedienceGrade,
    this.rebellionStatus,
    this.focusApp,
    this.physicalPresence,
    this.ambientLight,
    this.activityState,
    this.storageHealth,
    this.adminShield,
    this.connectionQuality,
    required this.credits,
    this.stressIndex,
    this.ambientNoise,
    this.deviceOrientation,
    this.lightExposure,
    required this.rankPosition,
    this.geofenceName,
    this.appUsagePulse,
    this.physicalStamina,
    this.sleepDebt,
    this.currentPosture,
    this.liveBlur,
    this.backspaceCount,
    this.emotionalTone,
    this.antiCheatStatus,
    this.lastCommunication,
    this.taskProgress,
    this.nextJob,
    this.inventoryExpiry,
    this.nextJobCountdown,
    this.classification,
    this.loyaltyStreak,
    this.deceptionProbability,
    this.emotionalVolatility,
    this.cognitiveLoad,
    this.spaceDistance,
    this.debtToCreditRatio,
    this.pleadingQuota,
    required this.applicationStatus,
  });

  // ── تحويل البيانات الحقيقية من Firestore ─────────────────────
  factory ParticipantCardModel.fromFirestore(String id, Map<String, dynamic> d) {
    
    // دالة مساعدة لتحويل النصوص المسجلة في قاعدة البيانات إلى Enums بشكل آمن
    T? enumFromString<T>(Iterable<T> values, String? value) {
      if (value == null) return null;
      try {
        return values.firstWhere((e) => e.toString().split('.').last == value);
      } catch (_) {
        return null;
      }
    }

    // تحديد حالة النبض بناءً على البيانات (إذا لم تكن مسجلة صراحة، نستنتجها من حالة الاستمارة)
    LivePulse pulse = enumFromString(LivePulse.values, d['livePulse']) ??
        (d['applicationStatus'] == 'approved_active' ? LivePulse.active : 
         d['applicationStatus'] == 'pending' ? LivePulse.idle : LivePulse.offline);

    return ParticipantCardModel(
      uid: id,
      name: d['fullName'] ?? d['displayName'] ?? 'عنصر مجهول',
      code: d['code'] ?? d['participantCode'] ?? 'غير محدد',
      avatarUrl: d['photoURL'],
      applicationStatus: d['applicationStatus'] ?? 'pending',
      livePulse: pulse,
      credits: d['credits'] ?? 0,
      rankPosition: d['rankPosition'] ?? 0,
      currentJob: d['currentJob'],
      batteryPercent: d['batteryPercent'],
      batteryHealth: enumFromString(BatteryHealth.values, d['batteryHealth']),
      obedienceGrade: d['obedienceGrade'],
      rebellionStatus: d['rebellionStatus'],
      focusApp: d['focusApp'],
      physicalPresence: enumFromString(PhysicalPresence.values, d['physicalPresence']),
      ambientLight: d['ambientLight'],
      activityState: enumFromString(ActivityState.values, d['activityState']),
      storageHealth: d['storageHealth'],
      adminShield: d['adminShield'],
      connectionQuality: enumFromString(ConnectionQuality.values, d['connectionQuality']),
      stressIndex: d['stressIndex'],
      ambientNoise: d['ambientNoise'],
      deviceOrientation: enumFromString(OrientationMode.values, d['deviceOrientation']),
      lightExposure: enumFromString(LightExposure.values, d['lightExposure']),
      geofenceName: d['geofenceName'],
      appUsagePulse: d['appUsagePulse'],
      physicalStamina: d['physicalStamina'],
      sleepDebt: (d['sleepDebt'] as num?)?.toDouble(),
      currentPosture: enumFromString(Posture.values, d['currentPosture']),
      liveBlur: d['liveBlur'],
      backspaceCount: d['backspaceCount'],
      emotionalTone: enumFromString(EmotionalTone.values, d['emotionalTone']),
      antiCheatStatus: enumFromString(AntiCheatStatus.values, d['antiCheatStatus']),
      // سحب وقت آخر ظهور وتواصل
      lastCommunication: (d['last_seen'] as Timestamp?)?.toDate() ?? (d['lastCommunication'] as Timestamp?)?.toDate(),
      taskProgress: (d['taskProgress'] as num?)?.toDouble(),
      nextJob: d['nextJob'],
      inventoryExpiry: (d['inventoryExpiry'] as Timestamp?)?.toDate(),
      nextJobCountdown: d['nextJobCountdownMs'] != null ? Duration(milliseconds: d['nextJobCountdownMs']) : null,
      classification: enumFromString(Classification.values, d['classification']),
      loyaltyStreak: d['loyaltyStreak'],
      deceptionProbability: d['deceptionProbability'],
      emotionalVolatility: d['emotionalVolatility'],
      cognitiveLoad: d['cognitiveLoad'],
      spaceDistance: (d['spaceDistance'] as num?)?.toDouble(),
      debtToCreditRatio: (d['debtToCreditRatio'] as num?)?.toDouble(),
      pleadingQuota: d['pleadingQuota'],
    );
  }
}

// ── Enums ─────────────────────────────────────────────────────

enum LivePulse { active, idle, offline }
enum BatteryHealth { good, fair, poor, critical }
enum PhysicalPresence { indoor, outdoor, transit, unknown }
enum ActivityState { active, idle, sleeping }
enum ConnectionQuality { excellent, good, poor, offline }
enum OrientationMode { portrait, landscape }
enum LightExposure { bright, dim, dark }
enum Posture { sitting, standing, walking, lying }
enum EmotionalTone { positive, neutral, negative, stressed }
enum AntiCheatStatus { clean, suspicious, flagged }
enum Classification { resident, commuter }

// ── Field Keys (used by visibility settings) ─────────────────

class CardField {
  final String key;
  final String label;
  final String category;

  const CardField({
    required this.key,
    required this.label,
    required this.category,
  });

  static const List<CardField> all = [
    CardField(key: 'currentJob',     label: 'المهمة الحالية',       category: 'identity'),
    CardField(key: 'classification', label: 'التصنيف',              category: 'identity'),
    CardField(key: 'rankPosition',   label: 'الترتيب',              category: 'identity'),
    CardField(key: 'geofenceName',   label: 'المنطقة الجغرافية',    category: 'identity'),
    CardField(key: 'livePulse',      label: 'الإشارة الحية',        category: 'live'),
    CardField(key: 'activityState',  label: 'حالة النشاط',          category: 'live'),
    CardField(key: 'physicalPresence',label: 'التواجد الفعلي',      category: 'live'),
    CardField(key: 'focusApp',       label: 'التطبيق النشط',        category: 'live'),
    CardField(key: 'appUsagePulse',  label: 'نبض استخدام التطبيقات',category: 'live'),
    CardField(key: 'deviceOrientation', label: 'اتجاه الجهاز',      category: 'live'),
    CardField(key: 'batteryPercent', label: 'البطارية %',            category: 'device'),
    CardField(key: 'batteryHealth',  label: 'صحة البطارية',          category: 'device'),
    CardField(key: 'storageHealth',  label: 'مساحة التخزين',         category: 'device'),
    CardField(key: 'adminShield',    label: 'درع المشرف',            category: 'device'),
    CardField(key: 'connectionQuality', label: 'جودة الاتصال',      category: 'device'),
    CardField(key: 'liveBlur',       label: 'ضبابية الشاشة',        category: 'device'),
    CardField(key: 'lastCommunication', label: 'آخر تواصل',          category: 'device'),
    CardField(key: 'obedienceGrade', label: 'درجة الطاعة',          category: 'performance'),
    CardField(key: 'antiCheatStatus',label: 'حالة الغش',            category: 'performance'),
    CardField(key: 'taskProgress',   label: 'تقدم المهمة',          category: 'performance'),
    CardField(key: 'nextJob',        label: 'المهمة القادمة',        category: 'performance'),
    CardField(key: 'nextJobCountdown',label: 'العد التنازلي',       category: 'performance'),
    CardField(key: 'loyaltyStreak',  label: 'سلسلة الولاء',         category: 'performance'),
    CardField(key: 'rebellionStatus',label: 'حالة التمرد',          category: 'performance'),
    CardField(key: 'ambientLight',   label: 'الضوء المحيط',         category: 'environment'),
    CardField(key: 'lightExposure',  label: 'تعرض الضوء',           category: 'environment'),
    CardField(key: 'ambientNoise',   label: 'الضوضاء المحيطة',      category: 'environment'),
    CardField(key: 'spaceDistance',  label: 'المسافة التقريبية',     category: 'environment'),
    CardField(key: 'stressIndex',    label: 'مؤشر التوتر',          category: 'psych'),
    CardField(key: 'emotionalTone',  label: 'النبرة العاطفية',       category: 'psych'),
    CardField(key: 'cognitiveLoad',  label: 'الحمل المعرفي',         category: 'psych'),
    CardField(key: 'sleepDebt',      label: 'عجز النوم',            category: 'psych'),
    CardField(key: 'deceptionProbability', label: 'احتمالية الخداع',  category: 'psych'),
    CardField(key: 'emotionalVolatility',  label: 'التقلب العاطفي',   category: 'psych'),
    CardField(key: 'currentPosture', label: 'الوضعية الحالية',       category: 'psych'),
    CardField(key: 'physicalStamina',label: 'القدرة البدنية',         category: 'psych'),
    CardField(key: 'backspaceCount', label: 'عدد مسح المدخلات',      category: 'psych'),
    CardField(key: 'credits',        label: 'الرصيد',               category: 'finance'),
    CardField(key: 'debtToCreditRatio', label: 'نسبة الدين/رصيد',    category: 'finance'),
    CardField(key: 'pleadingQuota',  label: 'حصة الاستجداء',        category: 'finance'),
    CardField(key: 'inventoryExpiry',label: 'انتهاء المخزون',       category: 'finance'),
  ];

  static const Map<String, String> categoryLabels = {
    'identity':    'الهوية',
    'live':        'الحالة الحية',
    'device':      'الجهاز',
    'performance': 'الأداء',
    'environment': 'البيئة',
    'psych':       'نفسي / بيولوجي',
    'finance':     'مالي',
  };

  static const Set<String> defaultVisible = {
    'livePulse', 'batteryPercent', 'obedienceGrade', 'rankPosition',
    'focusApp', 'taskProgress', 'antiCheatStatus', 'connectionQuality',
    'activityState', 'lastCommunication',
  };
}
