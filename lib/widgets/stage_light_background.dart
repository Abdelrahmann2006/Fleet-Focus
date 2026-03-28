import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

class StageLightBackground extends StatefulWidget {
  const StageLightBackground({super.key});

  @override
  State<StageLightBackground> createState() => _StageLightBackgroundState();
}

class _StageLightBackgroundState extends State<StageLightBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _rotationAnim = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _StageLightPainter(
              rotation: _rotationAnim.value,
              opacity: _opacityAnim.value,
            ),
          );
        },
      ),
    );
  }
}

class _StageLightPainter extends CustomPainter {
  final double rotation;
  final double opacity;

  _StageLightPainter({required this.rotation, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final cx = size.width / 2;
    final cy = size.height * 0.28;

    // Main spotlight cone
    canvas.save();
    canvas.translate(cx, cy * 0.35);
    canvas.rotate(rotation);

    final conePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accent.withOpacity(0.22 * opacity),
          AppColors.accentDark.withOpacity(0.08 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: size.width * 0.75));

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(-size.width * 0.55, size.height * 0.65)
      ..lineTo(size.width * 0.55, size.height * 0.65)
      ..close();
    canvas.drawPath(path, conePaint);
    canvas.restore();

    // Circle glow at top
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accent.withOpacity(0.35 * opacity),
          AppColors.accentDark.withOpacity(0.15 * opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 90));
    canvas.drawCircle(Offset(cx, cy), 90, glowPaint);

    // Dark overlay circle
    final circlePaint = Paint()
      ..color = AppColors.background.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 72, circlePaint);

    // Gold ring
    final ringPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.6 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(cx, cy), 72, ringPaint);

    // Bottom ambient
    final bottomPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accentDark.withOpacity(0.15 * opacity),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(cx, size.height * 0.6), radius: size.width * 0.5),
      );
    canvas.drawCircle(Offset(cx, size.height * 0.6), size.width * 0.5, bottomPaint);
  }

  @override
  bool shouldRepaint(_StageLightPainter old) =>
      old.rotation != rotation || old.opacity != opacity;
}
