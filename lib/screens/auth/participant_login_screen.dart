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

  Future<void> _handleValidateCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _codeError = 'أدخل الكود المقدم من القائد');
      return;
    }
    setState(() { _loading = true; _codeError = null; });
    try {
      final leaderData = await context.read<AuthProvider>().validateLeaderCode(code);
      if (leaderData == null) {
        setState(() => _codeError = 'الكود غير صحيح أو منتهي الصلاحية');
        return;
      }
      _validatedLeader = leaderData;
      setState(() => _step = 'biometric');
    } catch (e) {
      setState(() => _codeError = 'خطأ في التحقق من الكود');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleBiometricToggle() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!canCheck) { setState(() => _biometricEnabled = !_biometricEnabled); return; }
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
      _showError('حدث خطأ. حاول مرة أخرى.');
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

  String get _title => _step == 'login' ? 'دخول المتسابق' : _step == 'code' ? 'كود القائد' : 'الإعداد النهائي';
  String get _subtitle => _step == 'login'
      ? 'سجّل دخولك للمشاركة في المنافسة'
      : _step == 'code'
          ? 'أدخل الكود المقدم لك من قائدك'
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      // Progress dots
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
                  Text(_title,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
                  const SizedBox(height: 8),
                  Text(_subtitle,
                      style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontFamily: 'Tajawal'),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 36),

                  if (_step == 'login') ...[
                    _GoogleSignInButtonSimple(loading: _loading, onTap: _handleGoogleLogin),
                  ],

                  if (_step == 'code') ...[
                    GoldInput(
                      label: 'كود القائد',
                      controller: _codeCtrl,
                      hint: 'مثال: L-ABC123',
                      errorText: _codeError,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 9,
                      prefixIcon: const Icon(Icons.key_outlined, color: AppColors.textMuted, size: 18),
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
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('الكود يبدأ بـ L- ويتكون من 8 أحرف. اطلبه من قائدك.',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal'),
                                textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GoldButton(label: 'التحقق من الكود', onPressed: _handleValidateCode, loading: _loading),
                  ],

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
                                Text(_validatedLeader?['leaderName'] ?? '',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text, fontFamily: 'Tajawal')),
                                Text('كود: ${_codeCtrl.text.trim().toUpperCase()}',
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
              Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Center(child: Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4285F4))))),
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

class _BiometricRow extends StatelessWidget {
  final bool enabled;
  final VoidCallback onToggle;
  const _BiometricRow({required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? AppColors.accent.withOpacity(0.05) : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: enabled ? AppColors.accent.withOpacity(0.4) : AppColors.border),
        ),
        child: Row(
          children: [
            Switch(value: enabled, onChanged: (_) => onToggle(), activeColor: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('المصادقة البيومترية',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: enabled ? AppColors.accent : AppColors.text, fontFamily: 'Tajawal')),
                const Text('بصمة الإصبع أو الوجه (اختياري)',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'Tajawal')),
              ]),
            ),
            Icon(Icons.fingerprint, color: enabled ? AppColors.accent : AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
