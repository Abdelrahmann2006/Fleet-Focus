import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';

[span_4](start_span)/// شاشة المطهر — حالة الانتظار للمشارك قبل قبوله[span_4](end_span)
class PurgatoryScreen extends StatefulWidget {
  const PurgatoryScreen({super.key});

  @override
  State<PurgatoryScreen> createState() => _PurgatoryScreenState();
}

class _PurgatoryScreenState extends State<PurgatoryScreen>
    with TickerProviderStateMixin {
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

    [span_5](start_span)// ── إعداد الأنيميشن ──────────────────────────────────[span_5](end_span)
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

    // 📡 البدء في مراقبة حالة الطلب للانتقال التلقائي
    _listenToStatusUpdate();
  }

  /// مستمع لمراقبة تغيير حالة applicationStatus في Firestore
  void _listenToStatusUpdate() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      if (snap.exists && mounted) {
        final status = snap.data()?['applicationStatus'];

        [span_6](start_span)// إذا وافقت السيدة، يتم توجيه العنصر لمرسوم القبول[span_6](end_span)
        if (status == 'approved') {
          context.go('/onboarding/countdown');
        } 
        // إذا تم الرفض، يعود لشاشة الدخول
        else if (status == 'rejected') {
          context.go('/participant/login');
        }
      }
    });
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
    final name = user?.fullName?.split(' ').first ?? 'العنصر';

    return Scaffold(
      backgroundColor: const Color(0xFF06060F),
      body: Stack(
        children: [
          [span_7](start_span)// ── خلفية الجسيمات المتحركة ─────────────────────────[span_7](end_span)
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
                      [span_8](start_span)// ── أيقونة الانتظار الذهبية ────────────────────[span_8](end_span)
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
                                      colors: [
                                        AppColors.accent.withOpacity(0.15),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.hourglass_top_rounded,
                                    size: 34,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      [span_9](start_span)// ── اسم العنصر ───────────────────────────[span_9](end_span)
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          fontFamily: 'Tajawal',
                          letterSpacing: 1.2,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'طلبك قيد المراجعة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          fontFamily: 'Tajawal',
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── وصف الحالة المحدث ───────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.2),
                          ),
                        ),
                        child: const Text(
                          'وصل للسيدة و هي تراجعه الآن.\n\nهذه الشاشة ستتحدث تلقائياً عند البت في طلبك.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            fontFamily: 'Tajawal',
                            height: 1.7,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      [span_10](start_span)// ── نقاط الانتظار ─────────────────────────[span_10](end_span)
                      _WaitingDots(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

[span_11](start_span)// ── المكونات الفرعية (الجسيمات، الرسام، النقاط) ─────────────────────[span_11](end_span)

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

class _WaitingDotsState extends State<_WaitingDots>
    with SingleTickerProviderStateMixin {
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
