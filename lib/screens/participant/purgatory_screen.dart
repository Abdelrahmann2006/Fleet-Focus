import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';

/// شاشة المطهر — حالة الانتظار للمشارك قبل قبوله
///
/// مُغلقة تماماً — لا توجد أزرار للتنقل.
/// تُعرض تلقائياً عندما applicationStatus == 'pending' أو غير معروف.
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

  final List<_Particle> _particles = List.generate(
    20,
    (_) => _Particle(),
  );

  @override
  void initState() {
    super.initState();

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
    final name = user?.fullName?.split(' ').first ?? 'العنصر';

    return Scaffold(
      backgroundColor: const Color(0xFF06060F),
      body: Stack(
        children: [
          // ── خلفية جسيمات ──────────────────────────────────
          ..._particles.map((p) => _ParticleWidget(particle: p, ctrl: _pulseCtrl)),

          // ── محتوى رئيسي ───────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── رمز الانتظار المتحرك ───────────────
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

                      // ── اسم المستخدم ───────────────────────
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

                      // ── العنوان ────────────────────────────
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

                      // ── الوصف ──────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.2),
                          ),
                        ),
                        child: const Text(
                          'ملفك الشخصي وصل إلى القائد وهو يراجعه الآن.\n\nهذه الشاشة ستتحدث تلقائياً عند البت في طلبك.\nلا تغلق التطبيق.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontFamily: 'Tajawal',
                            height: 1.7,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── نقاط انتظار متحركة ─────────────────
                      _WaitingDots(),

                      const SizedBox(height: 24),

                      // ── تحذير ──────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'التطبيق في وضع القفل حتى صدور القرار',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
                      ),
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

// ── Particle ──────────────────────────────────────────────────

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

// ── Ring Painter ──────────────────────────────────────────────

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

// ── Waiting Dots ──────────────────────────────────────────────

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
