import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/approval_meta_model.dart';
import '../../providers/auth_provider.dart';

/// InterviewLockScreen — شاشة القفل المطلق وقت المقابلة (Step 4a)
///
/// تُفعَّل تلقائياً عبر InterviewAlarmReceiver (AlarmManager) أو من Firestore.
/// تحجب الجهاز بالكامل حتى تُرسل السيدة الأمر النهائي.
/// لا يوجد أي زر للخروج — لا Back، لا Home (يُمنع عبر FocusNode + WillPopScope).
class InterviewLockScreen extends StatefulWidget {
  const InterviewLockScreen({super.key});

  @override
  State<InterviewLockScreen> createState() => _InterviewLockScreenState();
}

class _InterviewLockScreenState extends State<InterviewLockScreen>
    with TickerProviderStateMixin {
  Timer? _pollingTimer;
  Timer? _pulseTimer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  late AnimationController _lockCtrl;
  late Animation<double> _lockBounce;

  @override
  void initState() {
    super.initState();

    // إخفاء شريط الحالة
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _lockCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _lockBounce = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _lockCtrl, curve: Curves.easeInOut),
    );

    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.refreshUserData();
      final status = auth.user?.applicationStatus;
      if (status == 'final_constitution_active' || status == 'approved_active') {
        if (mounted) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseCtrl.dispose();
    _lockCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = context.watch<AuthProvider>().user?.approvalMeta;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildBody(meta),
      ),
    );
  }

  Widget _buildBody(ApprovalMeta? meta) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF0A0000), Colors.black],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── أيقونة القفل ─────────────────────────────
            AnimatedBuilder(
              animation: _lockBounce,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _lockBounce.value),
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A0000),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.6), width: 2),
                      ),
                      child: const Icon(Icons.lock_outline_rounded, color: Colors.red, size: 52),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── نص القفل ─────────────────────────────────
            const Text(
              'الجهاز مقفول',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontFamily: 'Tajawal',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF0D0000),
              ),
              child: const Text(
                'جارٍ المقابلة مع السيدة\nلن يُفتح الجهاز حتى تحدد السيدة المصير النهائي',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Colors.redAccent,
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  height: 1.8,
                ),
              ),
            ),
            const SizedBox(height: 32),

            if (meta != null) ...[
              Text(
                'المقابلة: ${meta.formattedInterviewTime}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                meta.interviewLocation,
                style: const TextStyle(
                  color: Colors.white24,
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                ),
              ),
            ],

            const SizedBox(height: 48),

            // ── مؤشر الانتظار ────────────────────────────
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'في انتظار قرار السيدة...',
              style: TextStyle(
                color: Colors.white24,
                fontFamily: 'Tajawal',
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
