import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  بيانات الفصول — استبدل النصوص بمحتوى وثيقتك الفعلية
// ─────────────────────────────────────────────────────────────────────────────

class _Chapter {
  final String title;
  final String body;
  const _Chapter({required this.title, required this.body});
}

const List<_Chapter> _chapters = [
  _Chapter(
    title: 'الفصل الأول — الأطراف والتعريفات',
    body: '''
يُبرم هذا الاتفاق بين طرفين راشدين مدركَين لمضمونه وتبعاته الكاملة.

الطرف الأول (القائد): الشخص المفوَّض بصلاحيات الإشراف والمتابعة وفق ما تنص عليه هذه الوثيقة.

الطرف الثاني (المتسابق): الشخص الذي يقبل طوعاً الخضوع لبنود هذا الإطار لغرض التطوير الذاتي وتعزيز المساءلة السلوكية.

يُقرّ الطرفان بأن هذا الاتفاق حرٌّ تماماً من أي إكراه، وأن لكل طرف الحق في إنهائه بإشعار صريح في أي وقت.
''',
  ),
  _Chapter(
    title: 'الفصل الثاني — نطاق الصلاحيات والحدود',
    body: '''
يمنح المتسابق القائدَ صلاحية الإشراف على المسار الرقمي وفق ما تحدده هذه الوثيقة حصراً.

تشمل الصلاحيات: مراجعة تقارير الالتزام، تفعيل إشعارات التنبيه، وتقييم درجات الأداء.

لا تتجاوز الصلاحيات الحدود المتفق عليها. أي تصرف خارج النطاق يُعدّ انتهاكاً فورياً للاتفاق ويُوقف مفعوله.

يلتزم الطرفان بالسرية التامة في جميع البيانات المتبادلة ضمن هذا الإطار.
''',
  ),
  _Chapter(
    title: 'الفصل الثالث — الالتزامات والمسؤوليات',
    body: '''
يلتزم المتسابق بـ:
- التواصل الصادق والشفاف مع القائد.
- الإبلاغ الفوري عن أي صعوبة أو عائق يحول دون تنفيذ البنود.
- احترام قرارات القائد في نطاق الصلاحيات المحددة.

يلتزم القائد بـ:
- ممارسة الصلاحيات بمسؤولية ولصالح المتسابق.
- الاستماع الفعّال لأي مخاوف تُرفع.
- تعليق أو إنهاء الاتفاق فور طلب المتسابق ذلك.
''',
  ),
  _Chapter(
    title: 'الفصل الرابع — بنود إنهاء الاتفاق',
    body: '''
يحق لكل طرف إنهاء هذا الاتفاق فورياً وبدون قيد بإبلاغ الطرف الآخر.

عند الإنهاء: تُحذف جميع البيانات المجمَّعة ضمن الإطار خلال 72 ساعة.

لا يُفسَّر الإنهاء باعتباره إخفاقاً — بل ممارسة لحق أصيل.

بالتوقيع على هذه الوثيقة يُقرّ الطرفان بفهمهما الكامل لجميع البنود وقبولهما لها طوعاً.
''',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
//  الشاشة الرئيسية
// ─────────────────────────────────────────────────────────────────────────────

class ConstitutionScreen extends StatefulWidget {
  const ConstitutionScreen({super.key});

  @override
  State<ConstitutionScreen> createState() => _ConstitutionScreenState();
}

class _ConstitutionScreenState extends State<ConstitutionScreen>
    with SingleTickerProviderStateMixin {
  int _currentChapter = 0;
  bool _canAgree = false;
  int _secondsLeft = 45;
  Timer? _timer;
  final Set<int> _agreedChapters = {};
  final ScrollController _scrollCtrl = ScrollController();

  // تأثير الدخول
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _canAgree = false;
      _secondsLeft = 45;
    });
    _fadeCtrl.reset();
    _fadeCtrl.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _canAgree = true;
          t.cancel();
          // تمرير للأسفل تلقائياً عند انتهاء الوقت
          Future.delayed(const Duration(milliseconds: 200), () {
            if (_scrollCtrl.hasClients) {
              _scrollCtrl.animateTo(
                _scrollCtrl.position.maxScrollExtent,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
              );
            }
          });
        }
      });
    });
  }

  void _agreeChapter() {
    _agreedChapters.add(_currentChapter);
    if (_currentChapter < _chapters.length - 1) {
      setState(() => _currentChapter++);
      _scrollCtrl.jumpTo(0);
      _startTimer();
    } else {
      // جميع الفصول مقبولة → الانتقال لشاشة التوقيع
      context.push('/onboarding/signature');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapters[_currentChapter];
    final progress = (_currentChapter + 1) / _chapters.length;
    final timerProgress = (45 - _secondsLeft) / 45;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // ── شريط التقدم العلوي ─────────────────────────────
              _TopProgressBar(
                chapterIndex: _currentChapter,
                totalChapters: _chapters.length,
                overallProgress: progress,
              ),

              // ── نص الفصل ──────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // عنوان الفصل
                      Text(
                        chapter.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                          fontFamily: 'Tajawal',
                          height: 1.5,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 2,
                        width: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.accent, Colors.transparent],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // نص الفصل
                      Text(
                        chapter.body.trim(),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          fontFamily: 'Tajawal',
                          height: 2.0,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // ── شريط الموقّت + زر الموافقة ────────────────────
              _BottomAgreementBar(
                secondsLeft: _secondsLeft,
                timerProgress: timerProgress,
                canAgree: _canAgree,
                isLastChapter: _currentChapter == _chapters.length - 1,
                onAgree: _agreeChapter,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  شريط التقدم العلوي
// ─────────────────────────────────────────────────────────────────────────────

class _TopProgressBar extends StatelessWidget {
  final int chapterIndex;
  final int totalChapters;
  final double overallProgress;

  const _TopProgressBar({
    required this.chapterIndex,
    required this.totalChapters,
    required this.overallProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${chapterIndex + 1} / $totalChapters',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontFamily: 'Tajawal'),
              ),
              const Text(
                'مراجعة الوثيقة',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Tajawal'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // أنقاط الفصول
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(totalChapters, (i) {
              final isActive = i == chapterIndex;
              final isDone = i < chapterIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.success
                      : isActive
                          ? AppColors.accent
                          : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  شريط الموقّت والموافقة
// ─────────────────────────────────────────────────────────────────────────────

class _BottomAgreementBar extends StatelessWidget {
  final int secondsLeft;
  final double timerProgress;
  final bool canAgree;
  final bool isLastChapter;
  final VoidCallback onAgree;

  const _BottomAgreementBar({
    required this.secondsLeft,
    required this.timerProgress,
    required this.canAgree,
    required this.isLastChapter,
    required this.onAgree,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // شريط الموقّت
          if (!canAgree) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${secondsLeft}s',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      fontFamily: 'Tajawal'),
                ),
                const Text(
                  'يُرجى القراءة الكاملة قبل المتابعة',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontFamily: 'Tajawal'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: timerProgress),
                duration: const Duration(milliseconds: 500),
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: AppColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'يمكنك المتابعة',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.success,
                      fontFamily: 'Tajawal'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // زر الموافقة
          SizedBox(
            width: double.infinity,
            height: 52,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: canAgree
                  ? ElevatedButton(
                      key: const ValueKey('agree'),
                      onPressed: onAgree,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        isLastChapter
                            ? 'أوافق على جميع البنود والمتابعة للتوقيع'
                            : 'أوافق والانتقال للفصل التالي',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Tajawal'),
                      ),
                    )
                  : Container(
                      key: const ValueKey('waiting'),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'الرجاء الانتظار...',
                          style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textMuted,
                              fontFamily: 'Tajawal'),
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
