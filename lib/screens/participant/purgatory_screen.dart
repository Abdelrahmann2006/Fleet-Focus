import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';

/// شاشة المطهر — حالة الانتظار واستقبال المرسوم السيادي
class PurgatoryScreen extends StatefulWidget {
  const PurgatoryScreen({super.key});

  @override
  State<PurgatoryScreen> createState() => _PurgatoryScreenState();
}

class _PurgatoryScreenState extends State<PurgatoryScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _pulse;
  late Animation<double> _rotate;
  late Animation<double> _fade;

  final List<_Particle> _particles = List.generate(20, (_) => _Particle());

  @override
  void initState() {
    super.initState();

    // ── إعداد الأنيميشن ──────────────────────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _rotate = Tween<double>(begin: 0, end: 2 * pi).animate(_rotateCtrl);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(backgroundColor: AppColors.background);

    return Scaffold(
      backgroundColor: const Color(0xFF06060F),
      // استخدمنا StreamBuilder هنا لمراقبة التغيرات لحظياً بدلاً من _listenToStatusUpdate
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final status = data['applicationStatus'] ?? 'submitted';
          final payload = data['joinRequestPayload'] ?? ''; // الرسالة السيادية

          // 1. حالة الرفض
          if (status == 'rejected') {
            return _buildRejectedScreen();
          }

          // 2. حالة القبول المبدئي (وصول الرسالة السيادية)
          if (status == 'join_request_pending') {
            return _buildSovereignDecreeScreen(context, user.uid, payload);
          }

          // 3. حالة الانتظار الافتراضية (submitted) - نعرض فيها تصميمك المتحرك
          return _buildWaitingScreen(user.fullName?.split(' ').first ?? 'العنصر');
        },
      ),
    );
  }

  // ── شاشة عرض الرسالة السيادية وبروتوكول القبول (تنفجر فجأة للتابع) ──────────
  Widget _buildSovereignDecreeScreen(BuildContext context, String uid, String message) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                border: Border.all(color: AppColors.error),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('مرسوم وارد', style: TextStyle(color: AppColors.error, fontFamily: 'Tajawal', fontWeight: FontWeight.w900, fontSize: 18)),
                  SizedBox(width: 8),
                  Icon(Icons.warning_rounded, color: AppColors.error),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 1.5),
                  boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 20)],
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    message,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: AppColors.text, fontSize: 14, fontFamily: 'Courier', height: 1.8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'بضغطك على الزر أدناه، أنت توافق على كافة الشروط المذكورة، وسيُطلب منك فوراً إعطاء صلاحيات لنظام Panopticon.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'Tajawal', height: 1.5),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                // 1. تحديث الحالة
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'applicationStatus': 'permissions_flow_initiated',
                });
                // 2. التوجيه إلى شاشة الصلاحيات لتسليم الجهاز (تأكد أن هذا المسار صحيح في app_router.dart)
                if (context.mounted) {
                  context.go('/participant/permissions_flow'); 
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('أوافق على منح الصلاحيات',
                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );
  }

  // ── شاشة الرفض ──────────────────────────────────────────────────────────
  Widget _buildRejectedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 80, color: AppColors.error),
            const SizedBox(height: 24),
            const Text('تم رفض التماسكم', textAlign: TextAlign.center, style: TextStyle(color: AppColors.error, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
            const SizedBox(height: 16),
            const Text('لم تَرَى السيدة أنك مؤهل للانضمام. تم إدراج ملفك في الأرشيف المرفوض ولن يُسمح لك بالمحاولة مجدداً.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontFamily: 'Tajawal', height: 1.6)),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () => context.go('/participant/login'),
              child: const Text('العودة لشاشة الدخول', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
            )
          ],
        ),
      ),
    );
  }

  // ── شاشة الانتظار بالتصميم المتحرك الخاص بك ──────────────────────────────
  Widget _buildWaitingScreen(String name) {
    return Stack(
      children: [
        ..._particles.map((p) => _ParticleWidget(particle: p, ctrl: _pulseCtrl)),
        SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([_pulse, _rotate]),
                      builder: (_, __) => Transform.scale(
                        scale: _pulse.value,
                        child: SizedBox(
                          width: 130,
                          height: 130,
                          child: CustomPaint(
                            painter: _RingPainter(angle: _rotate.value),
                            child: Center(
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.accent.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                  gradient: RadialGradient(
                                    colors: [AppColors.accent.withOpacity(0.15), Colors.transparent],
                                  ),
                                ),
                                child: const Icon(Icons.hourglass_top_rounded, size: 34, color: AppColors.accent),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accent, fontFamily: 'Tajawal', letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    const Text('طلبك قيد المراجعة', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal', height: 1.3)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                      ),
                      child: const Text('وصلت الاستمارة للسيدة و هي تراجعها الآن.\n\nهذه الشاشة ستتحدث تلقائياً وبشكل مفاجئ عند البت في طلبك.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontFamily: 'Tajawal', height: 1.7)),
                    ),
                    const SizedBox(height: 32),
                    _WaitingDots(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── المكونات الفرعية (الجسيمات، الرسام، النقاط) ─────────────────────

class _Particle {
  final double x = Random().nextDouble();
  final double y = Random().nextDouble();
  final double size = Random().nextDouble() * 3 + 1;
  final double opacity = Random().nextDouble() * 0.4 + 0.05;
}

class _ParticleWidget extends StatelessWidget {
  final _Particle particle;
  final AnimationController ctrl;
  const _ParticleWidget({required this.particle, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: particle.x * MediaQuery.of(context).size.width,
      top: particle.y * MediaQuery.of(context).size.height,
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) => Opacity(
          opacity: particle.opacity * (0.5 + 0.5 * ctrl.value),
          child: Container(
            width: particle.size,
            height: particle.size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double angle;
  const _RingPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        startAngle: angle,
        endAngle: angle + pi * 1.5,
        colors: const [Colors.transparent, AppColors.accent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.angle != angle;
}

class _WaitingDots extends StatefulWidget {
  @override
  State<_WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<_WaitingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        if (_ctrl.isCompleted) {
          setState(() => _active = (_active + 1) % 3);
          _ctrl.reset();
          _ctrl.forward();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i == _active
              ? AppColors.accent
              : AppColors.accent.withOpacity(0.2),
        ),
      )),
    );
  }
}
