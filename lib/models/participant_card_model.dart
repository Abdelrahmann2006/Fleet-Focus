import 'dart:math';

/// نموذج بيانات بطاقة المشارك الكاملة
/// يشمل جميع نقاط البيانات الممكنة — معظمها nullable (لم تُجمع بعد)
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

  // ── Mock Data Generator ──────────────────────────────────────

  static final _rng = Random();
  static int _rank = 0;

  static final _names = [
    'فهد العتيبي', 'سارة المطيري', 'ماجد الشمري', 'نورة القحطاني',
    'بندر الدوسري', 'ريم الزهراني', 'خالد الحربي', 'لينا السبيعي',
    'عبدالله العنزي', 'هند العسيري', 'سلطان البقمي', 'منى الغامدي',
  ];
  static final _jobs = [
    'مراقب ميداني', 'محلل بيانات', 'منسق عمليات', 'مشرف فرعي',
    'مراسل أحداث', 'مدير لوجستي', null, null,
  ];
  static final _apps = [
    'com.whatsapp', 'com.google.android.youtube', 'com.instagram.android',
    'com.android.chrome', 'com.android.settings', null,
  ];
  static final _geofences = [
    'المنطقة الشمالية', 'حرم الجامعة', 'المركز التجاري',
    'الحي الغربي', null, null,
  ];
  static final _nextJobs = [
    'تقرير ميداني #7', 'مراجعة الحسابات', 'فحص المعدات', null,
  ];

  static ParticipantCardModel mock(String uid) {
    _rank++;
    final r = _rng;
    final pulse = LivePulse.values[r.nextInt(LivePulse.values.length)];
    return ParticipantCardModel(
      uid: uid,
      name: _names[r.nextInt(_names.length)],
      code: 'P${r.nextInt(9000) + 1000}',
      currentJob: _jobs[r.nextInt(_jobs.length)],
      livePulse: pulse,
      batteryPercent: r.nextInt(100),
      batteryHealth: BatteryHealth.values[r.nextInt(BatteryHealth.values.length)],
      obedienceGrade: r.nextInt(101),
      rebellionStatus: r.nextBool(),
      focusApp: _apps[r.nextInt(_apps.length)],
      physicalPresence: PhysicalPresence.values[r.nextInt(PhysicalPresence.values.length)],
      ambientLight: r.nextInt(1000),
      activityState: ActivityState.values[r.nextInt(ActivityState.values.length)],
      storageHealth: 10 + r.nextInt(90),
      adminShield: r.nextBool(),
      connectionQuality: ConnectionQuality.values[r.nextInt(ConnectionQuality.values.length)],
      credits: r.nextInt(5000) - 1000,
      stressIndex: r.nextInt(101),
      ambientNoise: 20 + r.nextInt(80),
      deviceOrientation: OrientationMode.values[r.nextInt(OrientationMode.values.length)],
      lightExposure: LightExposure.values[r.nextInt(LightExposure.values.length)],
      rankPosition: _rank,
      geofenceName: _geofences[r.nextInt(_geofences.length)],
      appUsagePulse: r.nextInt(20),
      physicalStamina: r.nextInt(101),
      sleepDebt: r.nextDouble() * 6,
      currentPosture: Posture.values[r.nextInt(Posture.values.length)],
      liveBlur: r.nextBool(),
      backspaceCount: r.nextInt(50),
      emotionalTone: EmotionalTone.values[r.nextInt(EmotionalTone.values.length)],
      antiCheatStatus: r.nextDouble() < 0.8
          ? AntiCheatStatus.clean
          : AntiCheatStatus.values[r.nextInt(AntiCheatStatus.values.length)],
      lastCommunication: DateTime.now().subtract(Duration(minutes: r.nextInt(120))),
      taskProgress: r.nextDouble(),
      nextJob: _nextJobs[r.nextInt(_nextJobs.length)],
      inventoryExpiry: DateTime.now().add(Duration(days: r.nextInt(30))),
      nextJobCountdown: Duration(hours: r.nextInt(24), minutes: r.nextInt(60)),
      classification: Classification.values[r.nextInt(Classification.values.length)],
      loyaltyStreak: r.nextInt(60),
      deceptionProbability: r.nextInt(101),
      emotionalVolatility: r.nextInt(101),
      cognitiveLoad: r.nextInt(101),
      spaceDistance: r.nextDouble() * 500,
      debtToCreditRatio: 0.5 + r.nextDouble() * 2,
      pleadingQuota: r.nextInt(101),
      applicationStatus: 'approved',
    );
  }

  static List<ParticipantCardModel> mockList(int count) {
    _rank = 0;
    return List.generate(count, (i) => mock('uid_$i'));
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
    // الهوية
    CardField(key: 'currentJob',     label: 'المهمة الحالية',       category: 'identity'),
    CardField(key: 'classification', label: 'التصنيف',              category: 'identity'),
    CardField(key: 'rankPosition',   label: 'الترتيب',              category: 'identity'),
    CardField(key: 'geofenceName',   label: 'المنطقة الجغرافية',    category: 'identity'),
    // الحالة الحية
    CardField(key: 'livePulse',      label: 'الإشارة الحية',        category: 'live'),
    CardField(key: 'activityState',  label: 'حالة النشاط',          category: 'live'),
    CardField(key: 'physicalPresence',label: 'التواجد الفعلي',      category: 'live'),
    CardField(key: 'focusApp',       label: 'التطبيق النشط',        category: 'live'),
    CardField(key: 'appUsagePulse',  label: 'نبض استخدام التطبيقات',category: 'live'),
    CardField(key: 'deviceOrientation', label: 'اتجاه الجهاز',      category: 'live'),
    // الجهاز
    CardField(key: 'batteryPercent', label: 'البطارية %',            category: 'device'),
    CardField(key: 'batteryHealth',  label: 'صحة البطارية',          category: 'device'),
    CardField(key: 'storageHealth',  label: 'مساحة التخزين',         category: 'device'),
    CardField(key: 'adminShield',    label: 'درع المشرف',            category: 'device'),
    CardField(key: 'connectionQuality', label: 'جودة الاتصال',      category: 'device'),
    CardField(key: 'liveBlur',       label: 'ضبابية الشاشة',        category: 'device'),
    CardField(key: 'lastCommunication', label: 'آخر تواصل',          category: 'device'),
    // الأداء
    CardField(key: 'obedienceGrade', label: 'درجة الطاعة',          category: 'performance'),
    CardField(key: 'antiCheatStatus',label: 'حالة الغش',            category: 'performance'),
    CardField(key: 'taskProgress',   label: 'تقدم المهمة',          category: 'performance'),
    CardField(key: 'nextJob',        label: 'المهمة القادمة',        category: 'performance'),
    CardField(key: 'nextJobCountdown',label: 'العد التنازلي',       category: 'performance'),
    CardField(key: 'loyaltyStreak',  label: 'سلسلة الولاء',         category: 'performance'),
    CardField(key: 'rebellionStatus',label: 'حالة التمرد',          category: 'performance'),
    // البيئة
    CardField(key: 'ambientLight',   label: 'الضوء المحيط',         category: 'environment'),
    CardField(key: 'lightExposure',  label: 'تعرض الضوء',           category: 'environment'),
    CardField(key: 'ambientNoise',   label: 'الضوضاء المحيطة',      category: 'environment'),
    CardField(key: 'spaceDistance',  label: 'المسافة التقريبية',     category: 'environment'),
    // نفسي / بيولوجي
    CardField(key: 'stressIndex',    label: 'مؤشر التوتر',          category: 'psych'),
    CardField(key: 'emotionalTone',  label: 'النبرة العاطفية',       category: 'psych'),
    CardField(key: 'cognitiveLoad',  label: 'الحمل المعرفي',         category: 'psych'),
    CardField(key: 'sleepDebt',      label: 'عجز النوم',            category: 'psych'),
    CardField(key: 'deceptionProbability', label: 'احتمالية الخداع',  category: 'psych'),
    CardField(key: 'emotionalVolatility',  label: 'التقلب العاطفي',   category: 'psych'),
    CardField(key: 'currentPosture', label: 'الوضعية الحالية',       category: 'psych'),
    CardField(key: 'physicalStamina',label: 'القدرة البدنية',         category: 'psych'),
    CardField(key: 'backspaceCount', label: 'عدد مسح المدخلات',      category: 'psych'),
    // مالي
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

  // الحقول المرئية الافتراضية
  static const Set<String> defaultVisible = {
    'livePulse', 'batteryPercent', 'obedienceGrade', 'rankPosition',
    'focusApp', 'taskProgress', 'antiCheatStatus', 'connectionQuality',
    'activityState', 'lastCommunication',
  };
}
