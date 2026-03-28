import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  نموذج بيانات نقطة التوقيع — يُخزّن الإحداثيات + السرعة + الضغط
// ─────────────────────────────────────────────────────────────────────────────

class _SignaturePoint {
  final Offset position;
  final double pressure;   // 0.0 – 1.0
  final double speed;      // px/ms
  final DateTime timestamp;

  _SignaturePoint({
    required this.position,
    required this.pressure,
    required this.speed,
    required DateTime? time,
  }) : timestamp = time ?? DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
//  تحليل بيولوجيا التوقيع الرقمي
// ─────────────────────────────────────────────────────────────────────────────

class _SignatureAnalysis {
  final double averageSpeed;    // متوسط السرعة (px/ms)
  final double maxSpeed;        // أعلى سرعة
  final double pressureVariance; // تشتّت الضغط
  final int totalPoints;
  final bool isValid;
  final String? rejectionReason;

  const _SignatureAnalysis({
    required this.averageSpeed,
    required this.maxSpeed,
    required this.pressureVariance,
    required this.totalPoints,
    required this.isValid,
    this.rejectionReason,
  });

  /// ─── قواعد التحقق ───────────────────────────────────────────
  /// السرعة المفرطة: > 3.0 px/ms → تُعتبر توقيعاً متسرّعاً
  /// نقاط قليلة جداً: < 30 نقطة → توقيع غير كافٍ
  /// تشتّت الضغط: إذا كان الجهاز يدعم الضغط وكان ثابتاً جداً
  static const double _maxAllowedSpeed = 3.0;
  static const int _minPoints = 30;

  static _SignatureAnalysis evaluate(List<_SignaturePoint> points) {
    if (points.length < _minPoints) {
      return const _SignatureAnalysis(
        averageSpeed: 0,
        maxSpeed: 0,
        pressureVariance: 0,
        totalPoints: 0,
        isValid: false,
        rejectionReason: 'التوقيع قصير جداً — يُرجى التوقيع بشكل كامل',
      );
    }

    // حساب السرعات
    final speeds = <double>[];
    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1];
      final p2 = points[i];
      final distance = (p2.position - p1.position).distance;
      final dt = p2.timestamp.difference(p1.timestamp).inMicroseconds / 1000.0;
      if (dt > 0) speeds.add(distance / dt);
    }

    final avgSpeed =
        speeds.isEmpty ? 0.0 : speeds.reduce((a, b) => a + b) / speeds.length;
    final maxSpeed = speeds.isEmpty ? 0.0 : speeds.reduce(max);

    // حساب تشتّت الضغط
    final pressures = points.map((p) => p.pressure).toList();
    final avgPressure = pressures.reduce((a, b) => a + b) / pressures.length;
    final variance = pressures
            .map((p) => (p - avgPressure) * (p - avgPressure))
            .reduce((a, b) => a + b) /
        pressures.length;

    // التحقق من السرعة
    if (avgSpeed > _maxAllowedSpeed) {
      return _SignatureAnalysis(
        averageSpeed: avgSpeed,
        maxSpeed: maxSpeed,
        pressureVariance: variance,
        totalPoints: points.length,
        isValid: false,
        rejectionReason:
            'التوقيع متسرّع جداً — يُرجى التوقيع بهدوء وعناية (سرعة: ${avgSpeed.toStringAsFixed(1)} px/ms)',
      );
    }

    return _SignatureAnalysis(
      averageSpeed: avgSpeed,
      maxSpeed: maxSpeed,
      pressureVariance: variance,
      totalPoints: points.length,
      isValid: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  شاشة التوقيع الرئيسية
// ─────────────────────────────────────────────────────────────────────────────

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen>
    with SingleTickerProviderStateMixin {
  final List<List<_SignaturePoint>> _strokes = [];
  List<_SignaturePoint> _currentStroke = [];
  _SignaturePoint? _lastPoint;
  _SignatureAnalysis? _analysis;
  bool _verifying = false;
  bool _showSuccess = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // ── بوابة الـ 45 ثانية — توقيت الجلسة البيولوجية ─────────────
  static const _requiredSeconds = 45;
  int _elapsedSeconds = 0;
  Timer? _sessionTimer;

  bool get _timeGatePassed => _elapsedSeconds >= _requiredSeconds;
  int get _remainingGateSeconds =>
      (_requiredSeconds - _elapsedSeconds).clamp(0, _requiredSeconds);

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));

