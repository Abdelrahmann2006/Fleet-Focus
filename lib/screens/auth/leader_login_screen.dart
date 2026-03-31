import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/gold_input.dart';

class LeaderLoginScreen extends StatefulWidget {
  const LeaderLoginScreen({super.key});

  @override
  State<LeaderLoginScreen> createState() => _LeaderLoginScreenState();
}

class _LeaderLoginScreenState extends State<LeaderLoginScreen>
    with SingleTickerProviderStateMixin {
  final _fullNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  late AnimationController _eyeCtrl;
  late Animation<double> _eyeMove;

  String _step = 'login'; // 'login' | 'setup'
  bool _loading = false;
  bool _biometricEnabled = false;
  bool _bioFace = false;
  bool _bioFinger = false;
  Map<String, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _eyeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _eyeMove = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _eyeCtrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _eyeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().signInWithGoogle();
      setState(() => _step = 'setup');
    } catch (e) {
      _showError('فشل تسجيل الدخول بـ Google. حاول مرة أخرى.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showBiometricOptions() async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.backgroundCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'تسجيل البيومترية',
            style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                fontSize: 18),
            textAlign: TextAlign.right,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اختر طرق التحقق التي تريد تسجيلها:',
                style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.textSecondary,
                    fontSize: 14),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 16),
              // بصمة الوجه
              _BiometricOption(
                icon: Icons.face_retouching_natural,
                label: 'بصمة الوجه',
                subtitle: 'التعرف على الوجه بالكاميرا',
                selected: _bioFace,
                onTap: () => setS(() => _bioFace = !_bioFace),
              ),
              const SizedBox(height: 10),
              // بصمة الإصبع
              _BiometricOption(
                icon: Icons.fingerprint,
                label: 'بصمة الإصبع',
                subtitle: 'مستشعر البصمة على الجهاز',
                selected: _bioFinger,
                onTap: () => setS(() => _bioFinger = !_bioFinger),
              ),
              const SizedBox(height: 20),
              if (!kIsWeb)
                Text(
                  'ملاحظة: يجب أن يكون الجهاز يدعم هذه الميزات',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (kIsWeb)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'البيومترية تعمل على تطبيق الجوال فقط',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.warning,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(
                      fontFamily: 'Tajawal', color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _biometricEnabled = _bioFace || _bioFinger;
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('حفظ',
                  style: TextStyle(
                      fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  bool _validate() {
    final errs = <String, String?>{};
    if (_fullNameCtrl.text.trim().isEmpty)
      errs['fullName'] = 'الاسم الكامل مطلوب';
    if (_passwordCtrl.text.length < 6)
      errs['password'] = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    if (_passwordCtrl.text != _confirmCtrl.text)
      errs['confirm'] = 'كلمتا المرور غير متطابقتين';
    setState(() => _errors = errs);
    return errs.isEmpty;
  }

  Future<void> _handleSetup() async {
    if (!_validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().setupLeaderAccount(
        fullName: _fullNameCtrl.text.trim(),
        appPassword: _passwordCtrl.text,
        biometricEnabled: _biometricEnabled,
        bioFace: _bioFace,
        bioFinger: _bioFinger,
      );
      if (mounted) context.go('/leader/dashboard');
    } catch (e) {
      _showError('حدث خطأ أثناء الإعداد. حاول مرة أخرى.');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg, textAlign: TextAlign.right),
          backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060610),
      body: Stack(
        children: [
          // خلفية مضيئة
          Positioned(
            top: -100,
            left: 0,
            right: 0,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.15),
                    Colors.transparent,
                  ],
                  radius: 1.0,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  // زر الرجوع
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward,
                          color: AppColors.textSecondary),
                      onPressed: () => _step == 'setup'
                          ? setState(() => _step = 'login')
                          : context.pop(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // عنوان البوابة
                  const Text(
                    'بوابة دخول السيدة',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontFamily: 'Tajawal',
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // أيقونة العين مع حركة
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.5), width: 2),
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accent.withOpacity(0.2),
                          AppColors.accent.withOpacity(0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 25,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _eyeMove,
                        builder: (_, __) => CustomPaint(
                          size: const Size(52, 28),
                          painter: _MiniEyePainter(
                              pupilOffset: _eyeMove.value * 0.6),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    _step == 'login' ? 'السيدة' : 'إعداد الحساب',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        fontFamily: 'Tajawal'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _step == 'login'
                        ? 'سجّلي دخولك للوصول إلى نظام السيطرة'
                        : 'أكملي معلوماتك لبدء الإدارة',
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontFamily: 'Tajawal'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  if (_step == 'login') ...[
                    _GoogleSignInButton(
                        loading: _loading, onTap: _handleGoogleLogin),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 13, color: AppColors.accent.withOpacity(0.7)),
                        const SizedBox(width: 6),
                        const Text(
                          'اتصال آمن ومشفر عبر OAuth 2.0',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontFamily: 'Tajawal'),
                        ),
                      ],
                    ),
                  ] else ...[
                    GoldInput(
                      label: 'الاسم الكامل (سيظهر في النظام)',
                      controller: _fullNameCtrl,
                      hint: 'أدخلي اسمك الكامل',
                      errorText: _errors['fullName'],
                      prefixIcon: const Icon(Icons.person_outline,
                          color: AppColors.textMuted, size: 18),
                    ),
                    const SizedBox(height: 16),
                    GoldInput(
                      label: 'كلمة مرور التطبيق',
                      controller: _passwordCtrl,
                      hint: '6 أحرف على الأقل',
                      obscureText: true,
                      errorText: _errors['password'],
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.textMuted, size: 18),
                    ),
                    const SizedBox(height: 16),
                    GoldInput(
                      label: 'تأكيد كلمة المرور',
                      controller: _confirmCtrl,
                      hint: 'أعيدي إدخال كلمة المرور',
                      obscureText: true,
                      errorText: _errors['confirm'],
                      prefixIcon: const Icon(Icons.check_circle_outline,
                          color: AppColors.textMuted, size: 18),
                    ),
                    const SizedBox(height: 20),

                    // زر البيومترية
                    GestureDetector(
                      onTap: _showBiometricOptions,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _biometricEnabled
                              ? AppColors.accent.withOpacity(0.08)
                              : AppColors.backgroundCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _biometricEnabled
                                ? AppColors.accent.withOpacity(0.4)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _biometricEnabled
                                    ? AppColors.accent.withOpacity(0.15)
                                    : AppColors.backgroundElevated,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.security,
                                color: _biometricEnabled
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _biometricEnabled
                                        ? 'البيومترية مُفعَّلة ✓'
                                        : 'تفعيل التحقق البيومتري',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _biometricEnabled
                                          ? AppColors.accent
                                          : AppColors.text,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                  Text(
                                    _biometricEnabled
                                        ? [
                                            if (_bioFace) 'بصمة الوجه',
                                            if (_bioFinger) 'بصمة الإصبع',
                                          ].join(' + ')
                                        : 'اضغط لتسجيل بصمة الوجه أو الإصبع',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        fontFamily: 'Tajawal'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    GoldButton(
                        label: 'إنشاء حساب السيدة',
                        onPressed: _handleSetup,
                        loading: _loading),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Google Sign In ──────────────────────────────────────────────
class _GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleSignInButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.accent))
            else ...[
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Center(
                    child: Text('G',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4285F4)))),
              ),
              const SizedBox(width: 14),
              const Text('تسجيل الدخول بـ Google',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                      fontFamily: 'Tajawal')),
            ],
          ],
        ),
      ),
    );
  }
}

