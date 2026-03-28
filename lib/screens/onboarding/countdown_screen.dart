import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../constants/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SystemControlChannel — Placeholder للتكامل النيتف
//  الـ Kotlin ينفّذ ما تحتاجه على الجانب الآخر من القناة
// ─────────────────────────────────────────────────────────────────────────────

class _SystemControlChannel {
  static const MethodChannel _channel =
      MethodChannel('com.competition.app/system_control');

  /// يُرسل إشارة "دمج مكتمل" بعد انتهاء العدّ التنازلي
  static Future<void> onboardingComplete() async {
    try {
      await _channel.invokeMethod('onboardingComplete');
    } on PlatformException catch (e) {
      debugPrint('SystemControlChannel: ${e.message}');
    } on MissingPluginException {
      // الـ Kotlin handler لم يُسجَّل بعد — يُتجاهل في التطوير
      debugPrint('SystemControlChannel: لم يُسجَّل handler بعد');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  أسماء الأرقام بالعربية
// ─────────────────────────────────────────────────────────────────────────────

const _arabicNumbers = [
  'عشر', 'تسع', 'ثمان', 'سبع', 'ست',
  'خمس', 'أربع', 'ثلاث', 'اثنتان', 'واحدة',
];

// ─────────────────────────────────────────────────────────────────────────────
//  الشاشة الرئيسية
// ─────────────────────────────────────────────────────────────────────────────

class CountdownScreen extends StatefulWidget {
  final String leaderName;

  const CountdownScreen({
    super.key,
    this.leaderName = 'الإدارة',
  });

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen>
    with TickerProviderStateMixin {
  int _secondsLeft = 10;
  bool _countdownStarted = false;
  bool _completed = false;

  // كنترولر نبضات الخلفية
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // كنترولر العدد
  late AnimationController _numberCtrl;
  late Animation<double> _numberFadeAnim;
  late Animation<double> _numberScaleAnim;

  // كنترولر الظهور الأوّلي
  late AnimationController _introCtrl;
  late Animation<double> _introFadeAnim;

  // كنترولر نهاية الشاشة
  late AnimationController _outroCtrl;
  late Animation<double> _outroAnim;

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startSequence();
  }

  void _initAnimations() {
    // نبض الخلفية
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 0.3, end: 0.7).animate(_pulseCtrl);

    // تغيير الرقم
    _numberCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _numberFadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _numberCtrl, curve: Curves.easeIn));
    _numberScaleAnim = Tween<double>(begin: 1.4, end: 1.0)
        .animate(CurvedAnimation(parent: _numberCtrl, curve: Curves.easeOut));

    // ظهور النص
    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _introFadeAnim =
        CurvedAnimation(parent: _introCtrl, curve: Curves.easeIn);

    // اختفاء الشاشة
    _outroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _outroAnim =
        Tween<double>(begin: 0, end: 1).animate(_outroCtrl);
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _introCtrl.forward();
    await Future.delayed(const Duration(seconds: 2));
    _startCountdown();
  }

