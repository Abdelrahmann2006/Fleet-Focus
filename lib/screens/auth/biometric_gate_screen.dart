import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';

/// BiometricGateScreen — بوابة المصادقة البيومترية
///
/// تُعرض تلقائياً عند كل فتح للتطبيق إذا كان المستخدم
/// قد فعّل المصادقة البيومترية (`biometricEnabled: true`).
///
/// تُطلق `localAuth.authenticate()` فور تحميل الشاشة.
/// عند النجاح → تُعلم AuthProvider → GoRouter يُعيد التوجيه تلقائياً.
class BiometricGateScreen extends StatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen>
    with SingleTickerProviderStateMixin {
  final _localAuth = LocalAuthentication();

  bool _checking = false;
  bool _failed = false;
  int _failCount = 0;
  String _errorMsg = '';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    // تأخير بسيط ثم إطلاق المصادقة تلقائياً
    Future.delayed(const Duration(milliseconds: 500), _authenticate);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_checking || !mounted) return;
    setState(() {
      _checking = true;
      _failed = false;
      _errorMsg = '';
    });

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isAvailable = await _localAuth.isDeviceSupported();

      if (!canCheck || !isAvailable) {
        // الجهاز لا يدعم البيومترية — نمرّر تلقائياً
        _onSuccess();
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'أثبت هويتك للمتابعة إلى لوحة التحكم',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        _onSuccess();
      } else {
        _onFailure('لم يتم التحقق من الهوية');
      }
    } catch (e) {
      _onFailure('خطأ في التحقق البيومتري');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _onSuccess() {
    if (!mounted) return;
    context.read<AuthProvider>().markBiometricVerified();
    // GoRouter redirect سيأخذ بالمجاز إلى الوجهة الصحيحة
  }

  void _onFailure(String msg) {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _failCount++;
      _errorMsg = msg;
    });
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060612),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── رمز البصمة المتحرك ──────────────────────────
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Transform.scale(
                    scale: _pulse.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _failed
                              ? AppColors.error.withOpacity(0.7)
                              : AppColors.accent.withOpacity(0.5),
                          width: 2,
                        ),
                        color: (_failed ? AppColors.error : AppColors.accent)
                            .withOpacity(0.07),
                      ),
                      child: Icon(
                        _failed
                            ? Icons.fingerprint
                            : Icons.fingerprint,
                        size: 64,
                        color: _failed
                            ? AppColors.error.withOpacity(0.8)
                            : AppColors.accent,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ── عنوان ─────────────────────────────────────────
                Text(
                  'التحقق من الهوية',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _failed ? AppColors.error : AppColors.textPrimary,
                    fontFamily: 'Tajawal',
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  _failed
                      ? _errorMsg
                      : _checking
                          ? 'جارٍ التحقق من هويتك...'
                          : 'استخدم بصمة الإصبع أو الوجه\nلفتح لوحة التحكم',
                  style: TextStyle(
                    fontSize: 15,
                    color: _failed
                        ? AppColors.error.withOpacity(0.8)
                        : AppColors.textSecondary,
                    fontFamily: 'Tajawal',
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // ── مؤشر التحميل أو زر إعادة المحاولة ─────────
                if (_checking)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2.5,
                    ),
                  )
                else if (_failed)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _authenticate,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: Text(
                            'إعادة المحاولة${_failCount > 1 ? ' ($_failCount)' : ''}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _signOut,
                        child: const Text(
                          'تسجيل الخروج',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // حالة الانتظار الأولية
                  GestureDetector(
                    onTap: _authenticate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        'اضغط للتحقق',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 60),

                // ── تذييل ─────────────────────────────────────
                Text(
                  'Panopticon · نظام المنافسة',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withOpacity(0.5),
                    fontFamily: 'Tajawal',
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
