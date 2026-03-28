import 'package:flutter/material.dart';
import '../../constants/colors.dart';

// ─── الأبواب الـ 11 (79 سؤالاً إلزامياً) ─────────────────────

class _ConsentDoor {
  final String number;
  final String title;
  final List<String> questions;
  const _ConsentDoor({required this.number, required this.title, required this.questions});
}

const List<_ConsentDoor> _kDoors = [
  _ConsentDoor(
    number: 'الباب الأول',
    title: 'الالتزام العام والطاعة',
    questions: [
      'هل تفهم أن الانضمام إلى هذا النظام يعني قبول السلطة الكاملة للسيدة دون تحفظ أو استثناء؟',
      'هل تقبل أن قرارات السيدة نهائية وغير قابلة للنقاش أو الاستئناف بأي شكل؟',
      'هل توافق على أن تُطيع الأوامر حتى في الحالات التي قد تبدو غير مريحة لك شخصياً؟',
      'هل تدرك أن أي شكل من أشكال العصيان سيؤدي إلى عواقب فورية وتلقائية؟',
      'هل تؤكد أن انضمامك طوعي وخالٍ من أي إكراه خارجي بأي صورة كانت؟',
      'هل تقبل أن الدستور ملزم ولا يمكن التراجع عنه بعد التوقيع الإلكتروني؟',
      'هل تفهم أن السيدة تملك حق تعديل قواعد النظام متى رأت ذلك مناسباً دون الرجوع إليك؟',
    ],
  ),
  _ConsentDoor(
    number: 'الباب الثاني',
    title: 'المراقبة الرقمية الشاملة',
    questions: [
      'هل توافق على مراقبة جهازك وكل نشاطك الرقمي بشكل مستمر وبدون توقف؟',
      'هل تقبل أن تُسجَّل كل ضغطة مفتاح تقوم بها داخل الجهاز وتُرسَل للسيدة؟',
      'هل توافق على التقاط صور عشوائية من كاميرا جهازك الأمامية والخلفية دون إشعار مسبق؟',
      'هل تقبل أن تُراقَب مواقعك الجغرافية ومساراتك في أي وقت وفي أي مكان؟',
      'هل توافق على تسجيل الأصوات المحيطة وتحليلها بحثاً عن الكلمات والمحادثات؟',
      'هل تقبل أن تُرسَل بيانات جهازك كاملةً — بما فيها الرسائل والتطبيقات — للسيدة مباشرةً؟',
      'هل تفهم أن محاولة تعطيل المراقبة أو التهرب منها تُعدّ انتهاكاً صريحاً وعقوبته مضاعفة؟',
    ],
  ),
  _ConsentDoor(
    number: 'الباب الثالث',
    title: 'صلاحيات الجهاز والسيطرة الكاملة',
    questions: [
      'هل توافق على منح التطبيق صلاحيات مشرف الجهاز الكاملة الدائمة؟',
      'هل تقبل أن يُقفَل جهازك عن بُعد في أي لحظة تراها السيدة مناسبة دون حاجة لإذنك؟',
      'هل توافق على تفعيل خدمة إمكانية الوصول التي تُتيح قراءة ومراقبة نشاط الشاشة بالكامل؟',
      'هل تقبل أن تُحظَر تطبيقات أو مواقع بعينها بأمر فوري من السيدة دون إبداء أي اعتراض؟',
      'هل توافق على إذن الظهور فوق جميع التطبيقات لعرض الأوامر والتنبيهات والعقوبات؟',
      'هل تدرك أن محاولة إلغاء هذه الصلاحيات ستؤدي إلى قفل فوري وعقوبة أشد؟',
      'هل توافق على أن التطبيق قادر على تسجيل الشاشة وبث محتواها مباشرة للسيدة؟',
    ],
  ),
  _ConsentDoor(
    number: 'الباب الرابع',
    title: 'الانضباط الجسدي والزمني',
    questions: [
      'هل تقبل تحديد ساعة إيقاظك يومياً من قِبَل السيدة دون إمكانية التعديل بنفسك؟',
      'هل تلتزم بإثبات نومك ويقظتك بالصور والصوت فور الطلب دون تأخير؟',
      'هل تقبل حظر النوم في أوقات غير مصرح بها حتى لو كنت متعباً جسدياً؟',
      'هل تلتزم بالإفادة الفورية عن موقعك الجغرافي الدقيق عند الطلب دون تأخير؟',
      'هل تقبل تحديد أوقات الأكل والشرب بحسب جداول السيدة عند التطبيق؟',
      'هل تلتزم بالمثول أمام الكاميرا بشكل واضح خلال 30 ثانية من وقت الطلب؟',
      'هل تقبل أن تخضع لفحوصات جسدية مرئية عبر الكاميرا للتحقق من مظهرك وهيئتك؟',
    ],
  ),
  _ConsentDoor(
    number: 'الباب الخامس',
    title: 'الانضباط النفسي والعقوبات',
    questions: [
      'هل تقبل العقوبات النفسية كحجب التطبيقات وتعتيم الشاشة وتغيير ألوانها؟',
      'هل توافق على نظام النقاط الذي يُحدد امتيازاتك اليومية ويؤثر في حياتك داخل النظام؟',
      'هل تقبل آلية الغرامات المالية من مخصصاتك الشخصية عند الإخفاق أو المخالفة؟',
      'هل تلتزم بكتابة جمل اعتذار مخصصة إذا تجاوزت حدود السلطة أو أسأت الأدب؟',
      'هل تقبل وضع الشاشة الحمراء كعقوبة بصرية مستمرة طوال اليوم على انتهاكاتك؟',
      'هل تفهم أن تجاهل العقوبات أو المقاومة يُضاعف أثرها تلقائياً دون تدخل بشري؟',
      'هل توافق على نظام القفل الرئيسي الذي يجمّد جهازك بالكامل عند محاولة التمرد؟',
      'هل تقبل أن تُنشر انتهاكاتك الجسيمة للمجموعة كعقوبة اجتماعية رادعة؟',
    ],
  ),
  _ConsentDoor(
    number: 'الباب السادس',
    title: 'الحياة الاجتماعية والتواصل',
    questions: [
      'هل تقبل أن تُرصَد جميع رسائلك ومحادثاتك واتصالاتك دون استثناء ودون تدخل منك؟',
      'هل توافق على حظر التواصل مع أشخاص بعينهم بأمر السيدة وإلى أجل غير مسمى؟',
      'هل تقبل تقييد ساعات استخدامك لمنصات التواصل الاجتماعي وفق جداول محددة؟',
      'هل تفهم أن كل محادثاتك مع أفراد المجموعة مرئية للسيدة في الوقت الفعلي؟',
      'هل تقبل حظر الخروج من المسكن بدون تصريح رقمي مُسبَق من السيدة؟',
      'هل توافق على الإفصاح الفوري عن أي تواصل خارجي طارئ حتى مع أفراد الأسرة؟',
      'هل تقبل أن أي علاقة اجتماعية جديدة تستلزم إحاطة السيدة والحصول على موافقتها؟',
    ],
  ),
  _ConsentDoor(
    number: 'الباب السابع',
    title: 'الوضع المالي والممتلكات',
    questions: [
      'هل تقبل الإفصاح الكامل والصادق عن جميع ممتلكاتك المادية والمالية دون استثناء؟',
      'هل توافق على أن تبقى سجلاتك المالية الكاملة تحت إشراف ومتابعة السيدة المستمرة؟',
      'هل تقبل نظام جرد الممتلكات الدوري والمفاجئ الذي قد يُفعَّل في أي وقت؟',
      'هل تفهم أن تغيير أي من ممتلكاتك المُسجَّلة يستلزم إبلاغ السيدة مسبقاً؟',
      'هل توافق على تجميد مصروفاتك الشخصية وفق تقدير السيدة ومتى رأت ذلك مناسباً؟',
      'هل تقبل أن يُخصَم مبلغ محدد من مخصصاتك مقابل كل مخالفة أو إخفاق يُسجَّل عليك؟',
      'هل تلتزم بتقديم فواتير وإيصالات أي عملية شراء تُجريها عند طلب السيدة فوراً؟',
    ],
  ),
  _ConsentDoor(
    number: 'الباب الثامن',
    title: 'الواجبات والمهام اليومية',
    questions: [
      'هل تقبل نظام المهام اليومية الذي تحدده السيدة وحدها دون الرجوع إلى رأيك؟',
      'هل تلتزم بتوثيق إنجاز كل مهمة بالصور والموقع الجغرافي في نفس وقت الإنجاز؟',
      'هل تفهم أن إخفاق مهمة واحدة يؤثر في تقييمك الكلي لذلك اليوم بالكامل؟',
      'هل تقبل التنقل بين أدوار مختلفة (خادم / مرافق / سكرتير) من يوم لآخر؟',
      'هل توافق على إعادة تنفيذ المهمة كاملةً إذا رأت السيدة أن التنفيذ كان قاصراً أو مهملاً؟',
      'هل تقبل عقوبة تضاعف المهام عند تكرار الإخفاق في نفس الفئة خلال أسبوع؟',
      'هل تلتزم بتنفيذ المهام الطارئة فوراً حتى لو كنت نائماً أو في وضع راحة مُقرَّرة؟',
    ],
  ),
  _ConsentDoor(
    number: 'الباب التاسع',
    title: 'الصحة والسلامة والجسد',
    questions: [
      'هل توافق على الإفصاح الكامل والصادق عن وضعك الصحي الجسدي والنفسي الحالي؟',
      'هل تقبل تعليمات السيدة المتعلقة بنظامك الغذائي وعدد ساعات نومك عند اتخاذها؟',
      'هل تلتزم بالإبلاغ الفوري عن أي تدهور صحي مفاجئ أو طارئ صحي من أي نوع؟',
      'هل تقبل الخضوع لفحوصات صحة دورية بناءً على طلب السيدة وفي الوقت الذي تحدده؟',
      'هل توافق على أن السيدة قادرة على تعديل جدول نشاطك الجسدي وتمريناتك اليومية؟',
      'هل تدرك أن إخفاء أي معلومة صحية عمداً يُعدّ خرقاً جسيماً وعقوبته مشددة؟',
      'هل تقبل نظام تتبع النوم والنشاط اليومي التلقائي الذي يُحلَّل ويُرسَل للسيدة؟',
    ],
  ),
  _ConsentDoor(
    number: 'الباب العاشر',
    title: 'الطوارئ والأزمات والحدود',
    questions: [
      'هل تدرك آلية التواصل مع السيدة في حالات الطوارئ الحقيقية وتلتزم باستخدامها فقط؟',
      'هل تفهم أن الاستغاثة الكاذبة أو الاستغاثة لأسباب تافهة ستُعرّضك لعقوبة أشد مضاعفة؟',
      'هل توافق على أن "الضغط الطويل للطوارئ" داخل التطبيق هو الآلية الوحيدة المشروعة للنداء؟',
      'هل تقبل أن السيدة وحدها تقرر ما إذا كانت الطوارئ المُبلَّغ عنها حقيقية أم لا؟',
      'هل تلتزم بعدم الاستعانة بجهة خارجية في أي شأن يخص النظام دون موافقة السيدة المسبقة؟',
      'هل تفهم أن الخطوط الحمراء التي أعلنتها في الاستمارة ستُحترَم ما لم تُشكّل خطراً حقيقياً؟',
      'هل تقبل أن يُطبَّق بروتوكول المحكمة العرفية الكامل عند إثبات التمرد الجسيم؟',
      'هل تدرك أن محاولة الإفلات النهائي من النظام تؤدي إلى قفل كامل وإنهاء تلقائي وأبدي؟',
    ],
  ),
  _ConsentDoor(
    number: 'الباب الحادي عشر',
    title: 'التعهد النهائي والإقرار الرسمي',
    questions: [
      'هل أقررتَ بأنك قرأتَ هذه الاستمارة كاملةً وفهمتَ مضمونها قبل الإجابة على أي سؤال؟',
      'هل تؤكد أن جميع بياناتك في هذه الاستمارة صادقة ودقيقة وخالية من التضليل؟',
      'هل تدرك أن تقديم معلومات مزيفة أو منقوصة عمداً يُلغي انضمامك فوراً وبصورة أبدية؟',
      'هل تقبل أن توقيعك الإلكتروني المرسوم بيدك ملزم قانونياً ورقمياً بنفس قوة الورقي؟',
      'هل توافق على عدم مشاركة أي من محتوى هذه الاستمارة مع أي شخص خارج النظام بأي شكل؟',
      'هل تقبل أن يُعرَض أي نزاع على السيدة وحدها بوصفها جهة الفصل الوحيدة والنهائية؟',
      'هل تُقرّ بأن انضمامك إلى هذا النظام يُجسِّد قراراً نهائياً وإرادياً حراً لا رجعة فيه؟',
    ],
  ),
];