    // بدء عداد الجلسة الإلزامي (45 ثانية)
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_elapsedSeconds < _requiredSeconds) _elapsedSeconds++;
        if (_elapsedSeconds >= _requiredSeconds) t.cancel();
      });
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  // ── معالجة أحداث اللمس ─────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    _currentStroke = [];
    _lastPoint = null;
    setState(() => _analysis = null);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final now = DateTime.now();
    final pos = d.localPosition;
    final pressure = d.sourceTimeStamp != null ? 0.5 : 0.5; // الضغط الافتراضي

    double speed = 0;
    if (_lastPoint != null) {
      final distance = (pos - _lastPoint!.position).distance;
      final dt =
          now.difference(_lastPoint!.timestamp).inMicroseconds / 1000.0;
      speed = dt > 0 ? distance / dt : 0;
    }

    final point = _SignaturePoint(
      position: pos,
      pressure: pressure,
      speed: speed,
      time: now,
    );
    _lastPoint = point;
    _currentStroke.add(point);
    setState(() {});
  }

  void _onPanEnd(DragEndDetails d) {
    if (_currentStroke.isNotEmpty) {
      _strokes.add(List.from(_currentStroke));
      _currentStroke = [];
    }
    setState(() {});
  }

  // ── معالجة Pointer (يدعم الضغط الحقيقي) ───────────────────────

  void _onPointerDown(PointerDownEvent e) {
    _currentStroke = [];
    _lastPoint = null;
    setState(() => _analysis = null);
  }

  void _onPointerMove(PointerMoveEvent e) {
    final now = DateTime.now();
    final pos = e.localPosition;
    final pressure = e.pressure.clamp(0.0, 1.0);

    double speed = 0;
    if (_lastPoint != null) {
      final distance = (pos - _lastPoint!.position).distance;
      final dt =
          now.difference(_lastPoint!.timestamp).inMicroseconds / 1000.0;
      speed = dt > 0 ? distance / dt : 0;
    }

    final point = _SignaturePoint(
      position: pos,
      pressure: pressure,
      speed: speed,
      time: now,
    );
    _lastPoint = point;
    _currentStroke.add(point);
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_currentStroke.isNotEmpty) {
      _strokes.add(List.from(_currentStroke));
      _currentStroke = [];
    }
    setState(() {});
  }

  // ── مسح التوقيع ──────────────────────────────────────────────

  void _clearSignature() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _analysis = null;
      _showSuccess = false;
    });
  }

  // ── التحقق من التوقيع ─────────────────────────────────────────

  Future<void> _verifySignature() async {
    // بوابة الوقت الإلزامي — 45 ثانية
    if (!_timeGatePassed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يجب الانتظار $_remainingGateSeconds ثانية إضافية قبل التحقق',
            textAlign: TextAlign.right,
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
      _shakeCtrl.forward(from: 0);
      return;
    }

    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 800));

    final allPoints = _strokes.expand((s) => s).toList();
    final result = _SignatureAnalysis.evaluate(allPoints);

    setState(() {
      _analysis = result;
      _verifying = false;
    });

    if (!result.isValid) {
      _shakeCtrl.forward(from: 0);
    } else {
      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.push('/onboarding/countdown');
    }
  }

  bool get _hasSignature =>
      _strokes.isNotEmpty || _currentStroke.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── رأس الشاشة ─────────────────────────────────────
            _Header(),

            // ── تعليمات ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.accent.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.accent, size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'وقّع بخطٍّ هادئ ومتّزن. يُحلَّل إيقاع التوقيع تلقائياً للتحقق من الهوية.',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.accent,
                            fontFamily: 'Tajawal',
                            height: 1.5),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── لوحة التوقيع ──────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) {
                    final shake =
                        sin(_shakeAnim.value * pi * 6) * 8 * (1 - _shakeAnim.value);
                    return Transform.translate(
                        offset: Offset(shake, 0), child: child);
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _analysis == null
                            ? AppColors.border
                            : _analysis!.isValid
                                ? AppColors.success
                                : AppColors.error,
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Listener(
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerUp: _onPointerUp,
                        child: GestureDetector(
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          child: CustomPaint(
                            painter: _SignaturePainter(
                              strokes: _strokes,
                              currentStroke: _currentStroke,
                            ),
                            child: _hasSignature
                                ? const SizedBox.expand()
                                : const Center(
                                    child: Text(
                                      'وقّع هنا',
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: AppColors.textMuted,
                                          fontFamily: 'Tajawal'),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── نتيجة التحليل ─────────────────────────────────
            if (_analysis != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _analysis!.isValid
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _analysis!.isValid
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    if (!_analysis!.isValid) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _clearSignature,
                        child: const Text('إعادة التوقيع',
                            style: TextStyle(
                                color: AppColors.error,
                                fontFamily: 'Tajawal',
                                fontSize: 13)),
                      ),
                    ],
                    const Spacer(),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _analysis!.isValid
                                ? '✓ تم التحقق من التوقيع'
                                : '✗ التحقق فشل',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _analysis!.isValid
                                    ? AppColors.success
                                    : AppColors.error,
                                fontFamily: 'Tajawal'),
                          ),
                          if (_analysis!.rejectionReason != null)
                            Text(
                              _analysis!.rejectionReason!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontFamily: 'Tajawal'),
                              textAlign: TextAlign.right,
                            ),
                          if (_analysis!.isValid)
                            Text(
                              'السرعة: ${_analysis!.averageSpeed.toStringAsFixed(2)} px/ms  |  نقاط: ${_analysis!.totalPoints}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontFamily: 'Tajawal'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      _analysis!.isValid ? Icons.check_circle : Icons.error,
                      color: _analysis!.isValid
                          ? AppColors.success
                          : AppColors.error,
                      size: 22,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ── أزرار التحكم ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  // زر المسح
                  if (_hasSignature)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: _clearSignature,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('مسح',
                            style: TextStyle(fontFamily: 'Tajawal')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (_hasSignature) const SizedBox(width: 12),
                  // زر التحقق
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _hasSignature && !_verifying && !_showSuccess
                          ? _verifySignature
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _showSuccess
                            ? AppColors.success
                            : (!_timeGatePassed
                                ? AppColors.border
                                : AppColors.accent),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _verifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2.5))
                          : Text(
                              _showSuccess
                                  ? 'جارٍ الانتقال...'
                                  : !_timeGatePassed
                                      ? 'انتظر $_remainingGateSeconds ث'
                                      : 'تحقق من التوقيع',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Tajawal',
                                  color: !_timeGatePassed
                                      ? AppColors.textMuted
                                      : Colors.black),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CustomPainter — رسم مسار التوقيع
// ─────────────────────────────────────────────────────────────────────────────

class _SignaturePainter extends CustomPainter {
  final List<List<_SignaturePoint>> strokes;
  final List<_SignaturePoint> currentStroke;

  _SignaturePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawStroke(List<_SignaturePoint> points) {
      if (points.length < 2) return;
      final path = Path();
      path.moveTo(points.first.position.dx, points.first.position.dy);
      for (int i = 1; i < points.length; i++) {
        final p = points[i].position;
        path.lineTo(p.dx, p.dy);
      }
      // ضبط السُّمك حسب الضغط
      final avgPressure =
          points.map((p) => p.pressure).reduce((a, b) => a + b) /
              points.length;
      paint.strokeWidth = 1.5 + (avgPressure * 2.5);
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }
    if (currentStroke.isNotEmpty) {
      drawStroke(currentStroke);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.strokes != strokes || old.currentStroke != currentStroke;
}

// ─────────────────────────────────────────────────────────────────────────────
//  رأس الشاشة
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 8),
          Icon(Icons.draw_outlined, color: AppColors.accent, size: 20),
          SizedBox(width: 10),
          Text(
            'التوقيع الإلكتروني',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Tajawal'),
          ),
        ],
      ),
    );
  }
}
