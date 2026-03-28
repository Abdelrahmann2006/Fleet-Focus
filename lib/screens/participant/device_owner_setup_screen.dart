import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../constants/colors.dart';
import '../../services/permission_service.dart';

/// DeviceOwnerSetupScreen — إعداد Device Owner تلقائياً
///
/// تُعرض فور قبول السيدة لطلب العنصر (قبل شاشة إعداد الجهاز).
/// الفلو:
///  1. فحص تلقائي — هل التطبيق Device Owner بالفعل؟
///  2. إذا نعم → تخطِّي مباشرةً إلى إعداد الجهاز
///  3. إذا لا → فحص حسابات Google
///  4. إذا يوجد حسابات → توجيه لحذفها + إعادة الفحص
///  5. بعد حذف الحسابات → عرض أمر ADB + استطلاع تلقائي
///  6. نجاح → شاشة "أعِد إضافة حساباتك" ثم متابعة
///  7. تخطِّي → انتقال مباشر لإعداد الجهاز (Accessibility فقط)

enum _DovState {
  checking,
  alreadyOwner,
  hasAccounts,
  awaitingAdb,
  success,
}

class DeviceOwnerSetupScreen extends StatefulWidget {
  const DeviceOwnerSetupScreen({super.key});

  @override
  State<DeviceOwnerSetupScreen> createState() => _DeviceOwnerSetupScreenState();
}

class _DeviceOwnerSetupScreenState extends State<DeviceOwnerSetupScreen>
    with SingleTickerProviderStateMixin {

  _DovState _state = _DovState.checking;
  List<String> _accounts = [];
  Timer? _pollTimer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  static const _adbCommand =
      'adb shell dpm set-device-owner com.abdelrahman.panopticon/.MyDeviceAdminReceiver';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _runInitialCheck();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _runInitialCheck() async {
    final isOwner = await PermissionService.isDeviceOwnerApp();
    if (!mounted) return;
    if (isOwner) {
      setState(() => _state = _DovState.alreadyOwner);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) _proceed();
      return;
    }
    final accounts = await PermissionService.getGoogleAccounts();
    if (!mounted) return;
    if (accounts.isNotEmpty) {
      setState(() { _state = _DovState.hasAccounts; _accounts = accounts; });
    } else {
      setState(() => _state = _DovState.awaitingAdb);
      _startPolling();
    }
  }

  Future<void> _recheckAfterAccountDeletion() async {
    setState(() => _state = _DovState.checking);
    await Future.delayed(const Duration(milliseconds: 800));
    final accounts = await PermissionService.getGoogleAccounts();
    if (!mounted) return;
    if (accounts.isNotEmpty) {
      setState(() { _state = _DovState.hasAccounts; _accounts = accounts; });
    } else {
      setState(() => _state = _DovState.awaitingAdb);
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final isOwner = await PermissionService.isDeviceOwnerApp();
      if (isOwner && mounted) {
        _pollTimer?.cancel();
        setState(() => _state = _DovState.success);
      }
    });
  }

  void _proceed() {
    if (mounted) context.go('/participant/permissions-flow');
  }

  void _skip() {
    _pollTimer?.cancel();
    _proceed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Spacer(),
          const Text(
            'تفعيل صلاحيات المالك',
            style: TextStyle(
              color: AppColors.text,
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.shield_outlined, color: AppColors.accent, size: 20),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _DovState.checking:
        return _CheckingView(pulse: _pulse);
      case _DovState.alreadyOwner:
        return _AlreadyOwnerView();
      case _DovState.hasAccounts:
        return _HasAccountsView(
          accounts: _accounts,
          onOpenSettings: () async {
            await PermissionService.openSyncSettings();
          },
          onRecheck: _recheckAfterAccountDeletion,
          onSkip: _skip,
        );
      case _DovState.awaitingAdb:
        return _AwaitingAdbView(
          adbCommand: _adbCommand,
          onSkip: _skip,
        );
      case _DovState.success:
        return _SuccessView(onContinue: _proceed);
    }
  }
}

// ─── 1. Checking ─────────────────────────────────────────────────────────────
class _CheckingView extends StatelessWidget {
  final Animation<double> pulse;
  const _CheckingView({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: pulse,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 2),
                gradient: RadialGradient(colors: [
                  AppColors.accent.withOpacity(0.2),
                  AppColors.accent.withOpacity(0.05),
                ]),
              ),
              child: const Icon(Icons.search_outlined, color: AppColors.accent, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          const Text('جارٍ الفحص...',
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 16)),
        ],
      ),
    );
  }
}

// ─── 2. Already Owner ────────────────────────────────────────────────────────
class _AlreadyOwnerView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withOpacity(0.15),
              border: Border.all(color: AppColors.success.withOpacity(0.4), width: 2),
            ),
            child: const Icon(Icons.verified_user_outlined, color: AppColors.success, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('التطبيق يعمل بصلاحيات المالك',
              style: TextStyle(color: AppColors.success, fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('جارٍ المتابعة تلقائياً...',
              style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 14)),
        ],
      ),
    );
  }
}

