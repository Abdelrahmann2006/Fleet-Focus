import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/approval_meta_model.dart';
import '../../providers/auth_provider.dart';

/// DyingScreenTransition — شاشة الانتقال إلى بروتوكول المقابلة (Step 2)
///
/// تُعرض فور قبول السيدة لطلب العنصر.
/// تحتوي على:
///  1. خلفية سوداء مع أيقونات تتلاشى تدريجياً
///  2. عداد تنازلي 30 ثانية
///  3. الرسالة الرسمية الكاملة مع التعبئة الديناميكية
///  4. بعد انتهاء العداد → يُغيِّر الحالة إلى `approved_active` ويتوجه لإعداد الجهاز
class DyingScreenTransition extends StatefulWidget {
  const DyingScreenTransition({super.key});

  @override
  State<DyingScreenTransition> createState() => _DyingScreenTransitionState();
}

class _DyingScreenTransitionState extends State<DyingScreenTransition>
    with TickerProviderStateMixin {
  static const _totalSeconds = 30;
  static const _iconCount    = 20;

  int _remaining = _totalSeconds;
  Timer? _countdown;
  bool _transitioning = false;

  // ── تحلّل الأيقونات ───────────────────────────────────────
  late AnimationController _dissolveCtrl;
  final _rng = Random();

  // ── ظهور النص ──────────────────────────────────────────────
  late AnimationController _textCtrl;
  late Animation<double> _textOpacity;

  // ── الأيقونات الوهمية ──────────────────────────────────────
  static const _appIcons = [
    Icons.apps_rounded,     Icons.camera_alt_outlined,
    Icons.chat_bubble_outline, Icons.music_note_outlined,
    Icons.map_outlined,     Icons.videocam_outlined,
    Icons.email_outlined,   Icons.calendar_today_outlined,
    Icons.settings_outlined, Icons.phone_outlined,
    Icons.photo_outlined,   Icons.wifi_outlined,
    Icons.bluetooth_outlined, Icons.location_on_outlined,
    Icons.headphones_outlined, Icons.notifications_outlined,
    Icons.lock_outline,     Icons.cloud_outlined,
    Icons.star_outline,     Icons.favorite_outline,
  ];

  final List<_IconParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    _dissolveCtrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    )..forward();

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);

    for (var i = 0; i < _iconCount; i++) {
      _particles.add(_IconParticle(
        icon: _appIcons[i % _appIcons.length],
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * 0.7,
        startDelay: _rng.nextDouble() * 0.6,
        size: 24 + _rng.nextDouble() * 20,
      ));
    }

    _startCountdown();
  }

  void _startCountdown() {
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _completeTransition();
      }
    });
  }

  Future<void> _completeTransition() async {
    if (_transitioning) return;
    _transitioning = true;
    final auth = context.read<AuthProvider>();
    await auth.markDyingScreenComplete();
    if (mounted) {
      context.go('/participant/device-owner-setup');
    }
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
    final auth = context.watch<AuthProvider>();
    final meta = auth.user?.approvalMeta;
    final assetCode = auth.user?.assetCode ?? auth.user?.linkedLeaderCode ?? '—';
    final ladyName  = meta?.ladyName ?? 'السيدة';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── الأيقونات المتلاشية ─────────────────────────────
          ...(_particles.map((p) => _buildIconParticle(p))),

          // ── الشريط الذهبي العلوي ────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(height: 2, color: AppColors.gold),
          ),

          // ── العداد التنازلي ──────────────────────────────────
          Positioned(
            top: 56,
            right: 24,
            child: _CountdownBadge(remaining: _remaining, total: _totalSeconds),
          ),

          // ── رسالة الانتقال ──────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _textOpacity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildMessageCard(meta: meta, ladyName: ladyName, assetCode: assetCode),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: _remaining <= 0 ? _completeTransition : null,
                        child: Text(
                          _remaining > 0
                              ? 'اقرأ التعليمات بعناية... ($_remaining ث)'
                              : 'متابعة →',
                          style: TextStyle(
                            color: _remaining > 0 ? AppColors.textMuted : AppColors.gold,
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconParticle(_IconParticle p) {
    return AnimatedBuilder(
      animation: _dissolveCtrl,
      builder: (_, __) {
        final progress = (_dissolveCtrl.value - p.startDelay).clamp(0.0, 1.0);
        final opacity  = (1.0 - progress * 1.5).clamp(0.0, 0.4);
        final scale    = 1.0 - progress * 0.5;
        return Positioned(
          left: MediaQuery.of(context).size.width * p.x - 20,
          top:  MediaQuery.of(context).size.height * p.y,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Icon(p.icon, color: Colors.white.withValues(alpha: 0.6), size: p.size),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageCard({
    required ApprovalMeta? meta,
    required String ladyName,
    required String assetCode,
  }) {
    final interviewTime     = meta?.formattedInterviewTime ?? '[غير محدد]';
    final interviewLocation = meta?.interviewLocation ?? '[غير محدد]';
    final auditSchedule     = meta?.auditSchedule ?? '[سيُحدَّد لاحقاً]';
    final dressCode         = meta?.dressCode ?? '[سيُحدَّد لاحقاً]';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── ترويسة الرسالة ──────────────────────────────
          _msgLine('من:', 'القائدة $ladyName'),
          const SizedBox(height: 4),
          _msgLine('إلى:', 'رمز المتقدم  $assetCode'),
          const SizedBox(height: 4),
          _msgLine('الموضوع:', 'إشعار القبول الأولي - تفعيل بروتوكول المقابلة'),
          const Divider(color: Color(0xFF333333), height: 28),

          // ── فقرة الترحيب ────────────────────────────────
          _msgParagraph(
            'بناءً على نموذج الطلب الذي قدمته طواعية، نُعلمك بأن ملفك الشخصي قد قُبل مبدئيًا للمثول أمام السيدة $ladyName.',
          ),
          const SizedBox(height: 12),
          _msgParagraph(
            'من هذه اللحظة، يتم تفعيل نظام التحكم الرقمي؛ هاتفك الآن تحت الإدارة الكاملة عن بُعد. اقرأ التعليمات التالية بحذر شديد. أي انتهاك لحرف واحد يعني الاستبعاد الفوري:',
          ),
          const SizedBox(height: 16),

          // ── بند 1: الجرد ────────────────────────────────
          _sectionTitle('1. بروتوكول الجرد الشامل:'),
          _msgParagraph('سيُطلب منك قريبًا إجراء جرد كامل لجميع ممتلكاتك.'),
          _highlightBox('توقيت الجرد: $auditSchedule'),
          _msgParagraph(
            'بمجرد تفعيل خاصية الجرد، سيتم قفل شاشة هاتفك، ولن تتمكن من الوصول إلى أي شيء آخر غير قائمة الجرد.',
          ),
          const SizedBox(height: 12),

          // ── بند 2: المقابلة ─────────────────────────────
          _sectionTitle('2. الزمان والمكان (المقابلة المباشرة):'),
          _highlightBox('$interviewTime\n$interviewLocation'),
          _msgParagraph(
            'تنبيه تقني: في لحظة حلول موعد المقابلة، ستنغلق شاشة هاتفك تمامًا ولن تُفتح إلا بعد انتهاء المقابلة وتحديد السيدة مصير ممتلكاتك والموافقة عليها.',
          ),
          const SizedBox(height: 12),

          // ── بند 3: الزي ────────────────────────────────
          _sectionTitle('3. المظهر العام (الزي الرسمي):'),
          _highlightBox(dressCode),
          const SizedBox(height: 12),

          // ── بند 4: قواعد الحضور ─────────────────────────
          _sectionTitle('4. بروتوكول الحضور (قواعد نظام صارمة - غير قابلة للتعديل):'),
          const SizedBox(height: 8),
          ...[
            'كن حاضرًا عند باب المقر قبل الوقت المحدد بـ 15 دقيقة بالضبط.',
            'التحدث مع أي شخص ممنوع. الطرق على الباب محظور.',
            'قف بثبات ويداك خلف ظهرك. عندما يحين الوقت، افتح الباب وادخل فورًا.',
            'تقدم بخطوات ثابتة وقف ثابتًا تمامًا تاركًا مسافة متر واحد.',
            'نظرك موجه للأمام وللأسفل. ستبقى واقفًا حتى تظهر السيدة.',
          ].map((rule) => Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                Text('•  ', style: TextStyle(color: AppColors.gold, fontSize: 14)),
                Expanded(child: Text(rule, style: _ruleStyle, textDirection: TextDirection.rtl)),
              ],
            ),
          )),
          const SizedBox(height: 12),

          // ── بند 5: الدستور النهائي ──────────────────────
          _sectionTitle('5. المرحلة النهائية:'),
          _msgParagraph(
            'إذا اجتزت المقابلة، سيطلب منك توقيع الدستور النهائي بـ "توقيع إلكتروني حي".',
          ),
          const SizedBox(height: 16),

          // ── تحذير ختامي ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0000),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
            ),
            child: Text(
              'ملاحظة ختامية: التأخير أو محاولة التلاعب سيؤدي إلى إلغاء طلبك إلى الأبد.',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.redAccent,
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _msgLine(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    textDirection: TextDirection.rtl,
    children: [
      Text(value, style: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal', fontSize: 12)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: AppColors.gold, fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w700)),
    ],
  );

  static Widget _msgParagraph(String text) => Text(
    text,
    textAlign: TextAlign.right,
    textDirection: TextDirection.rtl,
    style: const TextStyle(
      color: Colors.white70,
      fontFamily: 'Tajawal',
      fontSize: 13,
      height: 1.7,
    ),
  );

  static Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        color: AppColors.gold,
        fontFamily: 'Tajawal',
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  static Widget _highlightBox(String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF0D0D20),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Tajawal',
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  static final _ruleStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.8),
    fontFamily: 'Tajawal',
    fontSize: 12,
    height: 1.6,
  );
}

// ── عداد تنازلي دائري ─────────────────────────────────────────

class _CountdownBadge extends StatelessWidget {
  final int remaining;
  final int total;
  const _CountdownBadge({required this.remaining, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = remaining / total;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            color: AppColors.gold,
            backgroundColor: const Color(0xFF333333),
          ),
          Text(
            '$remaining',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }
}

class _IconParticle {
  final IconData icon;
  final double x;
  final double y;
  final double startDelay;
  final double size;
  _IconParticle({required this.icon, required this.x, required this.y, required this.startDelay, required this.size});
}
