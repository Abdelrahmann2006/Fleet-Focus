import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _buttonsController;
  late AnimationController _eyeController;
  late AnimationController _lightController;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoY;
  late Animation<double> _buttonsOpacity;
  late Animation<double> _buttonsY;
  late Animation<double> _eyeMove;
  late Animation<double> _lightAngle;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _buttonsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _eyeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _lightController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoY = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _buttonsOpacity =
        Tween<double>(begin: 0, end: 1).animate(_buttonsController);
    _buttonsY = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _buttonsController, curve: Curves.easeOut),
    );
    // حركة العين يمين ويسار
    _eyeMove = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _eyeController, curve: Curves.easeInOutSine),
    );
    // زاوية الضوء النازل
    _lightAngle = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(parent: _lightController, curve: Curves.easeInOutSine),
    );
    // نبض الأيقونة
    _pulse = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      _logoController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _buttonsController.forward();
        });
      });
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _buttonsController.dispose();
    _eyeController.dispose();
    _lightController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoading && auth.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final role = auth.user?.role;
        if (role == 'leader') context.go('/leader/dashboard');
        if (role == 'participant') context.go('/participant/home');
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060610),
      body: Stack(
        children: [
          // خلفية نجوم ونقاط خفيفة
          const _StarfieldBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // الشعار الرئيسي
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _logoY.value),
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        const Text(
                          'Panopticon',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                            fontFamily: 'Tajawal',
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'نظام السيطرة والمراقبة',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontFamily: 'Tajawal',
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // أيقونة العين الرئيسية مع نبض
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) => Transform.scale(
                            scale: _pulse.value,
                            child: _EyeIcon(eyeMove: _eyeMove),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // أزرار الدخول
                  AnimatedBuilder(
                    animation: _buttonsController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _buttonsY.value),
                        child: Opacity(
                            opacity: _buttonsOpacity.value, child: child),
                      );
                    },
                    child: Column(
                      children: [
                        // ── بوابة دخول السيدة (مع عين متحركة وضوء نازل) ──
                        _LeaderGateButton(
                          eyeMove: _eyeMove,
                          lightAngle: _lightAngle,
                          onTap: () => context.push('/auth/leader'),
                        ),
                        const SizedBox(height: 16),
                        // ── بوابة دخول العنصر ──
                        _ElementGateButton(
                          onTap: () => context.push('/auth/participant'),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // نص تذييل
                  Text(
                    'نظام مشفّر · اتصال آمن',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted.withOpacity(0.4),
                      fontFamily: 'Tajawal',
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── أيقونة العين الرئيسية ────────────────────────────────────────
class _EyeIcon extends StatelessWidget {
  final Animation<double> eyeMove;
  const _EyeIcon({required this.eyeMove});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.accent.withOpacity(0.2),
            AppColors.accent.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
        border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: eyeMove,
          builder: (_, __) => CustomPaint(
            size: const Size(70, 40),
            painter: _EyePainter(pupilOffset: eyeMove.value),
          ),
        ),
      ),
    );
  }
}

// ── رسام العين ──────────────────────────────────────────────────
class _EyePainter extends CustomPainter {
  final double pupilOffset;
  const _EyePainter({required this.pupilOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // شكل العين (قوس)
    final eyePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final eyePath = Path();
    eyePath.moveTo(0, cy);
    eyePath.quadraticBezierTo(cx, -size.height * 0.6, size.width, cy);
    eyePath.quadraticBezierTo(cx, size.height * 1.6, 0, cy);
    canvas.drawPath(eyePath, eyePaint);

    // حشو شفاف خفيف
    final fillPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    canvas.drawPath(eyePath, fillPaint);

    // البؤبؤ (يتحرك)
    final clampedOffset = pupilOffset.clamp(-10.0, 10.0);
    final pupilX = cx + clampedOffset;

    // هالة البؤبؤ
    final glowPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(pupilX, cy), 12, glowPaint);

    // البؤبؤ الخارجي
    final outerPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pupilX, cy), 10, outerPaint);

    // البؤبؤ الداخلي
    final innerPaint = Paint()
      ..color = const Color(0xFF060610)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pupilX, cy), 6, innerPaint);

    // لمعة صغيرة
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pupilX - 2, cy - 2), 2, shinePaint);
  }

  @override
  bool shouldRepaint(_EyePainter old) => old.pupilOffset != pupilOffset;
}

// ── بوابة دخول السيدة ────────────────────────────────────────────
class _LeaderGateButton extends StatelessWidget {
  final Animation<double> eyeMove;
  final Animation<double> lightAngle;
  final VoidCallback onTap;
  const _LeaderGateButton({
    required this.eyeMove,
    required this.lightAngle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent,
              const Color(0xFFB8860B),
              AppColors.accent.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ضوء نازل من الأيقونة
              AnimatedBuilder(
                animation: lightAngle,
                builder: (_, __) => Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Transform.rotate(
                    angle: lightAngle.value,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // محتوى الزر
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Row(
                  children: [
                    const Icon(Icons.chevron_left,
                        color: Color(0xFF1A0A00), size: 22),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'بوابة دخول السيدة',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A0A00),
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const Text(
                          'إدارة العناصر والسيطرة الكاملة',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0x991A0A00),
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // أيقونة عين متحركة في الزر
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: AnimatedBuilder(
                          animation: eyeMove,
                          builder: (_, __) => CustomPaint(
                            size: const Size(36, 20),
                            painter: _EyePainter(
                              pupilOffset: eyeMove.value * 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── بوابة دخول العنصر ────────────────────────────────────────────
class _ElementGateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ElementGateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(
          children: [
            const Icon(Icons.chevron_left,
                color: AppColors.textMuted, size: 22),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'بوابة دخول العنصر',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    fontFamily: 'Tajawal',
                  ),
                ),
                Text(
                  'الانضمام وملء استمارة الولاء',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: const Icon(Icons.fingerprint,
                  color: AppColors.accent, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

// ── خلفية النجوم ─────────────────────────────────────────────────
class _StarfieldBackground extends StatelessWidget {
  const _StarfieldBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _StarsPainter(),
    );
  }
}

class _StarsPainter extends CustomPainter {
  static final _rng = Random(42);
  static final _stars = List.generate(80, (i) => [
        _rng.nextDouble(),
        _rng.nextDouble(),
        _rng.nextDouble() * 1.5 + 0.5,
      ]);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in _stars) {
      paint.color = AppColors.accent.withOpacity(s[2] * 0.15);
      canvas.drawCircle(
          Offset(s[0] * size.width, s[1] * size.height), s[2], paint);
    }
    // خط ضوء خفي في المنتصف
    final linePaint = Paint()
      ..color = AppColors.accent.withOpacity(0.04)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height), linePaint);
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false;
}