// ─── 3. Has Accounts ─────────────────────────────────────────────────────────
class _HasAccountsView extends StatelessWidget {
  final List<String> accounts;
  final VoidCallback onOpenSettings;
  final VoidCallback onRecheck;
  final VoidCallback onSkip;

  const _HasAccountsView({
    required this.accounts,
    required this.onOpenSettings,
    required this.onRecheck,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.4)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'لتفعيل صلاحيات المالك الكاملة، يجب حذف حسابات Google من الجهاز مؤقتاً، ثم يمكنك إعادة إضافتها بعد التفعيل.',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: AppColors.warning, fontFamily: 'Tajawal', fontSize: 13, height: 1.6),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('الحسابات المسجَّلة حالياً:',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...accounts.map((email) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Spacer(),
                Flexible(
                  child: Text(email,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 14)),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.account_circle_outlined, color: AppColors.info, size: 20),
              ],
            ),
          )),
          const SizedBox(height: 20),
          _InfoCard(
            title: 'كيفية حذف الحسابات',
            steps: const [
              'اضغط "فتح إعدادات الحسابات" أدناه',
              'اختر كل حساب Google بالتسلسل',
              'اضغط على "حذف الحساب"',
              'بعد حذف جميع الحسابات، ارجع هنا',
              'اضغط "تحققت من الحذف"',
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.settings_outlined, color: Colors.black87),
              label: const Text('فتح إعدادات الحسابات',
                  style: TextStyle(color: Colors.black87, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 15)),
              onPressed: onOpenSettings,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.success),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_outlined, color: AppColors.success, size: 18),
              label: const Text('تحققت من الحذف — متابعة',
                  style: TextStyle(color: AppColors.success, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 15)),
              onPressed: onRecheck,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: onSkip,
              child: const Text('تخطي (Accessibility فقط)',
                  style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 4. Awaiting ADB ─────────────────────────────────────────────────────────
class _AwaitingAdbView extends StatelessWidget {
  final String adbCommand;
  final VoidCallback onSkip;

  const _AwaitingAdbView({required this.adbCommand, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withOpacity(0.4)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'الحسابات محذوفة. شغِّل الأمر التالي من الكمبيوتر عبر ADB لتفعيل صلاحية المالك. التطبيق يستطلع تلقائياً كل ثانيتين.',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: AppColors.info, fontFamily: 'Tajawal', fontSize: 13, height: 1.6),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.terminal_outlined, color: AppColors.info, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('أمر ADB (انسخه في الكمبيوتر):',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: adbCommand));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم نسخ الأمر',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Tajawal')),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.copy_outlined, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      adbCommand,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontFamily: 'Courier',
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _InfoCard(
            title: 'متطلبات تشغيل الأمر',
            steps: const [
              'وصِّل الهاتف بالكمبيوتر عبر USB أو Wi-Fi',
              'فعِّل "التصحيح عبر USB" في خيارات المطور',
              'افتح موجه الأوامر أو Terminal',
              'الصق الأمر واضغط Enter',
              'التطبيق سيكتشف التفعيل تلقائياً',
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Spacer(),
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              const Text('انتظار التفعيل...',
                  style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 13)),
            ],
          ),
          const SizedBox(height: 24),

          Center(
            child: TextButton(
              onPressed: onSkip,
              child: const Text('تخطي (Accessibility فقط)',
                  style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 5. Success ───────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final VoidCallback onContinue;
  const _SuccessView({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Center(
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withOpacity(0.15),
                border: Border.all(color: AppColors.success.withOpacity(0.5), width: 2),
              ),
              child: const Icon(Icons.verified_user, color: AppColors.success, size: 44),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'تم تفعيل صلاحيات المالك',
              style: TextStyle(
                color: AppColors.success,
                fontFamily: 'Tajawal',
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('يمكنك الآن إعادة إضافة حساباتك',
                        style: TextStyle(color: AppColors.accent, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 15)),
                    SizedBox(width: 8),
                    Icon(Icons.account_circle_outlined, color: AppColors.accent, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                ...[
                  'افتح الإعدادات ← الحسابات والنسخ الاحتياطي',
                  'اضغط "إضافة حساب"',
                  'اختر Google وسجِّل دخولك كالمعتاد',
                  'كرر الخطوات لكل حساب',
                  'بياناتك لم تُمسح — فقط الارتباط أُزيل مؤقتاً',
                ].map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(s, textAlign: TextAlign.right,
                            style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13, height: 1.5)),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.circle, color: AppColors.success, size: 6),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              label: const Text('متابعة إعداد الجهاز',
                  style: TextStyle(color: Colors.black87, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 16)),
              onPressed: onContinue,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widget: Info Card ─────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String title;
  final List<String> steps;

  const _InfoCard({required this.title, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.accent, fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(e.value, textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: AppColors.text, fontFamily: 'Tajawal',
                          fontSize: 13, height: 1.5)),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withOpacity(0.15),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text('${e.key + 1}',
                        style: const TextStyle(
                            color: AppColors.accent, fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
