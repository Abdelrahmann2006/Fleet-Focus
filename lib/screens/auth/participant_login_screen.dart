import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/stage_light_background.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/gold_input.dart';
import '../../constants/colors.dart';

class ParticipantLoginScreen extends StatefulWidget {
  const ParticipantLoginScreen({super.key});

  @override
  State<ParticipantLoginScreen> createState() => _ParticipantLoginScreenState();
}

class _ParticipantLoginScreenState extends State<ParticipantLoginScreen> {
  final _codeCtrl = TextEditingController();
  final _localAuth = LocalAuthentication();

  String _step = 'login'; // 'login' | 'code' | 'biometric'
  bool _loading = false;
  bool _biometricEnabled = false;
  String? _codeError;
  Map<String, dynamic>? _validatedLeader;

  int get _stepIndex => _step == 'login' ? 0 : _step == 'code' ? 1 : 2;

  // ── تسجيل الدخول بجوجل ──────────────────────────────────────────
  Future<void> _handleGoogleLogin() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().signInWithGoogle();
      setState(() => _step = 'code');
    } catch (e) {
      _showError('فشل تسجيل الدخول بـ Google. حاول مرة أخرى.');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── التحقق من كود المعرف (PAN-ID) ──────────────────────────────
  Future<void> _handleValidateCode() async {
    final code = _codeCtrl.text.trim().toUpperCase(); // تحويل للأحرف الكبيرة تلقائياً
    if (code.isEmpty) {
      setState(() => _codeError = 'أدخل معرف الانضمام المقدم من القائد');
      return;
    }
    setState(() { _loading = true; _codeError = null; });
    try {
      final leaderData = await context.read<AuthProvider>().validateLeaderCode(code);
      if (leaderData == null) {
        setState(() => _codeError = 'المعرف غير صحيح أو منتهي الصلاحية');
        return;
      }
      _validatedLeader = leaderData;
      setState(() => _step = 'biometric');
    } catch (e) {
      setState(() => _codeError = 'خطأ في التحقق من المعرف');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── تفعيل البصمة ──────────────────────────────────────────────
  Future<void> _handleBiometricToggle() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!canCheck) { 
      setState(() => _biometricEnabled = !_biometricEnabled); 
      return; 
    }
    if (!_biometricEnabled) {
      final ok = await _localAuth.authenticate(
        localizedReason: 'تأكيد الهوية لتفعيل البيومترية',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (ok) setState(() => _biometricEnabled = true);
    } else {
      setState(() => _biometricEnabled = false);
    }
  }

  // ── إتمام الإعداد ──────────────────────────────────────────────
  Future<void> _handleFinishSetup() async {
    if (_validatedLeader == null) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().setupParticipantAccount(
        leaderCode: _codeCtrl.text.trim().toUpperCase(),
        leaderUid: _validatedLeader!['leaderUid'],
        biometricEnabled: _biometricEnabled,
      );
      if (mounted) context.go('/participant/device-setup');
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

  void _goBack() {
    if (_step == 'biometric') setState(() => _step = 'code');
    else if (_step == 'code') setState(() => _step = 'login');
    else context.pop();
  }

  String get _title => _step == 'login' ? 'دخول المتسابق' : _step == 'code' ? 'معرف الانضمام' : 'الإعداد النهائي';
  String get _subtitle => _step == 'login'
      ? 'سجّل دخولك للمشاركة في المنافسة'
      : _step == 'code'
          ? 'أدخل المعرف (ID) المقدم لك من قائدك'
          : 'اختر خيارات الأمان وابدأ ملء الاستمارة';

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

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
                children: [
                  const SizedBox(height: 16),
                  // Header Navigation & Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      Row(
                        children: List.generate(3, (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _stepIndex ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i <= _stepIndex ? AppColors.accent : AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward, color: AppColors.textSecondary),
                        onPressed: _goBack,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  // Icon
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.accent.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.person_outline, size: 38, color: AppColors.accent),
                  ),

                  const SizedBox(height: 20),
                  Text(_title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
                  const SizedBox(height: 8),
                  Text(_subtitle, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
                  const SizedBox(height: 36),

                  // STEP 1: Login
                  if (_step == 'login') ...[
                    _GoogleSignInButtonSimple(loading: _loading, onTap: _handleGoogleLogin),
                  ],

                  // STEP 2: Alphanumeric Code Input (UPDATED)
                  if (_step == 'code') ...[
                    GoldInput(
                      label: 'معرف الانضمام (ID)',
                      controller: _codeCtrl,
                      hint: 'مثال: PAN-A1B2C3',
                      errorText: _codeError,
                      // التعديل هنا: يقبل حروف وأرقام الآن
                      keyboardType: TextInputType.text,
                      maxLength: 10,
                      prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textMuted, size: 18),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: AppColors.accent),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('أدخل المعرف الرسمي الصادر لك. المعرف يحتوي على حروف وأرقام.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Tajawal'),
                                textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GoldButton(label: 'التحقق من المعرف', onPressed: _handleValidateCode, loading: _loading),
                  ],

                  // STEP 3: Biometrics
                  if (_step == 'biometric') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.success.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_validatedLeader?['leaderName'] ?? 'القائد المعتمد',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text, fontFamily: 'Tajawal')),
                                Text('كود الارتباط: ${_codeCtrl.text.trim().toUpperCase()}',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'Tajawal')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _BiometricRow(enabled: _biometricEnabled, onToggle: _handleBiometricToggle),
                    const SizedBox(height: 20),
                    GoldButton(label: 'البدء بملء الاستمارة', onPressed: _handleFinishSetup, loading: _loading),
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

// ── Google Sign In Button ──────────────────────────────────────
class _GoogleSignInButtonSimple extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleSignInButtonSimple({required this.loading, required this.onTap});

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
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent))
            else ...[
              Container(width: 30, height: 30, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Center(child: Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4285F4))))),
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

// ── Biometric Toggle Row ───────────────────────────────────────
class _BiometricRow extends StatelessWidget {
  final bool enabled;
  final VoidCallback onToggle;
  const _BiometricRow({required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Switch(value: enabled, onChanged: (_) => onToggle(), activeColor: AppColors.accent),
          const Spacer(),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('تفعيل البصمة / الوجه', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontFamily: 'Tajawal', fontSize: 14)),
              Text('لزيادة أمان الوصول للنظام', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
            ],
          ),
          const SizedBox(width: 12),
          const Icon(Icons.fingerprint, color: AppColors.accent, size: 24),
        ],
      ),
    );
  }
}
