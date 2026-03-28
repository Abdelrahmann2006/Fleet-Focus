import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';

/// DyingRitualScreen — طقس الرحيل الرقمي
///
/// يُعرض عند خروج المشارك النهائي من النظام.
/// عداد 10 ثوانٍ + تحلّل رمز العين التدريجي + رسالة الوداع.
/// بعد الانتهاء: يُسجَّل الخروج ويُحوَّل إلى '/'.
class DyingRitualScreen extends StatefulWidget {
  const DyingRitualScreen({super.key});

  @override
  State<DyingRitualScreen> createState() => _DyingRitualScreenState();
}

class _DyingRitualScreenState extends State<DyingRitualScreen>
    with TickerProviderStateMixin {
  static const _totalSeconds = 10;

  int _remaining = _totalSeconds;
  Timer? _countdown;
  bool _signedOut = false;

  // ── حركة التحلّل ─────────────────────────────────────────────
  late AnimationController _dissolveCtrl;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late Animation<double> _rotation;

  // ── جسيمات التشتّت ──────────────────────────────────────────
  final List<_RitualParticle> _particles =
      List.generate(28, (_) => _RitualParticle());

  // ── نص الرسالة ────────────────────────────────────────────────
  late AnimationController _textCtrl;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    _dissolveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalSeconds),
    );
    _opacity  = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dissolveCtrl, curve: Curves.easeIn),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _dissolveCtrl, curve: Curves.easeInOut),
    );
    _rotation = Tween<double>(begin: 0, end: pi * 2).animate(
      CurvedAnimation(parent: _dissolveCtrl, curve: Curves.easeIn),
    );

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);

    _dissolveCtrl.forward();
    _startCountdown();
  }

  void _startCountdown() {
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _performSignOut();
      }
    });
  }

  Future<void> _performSignOut() async {
    if (_signedOut) return;
    _signedOut = true;
    await context.read<AuthProvider>().signOut();
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _dissolveCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (_remaining / _totalSeconds);

    return Scaffold(
      backgroundColor: const Color(0xFF030308),
      body: Stack(
        children: [
          // ── جسيمات تتساقط ──────────────────────────────────
          ..._particles.map((p) => _ParticleWidget(particle: p, progress: progress)),

          // ── محتوى مركزي ─────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── رمز العين يتحلّل ──────────────────────────
                AnimatedBuilder(
                  animation: _dissolveCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _opacity.value,
                    child: Transform.scale(
                      scale: _scale.value,
                      child: Transform.rotate(
                        angle: _rotation.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.error.withOpacity(
                                  _opacity.value * 0.6),
                              width: 1.5,
                            ),
                            color: AppColors.error.withOpacity(
                                _opacity.value * 0.05),
                          ),
                          child: CustomPaint(
                            painter: _EyePainter(
                              opacity: _opacity.value,
                              progress: progress,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // ── عداد تنازلي ────────────────────────────────
                Text(
                  '$_remaining',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: _remaining <= 3
                        ? AppColors.error
                        : AppColors.accent.withOpacity(0.9),
                    fontFamily: 'Tajawal',
                    height: 1,
                  ),
                ),

                const SizedBox(height: 16),

                // ── رسالة الرحيل ──────────────────────────────
                FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      Text(
                        'انتهت رحلتك',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary.withOpacity(0.85),
                          fontFamily: 'Tajawal',
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'جارٍ محو سجلّك الرقمي...',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textMuted.withOpacity(0.7),
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 56),

                // ── شريط تقدم التحلّل ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.border.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.lerp(AppColors.accent, AppColors.error, progress)!,
                      ),
                      minHeight: 3,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'سيُحوَّل النظام تلقائياً خلال $_remaining ثانية',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withOpacity(0.5),
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── رسام العين ────────────────────────────────────────────────────

class _EyePainter extends CustomPainter {
  final double opacity;
  final double progress;
  const _EyePainter({required this.opacity, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppColors.error.withOpacity(opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // رمز العين المركزية
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.65,
        height: size.height * 0.32,
      ),
      paint,
    );

    // بؤبؤ العين يتقلّص
    final pupilRadius = (size.width * 0.14) * (1 - progress * 0.9);
    canvas.drawCircle(
      center,
      pupilRadius,
      Paint()
        ..color = AppColors.error.withOpacity(opacity * 0.6)
        ..style = PaintingStyle.fill,
    );

    // خطوط إشعاعية تتلاشى
    final linePaint = Paint()
      ..color = AppColors.error.withOpacity(opacity * 0.3)
      ..strokeWidth = 0.8;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      canvas.drawLine(
        center + Offset(cos(angle) * 32, sin(angle) * 32),
        center + Offset(cos(angle) * 52, sin(angle) * 52),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_EyePainter old) =>
      old.opacity != opacity || old.progress != progress;
}

// ── جسيمة التشتّت ─────────────────────────────────────────────────

class _RitualParticle {
  final double startX;
  final double startY;
  final double angle;
  final double speed;
  final double size;
  final Color color;

  _RitualParticle()
      : startX = Random().nextDouble(),
        startY = Random().nextDouble(),
        angle = Random().nextDouble() * 2 * pi,
        speed = 0.3 + Random().nextDouble() * 0.5,
        size = 1.5 + Random().nextDouble() * 3,
        color = Color.lerp(
          AppColors.error,
          AppColors.accent,
          Random().nextDouble(),
        )!;
}

class _ParticleWidget extends StatelessWidget {
  final _RitualParticle particle;
  final double progress;
  const _ParticleWidget({required this.particle, required this.progress});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dx = particle.startX * size.width +
        cos(particle.angle) * particle.speed * progress * 200;
    final dy = particle.startY * size.height +
        sin(particle.angle) * particle.speed * progress * 200;

    return Positioned(
      left: dx,
      top: dy,
      child: Opacity(
        opacity: (1 - progress) * 0.6,
        child: Container(
          width: particle.size,
          height: particle.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: particle.color,
          ),
        ),
      ),
    );
  }
}
