import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/gold_input.dart';
import '../../widgets/gold_button.dart';

/// شاشة قفل أمان العنصر — تظهر عند كل فتح للتطبيق
/// تتطلب كلمة المرور أو البيومترية للمتابعة
class ParticipantSecurityLockScreen extends StatefulWidget {
  final String nextRoute;
  const ParticipantSecurityLockScreen({
    super.key,
    this.nextRoute = '/participant/application',
  });

  @override
  State<ParticipantSecurityLockScreen> createState() =>
      _ParticipantSecurityLockScreenState();
}

class _ParticipantSecurityLockScreenState
    extends State<ParticipantSecurityLockScreen>
    with TickerProviderStateMixin {
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _passError = false;
  String _errorMsg = '';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  late AnimationController _shakeCtrl;
  late Animation<double> _shake;

  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shake = Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);

    // محاولة بيومترية تلقائية
    if (!kIsWeb) {
      Future.delayed(const Duration(milliseconds: 600), _tryBiometric);
    }
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    if (!mounted) return;
    // محاكاة بيومترية (تعمل فقط على الجوال)
    if (kIsWeb) return;
    try {
      final user = context.read<AuthProvider>().user;
      if (user?.biometricEnabled != true) return;

      // محاولة المصادقة البيومترية
      setState(() => _loading = true);
      // على الجوال: استخدم local_auth
      // هنا نحاكي النجاح للعرض
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _onUnlocked();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyPassword() async {
    final pass = _passCtrl.text.trim();
    if (pass.isEmpty) {
      _triggerError('أدخل كلمة المرور');
      return;
    }
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString('app_password_hash') ?? '';

      if (storedHash.isEmpty) {
        // أول مرة - قبول مباشر
        _onUnlocked();
        return;
      }

      final auth = context.read<AuthProvider>();
      final ok = await auth.verifyCurrentUserPassword(pass);
      if (ok) {
        _onUnlocked();
      } else {
        setState(() => _loading = false);
        _triggerError('كلمة المرور غير صحيحة');
      }
    } catch (e) {
      setState(() => _loading = false);
      _triggerError('خطأ في التحقق، حاول مرة أخرى');
    }
  }

  void _triggerError(String msg) {
    setState(() {
      _passError = true;
      _errorMsg = msg;
    });
    _shakeCtrl.forward(from: 0);
    Future.delayed(
        const Duration(seconds: 3), () => setState(() => _passError = false));
  }

  void _onUnlocked() {
    if (!mounted) return;
    context.read<AuthProvider>().markBiometricVerified();
    context.go(widget.nextRoute);
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final hasBio = user?.biometricEnabled == true;

    return Scaffold(
      backgroundColor: const Color(0xFF060610),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // أيقونة القفل مع نبض
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Transform.scale(
                    scale: _pulse.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.2),
                            AppColors.accent.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                            color: AppColors.accent.withOpacity(0.5),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 25,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: AppColors.accent,
                        size: 48,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'بوابة أمان العنصر',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أدخل كلمة المرور أو استخدم البيومترية\nللوصول إلى النظام',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal',
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // حقل كلمة المرور مع اهتزاز عند الخطأ
                AnimatedBuilder(
                  animation: _shake,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                      _passError
                          ? 8 * (0.5 - _shake.value).abs() * 2
                          : 0,
                      0,
                    ),
                    child: child,
                  ),
                  child: GoldInput(
                    label: 'كلمة المرور',
                    controller: _passCtrl,
                    hint: 'أدخل كلمة مرور التطبيق',
                    obscureText: !_showPassword,
                    errorText: _passError ? _errorMsg : null,
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppColors.textMuted, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                    onSubmitted: (_) => _verifyPassword(),
                  ),
                ),

                const SizedBox(height: 20),

                GoldButton(
                  label: 'فتح النظام',
                  onPressed: _verifyPassword,
                  loading: _loading,
                ),

                if (hasBio && !kIsWeb) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AppColors.accent.withOpacity(0.3)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _tryBiometric,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fingerprint,
                                  color: AppColors.accent, size: 24),
                              const SizedBox(width: 10),
                              const Text(
                                'دخول بالبصمة',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                TextButton(
                  onPressed: _signOut,
                  child: const Text(
                    'تسجيل الخروج',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
