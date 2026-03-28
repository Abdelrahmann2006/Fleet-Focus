import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/stage_light_background.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/gold_input.dart';
import '../../constants/colors.dart';

class LeaderLoginScreen extends StatefulWidget {
  const LeaderLoginScreen({super.key});

  @override
  State<LeaderLoginScreen> createState() => _LeaderLoginScreenState();
}

class _LeaderLoginScreenState extends State<LeaderLoginScreen> {
  final _fullNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _localAuth = LocalAuthentication();

  String _step = 'login'; // 'login' | 'setup'
  bool _loading = false;
  bool _biometricEnabled = false;
  Map<String, String?> _errors = {};

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

  Future<void> _handleBiometricToggle() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!canCheck) {
      _showError('جهازك لا يدعم المصادقة البيومترية');
      return;
    }
    if (!_biometricEnabled) {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'تأكيد الهوية لتفعيل البيومترية',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (authenticated) setState(() => _biometricEnabled = true);
    } else {
      setState(() => _biometricEnabled = false);
    }
  }

  bool _validate() {
    final errs = <String, String?>{};
    if (_fullNameCtrl.text.trim().isEmpty) errs['fullName'] = 'الاسم الكامل مطلوب';
    if (_passwordCtrl.text.length < 6) errs['password'] = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    if (_passwordCtrl.text != _confirmCtrl.text) errs['confirm'] = 'كلمتا المرور غير متطابقتين';
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
      SnackBar(content: Text(msg, textAlign: TextAlign.right), backgroundColor: AppColors.error),
    );
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const StageLightBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward, color: AppColors.textSecondary),
                      onPressed: () => _step == 'setup'
                          ? setState(() => _step = 'login')
                          : context.pop(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Icon
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: AppGradients.goldGradientVertical,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: AppColors.accent.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: const Icon(Icons.shield_outlined, size: 38, color: AppColors.background),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    _step == 'login' ? 'دخول القائد' : 'إعداد الحساب',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _step == 'login'
                        ? 'سجّل دخولك بحساب Google لإدارة المتسابقين'
                        : 'أكمل معلوماتك لبدء الإدارة',
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontFamily: 'Tajawal'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  if (_step == 'login') ...[
                    _GoogleSignInButton(loading: _loading, onTap: _handleGoogleLogin),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 14, color: AppColors.accent),
                        SizedBox(width: 6),
                        Text('اتصال آمن ومشفر عبر OAuth 2.0',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
                      ],
                    ),
                  ] else ...[
                    GoldInput(label: 'الاسم الكامل', controller: _fullNameCtrl,
                        hint: 'أدخل اسمك الكامل', errorText: _errors['fullName'],
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.textMuted, size: 18)),
                    const SizedBox(height: 16),
                    GoldInput(label: 'كلمة مرور التطبيق', controller: _passwordCtrl,
                        hint: '6 أحرف على الأقل', obscureText: true, errorText: _errors['password'],
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18)),
                    const SizedBox(height: 16),
                    GoldInput(label: 'تأكيد كلمة المرور', controller: _confirmCtrl,
                        hint: 'أعد إدخال كلمة المرور', obscureText: true, errorText: _errors['confirm'],
                        prefixIcon: const Icon(Icons.check_circle_outline, color: AppColors.textMuted, size: 18)),
                    const SizedBox(height: 16),

                    // Biometric toggle
                    _BiometricToggle(
                      enabled: _biometricEnabled,
                      onToggle: _handleBiometricToggle,
                    ),
                    const SizedBox(height: 24),
                    GoldButton(label: 'إنشاء حساب القائد', onPressed: _handleSetup, loading: _loading),
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
              const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent))
            else ...[
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Center(child: Text('G',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4285F4)))),
              ),
              const SizedBox(width: 14),
              const Text('تسجيل الدخول بـ Google',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text, fontFamily: 'Tajawal')),
            ],
          ],
        ),
      ),
    );
  }
}

class _BiometricToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onToggle;
  const _BiometricToggle({required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? AppColors.accent.withOpacity(0.05) : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? AppColors.accent.withOpacity(0.4) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Switch(
              value: enabled,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('المصادقة البيومترية',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: enabled ? AppColors.accent : AppColors.text,
                        fontFamily: 'Tajawal',
                      )),
                  const Text('بصمة الإصبع أو الوجه',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'Tajawal')),
                ],
              ),
            ),
            Icon(Icons.fingerprint, color: enabled ? AppColors.accent : AppColors.textMuted, size: 24),
          ],
        ),
      ),
    );
  }
}