// ── خيار بيومتري واحد ───────────────────────────────────────────
class _BiometricOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _BiometricOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withOpacity(0.1)
              : AppColors.backgroundElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected ? AppColors.accent : AppColors.border.withOpacity(0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.accent : Colors.transparent,
                border: Border.all(
                    color: selected ? AppColors.accent : AppColors.textMuted,
                    width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.accent : AppColors.text,
                        fontSize: 15,
                      )),
                  Text(subtitle,
                      style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.textMuted,
                          fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon,
                color: selected ? AppColors.accent : AppColors.textMuted,
                size: 28),
          ],
        ),
      ),
    );
  }
}

// ── رسام العين الصغيرة ──────────────────────────────────────────
class _MiniEyePainter extends CustomPainter {
  final double pupilOffset;
  const _MiniEyePainter({required this.pupilOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final eyePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(0, cy);
    path.quadraticBezierTo(cx, -size.height * 0.6, size.width, cy);
    path.quadraticBezierTo(cx, size.height * 1.6, 0, cy);
    canvas.drawPath(path, eyePaint);
    final fillPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
    final px = (cx + pupilOffset).clamp(8.0, size.width - 8.0);
    final glowPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(px, cy), 9, glowPaint);
    canvas.drawCircle(
        Offset(px, cy),
        7,
        Paint()
          ..color = AppColors.accent.withOpacity(0.7)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(px, cy),
        4,
        Paint()
          ..color = const Color(0xFF060610)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(px - 1.5, cy - 1.5),
        1.5,
        Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_MiniEyePainter old) => old.pupilOffset != pupilOffset;
}