class Section7Consent extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const Section7Consent({super.key, this.initialData, required this.onChanged});
  @override
  State<Section7Consent> createState() => _Section7State();
}

class _Section7State extends State<Section7Consent> {
  // consent_q_1 … consent_q_79
  final Map<String, String?> _answers = {};
  int _expandedDoor = 0;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      final ca = (d['consent_answers'] as Map<String, dynamic>?) ?? {};
      ca.forEach((k, v) => _answers[k] = v?.toString());
    }
  }

  int _questionIndex(int doorIdx, int qIdx) {
    int count = 1;
    for (int i = 0; i < doorIdx; i++) count += _kDoors[i].questions.length;
    return count + qIdx;
  }

  int get _totalAnswered => _answers.values.where((v) => v != null).length;
  int get _totalQuestions {
    return _kDoors.fold(0, (s, d) => s + d.questions.length);
  }

  bool _doorComplete(int doorIdx) {
    final door = _kDoors[doorIdx];
    for (int qi = 0; qi < door.questions.length; qi++) {
      final key = 'consent_q_${_questionIndex(doorIdx, qi)}';
      if (_answers[key] == null) return false;
    }
    return true;
  }

  void _setAnswer(String key, String val) {
    setState(() => _answers[key] = val);
    _notify();
  }

  void _notify() {
    final Map<String, String> answersMap = {};
    _answers.forEach((k, v) { if (v != null) answersMap[k] = v; });
    widget.onChanged({
      'consent_answers': answersMap,
      'all_consents_given': _totalAnswered == _totalQuestions,
      'answered_count': _totalAnswered,
      'total_questions': _totalQuestions,
    });
  }

  @override
  Widget build(BuildContext context) {
    final answered  = _totalAnswered;
    final total     = _totalQuestions;
    final allDone   = answered == total;
    const teal      = Color(0xFF319795);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // رأس القسم
        const Text('الموافقة المستنيرة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
        const SizedBox(height: 4),
        const Text('الأبواب الـ 11 — 79 سؤالاً إلزامياً بإجابة نعم / لا',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        const SizedBox(height: 16),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),

        // تحذير
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.error.withOpacity(0.3))),
          child: const Text(
            'تحذير: هذه الأسئلة ملزمة قانونياً ورقمياً. كل إجابة تُحفَظ مع توقيت الإجابة وبيانات الجهاز. لا يمكن إلغاء الموافقة أو تعديلها بعد إرسال الاستمارة.',
            style: TextStyle(fontSize: 13, color: AppColors.error, fontFamily: 'Tajawal'),
            textAlign: TextAlign.right),
        ),
        const SizedBox(height: 16),

        // شريط التقدم
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$answered / $total سؤالاً',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: allDone ? teal : AppColors.accent, fontFamily: 'Tajawal')),
          const Text('اكتمال الإجابات', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? answered / total : 0,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(allDone ? teal : AppColors.accent),
          ),
        ),
        const SizedBox(height: 20),

        // الأبواب
        ...List.generate(_kDoors.length, (di) {
          final door     = _kDoors[di];
          final complete = _doorComplete(di);
          final expanded = _expandedDoor == di;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: complete ? teal.withOpacity(0.4) : expanded ? AppColors.accent.withOpacity(0.4) : AppColors.border,
                width: complete || expanded ? 1.5 : 1)),
            child: Column(
              children: [
                // رأس الباب
                GestureDetector(
                  onTap: () => setState(() => _expandedDoor = expanded ? -1 : di),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Icon(
                        complete ? Icons.check_circle : expanded ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 22,
                        color: complete ? teal : expanded ? AppColors.accent : AppColors.textMuted),
                      const SizedBox(width: 10),
                      Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 20, color: AppColors.textMuted),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(door.number,
                            style: TextStyle(fontSize: 11, color: complete ? teal : AppColors.textMuted, fontFamily: 'Tajawal')),
                        Text(door.title,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                                color: complete ? teal : AppColors.text, fontFamily: 'Tajawal')),
                        Text('${door.questions.length} أسئلة',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'Tajawal')),
                      ]),
                    ]),
                  ),
                ),

                // أسئلة الباب
                if (expanded) ...[
                  const Divider(color: AppColors.border, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: List.generate(door.questions.length, (qi) {
                        final qNum = _questionIndex(di, qi);
                        final key  = 'consent_q_$qNum';
                        final ans  = _answers[key];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ans == 'yes' ? teal.withOpacity(0.06) : ans == 'no' ? AppColors.error.withOpacity(0.06) : AppColors.backgroundElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ans == 'yes' ? teal.withOpacity(0.4) : ans == 'no' ? AppColors.error.withOpacity(0.4) : AppColors.border)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            // السؤال
                            Text('س$qNum: ${door.questions[qi]}',
                                style: const TextStyle(fontSize: 13, color: AppColors.text, fontFamily: 'Tajawal', height: 1.5),
                                textAlign: TextAlign.right),
                            const SizedBox(height: 10),
                            // أزرار نعم / لا
                            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              _AnswerBtn(
                                label: 'لا',
                                selected: ans == 'no',
                                color: AppColors.error,
                                onTap: () => _setAnswer(key, 'no'),
                              ),
                              const SizedBox(width: 8),
                              _AnswerBtn(
                                label: 'نعم',
                                selected: ans == 'yes',
                                color: teal,
                                onTap: () => _setAnswer(key, 'yes'),
                              ),
                            ]),
                          ]),
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 16),

        // ملخص
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: allDone ? teal.withOpacity(0.1) : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: allDone ? teal.withOpacity(0.5) : AppColors.border, width: allDone ? 1.5 : 1)),
          child: Row(children: [
            Icon(allDone ? Icons.verified_user_outlined : Icons.pending_outlined,
                color: allDone ? teal : AppColors.textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(
              allDone
                  ? 'أُجيبَت جميع الأسئلة الـ $total — جاهز للمتابعة'
                  : 'متبقٍ ${total - answered} سؤالاً — يجب الإجابة على الكل للمتابعة',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: allDone ? teal : AppColors.textMuted, fontFamily: 'Tajawal'),
              textAlign: TextAlign.right)),
          ]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _AnswerBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _AnswerBtn({required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.15) : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1)),
      child: Text(label, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          color: selected ? color : AppColors.textSecondary, fontFamily: 'Tajawal')),
    ),
  );
}