  void _startCountdown() {
    setState(() => _countdownStarted = true);
    _numberCtrl.forward(from: 0);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft <= 1) {
        t.cancel();
        await _onCountdownComplete();
      } else {
        setState(() => _secondsLeft--);
        _numberCtrl.forward(from: 0);
      }
    });
  }

  Future<void> _onCountdownComplete() async {
    setState(() => _completed = true);

    // إطلاق إشارة النيتف (Placeholder)
    await _SystemControlChannel.onboardingComplete();

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    _outroCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) context.go('/participant/home');
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _numberCtrl.dispose();
    _introCtrl.dispose();
    _outroCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _currentNumberWord {
    final index = 10 - _secondsLeft;
    if (index < 0 || index >= _arabicNumbers.length) return '';
    return _arabicNumbers[index];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _outroAnim,
      builder: (_, child) => Opacity(
        opacity: 1 - _outroAnim.value,
        child: child,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── نبض الخلفية ──────────────────────────────────
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      AppColors.accent.withOpacity(_pulseAnim.value * 0.12),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            ),

            // ── جسم الشاشة ──────────────────────────────────
            SafeArea(
              child: FadeTransition(
                opacity: _introFadeAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // أيقونة التزامن
                      _SyncIcon(),

                      const SizedBox(height: 48),

                      // النص الرئيسي
                      Text(
                        'تتم المصادقة. جاري دمج مسارك الرقمي تحت إشراف ${widget.leaderName}..',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                          fontFamily: 'Tajawal',
                          height: 1.8,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 48),

                      // العدّ التنازلي
                      if (_countdownStarted && !_completed)
                        AnimatedBuilder(
                          animation: _numberCtrl,
                          builder: (_, __) => Opacity(
                            opacity: _numberFadeAnim.value,
                            child: Transform.scale(
                              scale: _numberScaleAnim.value,
                              child: Column(
                                children: [
                                  // الرقم
                                  Text(
                                    '$_secondsLeft',
                                    style: const TextStyle(
                                      fontSize: 80,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.accent,
                                      fontFamily: 'Tajawal',
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // الرقم بالعربية
                                  Text(
                                    _currentNumberWord,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.white38,
                                      fontFamily: 'Tajawal',
                                      letterSpacing: 4,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  // شريط تقدم دائري
                                  _CircularCountdown(
                                    progress: (_secondsLeft - 1) / 9,
                                    secondsLeft: _secondsLeft,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // رسالة الاكتمال
                      if (_completed)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 600),
                          builder: (_, v, __) => Opacity(
                            opacity: v,
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.accent,
                                  size: 64,
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'تم دمج مسارك\nالتحكم الرقمي قد بدأ',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontFamily: 'Tajawal',
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'جاري الانتقال...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.4),
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // متحرك الانتظار قبل بدء العدّ
                      if (!_countdownStarted && !_completed)
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2,
                          ),
                        ),

                      const Spacer(flex: 3),

                      // نص "عشر ثوانٍ ليبدأ النظام"
                      if (_countdownStarted && !_completed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: Text(
                            'عشر ثوانٍ ليبدأ النظام',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.3),
                              fontFamily: 'Tajawal',
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── خطوط مسح متحركة (أثر ماتريكس) ─────────────
            const _ScanLines(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  مكوّن: أيقونة التزامن المتحركة
// ─────────────────────────────────────────────────────────────────────────────

class _SyncIcon extends StatefulWidget {
  @override
  State<_SyncIcon> createState() => _SyncIconState();
}

class _SyncIconState extends State<_SyncIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotCtrl;
  late Animation<double> _rotAnim;

  @override
  void initState() {
    super.initState();
    _rotCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    _rotAnim = Tween<double>(begin: 0, end: 1).animate(_rotCtrl);
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // دائرة خارجية دوّارة
          RotationTransition(
            turns: _rotAnim,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: CustomPaint(painter: _ArcPainter()),
            ),
          ),
          // أيقونة مركزية
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.08),
              border: Border.all(
                  color: AppColors.accent.withOpacity(0.2), width: 1),
            ),
            child: const Icon(
              Icons.fingerprint,
              color: AppColors.accent,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -1.0,
      1.8,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  مكوّن: عدّاد دائري
// ─────────────────────────────────────────────────────────────────────────────

class _CircularCountdown extends StatelessWidget {
  final double progress;
  final int secondsLeft;

  const _CircularCountdown({
    required this.progress,
    required this.secondsLeft,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: progress),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        builder: (_, value, __) => CustomPaint(
          painter: _CountdownRingPainter(progress: value),
          child: Center(
            child: Text(
              '$secondsLeft',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final double progress;
  _CountdownRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final trackPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final progressPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // خلفية الحلقة
    canvas.drawCircle(center, radius, trackPaint);

    // شريط التقدم
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
        rect, -3.14 / 2, 2 * 3.14 * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
//  مكوّن: خطوط المسح (Scan Lines) — تأثير بصري
// ─────────────────────────────────────────────────────────────────────────────

class _ScanLines extends StatefulWidget {
  const _ScanLines();

  @override
  State<_ScanLines> createState() => _ScanLinesState();
}

class _ScanLinesState extends State<_ScanLines>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _anim = Tween<double>(begin: -0.1, end: 1.1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _ScanLinePainter(position: _anim.value),
        ),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double position;
  _ScanLinePainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * position;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppColors.accent.withOpacity(0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 40, size.width, 80));

    canvas.drawRect(
      Rect.fromLTWH(0, y - 40, size.width, 80),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.position != position;
}
