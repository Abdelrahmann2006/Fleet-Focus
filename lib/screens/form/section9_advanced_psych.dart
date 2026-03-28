import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../widgets/gold_input.dart';

// ─── مصفوفة حدود الكرامة (50 بنداً: dignity_0 … dignity_49) ──
const List<String> _kDignityItems = [
  'الصراخ في وجهي أمام الآخرين',                            // 0
  'التوبيخ العلني أمام باقي الأعضاء',                      // 1
  'تجاهل ردودي تماماً أثناء الحديث المباشر',               // 2
  'استخدام كلمات مهينة مباشرة في مخاطبتي',                // 3
  'تقييد التواصل مع أسرتي لفترة ممتدة',                   // 4
  'حظر التواصل مع الأصدقاء لمدة غير محددة',               // 5
  'الإهانة الشخصية بسبب مظهري الجسدي',                    // 6
  'إصدار الأوامر دون أي تفسير أو مبرر',                   // 7
  'مطالبتي بالانتظار بلا حد زمني محدد',                  // 8
  'الاطلاع على محتوى هاتفي الشخصي بشكل مباشر',           // 9
  'المقارنة بالأعضاء الآخرين بشكل سلبي ومستمر',           // 10
  'تعليق حكم علني على مستوى أدائي',                       // 11
  'إلغاء مكافأتي فجأة دون إشعار أو سبب واضح',            // 12
  'التحكم الكامل في نوع طعامي ووجباتي اليومية',           // 13
  'فرض لباس أو مظهر بعينه باستمرار',                      // 14
  'الخصم المالي من مخصصاتي الشخصية',                      // 15
  'مصادرة جزء من ممتلكاتي مؤقتاً',                        // 16
  'تجميد استخدامي لمنصات التواصل الاجتماعي',              // 17
  'حظر الاستماع للموسيقى في أوقات محددة',                  // 18
  'إلزامي بوضعية جسدية محددة أثناء الانتظار',             // 19
  'قراءة رسائلي الخاصة مع الآخرين',                       // 20
  'فرض صمت كامل لفترات ممتدة',                            // 21
  'الإجبار على تكرار جمل الاعتذار عدة مرات',              // 22
  'استخدام نبرة باردة وجافة بشكل مستمر معي',              // 23
  'مخاطبتي بصيغة رسمية صارمة طوال الوقت',                // 24
  'إبلاغي بأنني في المرتبة الأخيرة في التقييم',            // 25
  'تعتيم شاشتي وتحويل ألوانها لرمادية كعقوبة',            // 26
  'حرماني من التواصل مع السيدة لأيام متتالية',             // 27
  'إلزامي بكتابة اعتراف تفصيلي مكتوب عن خطئي',           // 28
  'الخضوع لرقابة مباشرة مستمرة لمدة أسبوع كامل',          // 29
  'تجميد جميع نقاط الولاء فجأة ودون سابق إنذار',          // 30
  'فرض ساعة استيقاظ مبكرة جداً كعقوبة مؤلمة',            // 31
  'إلزامي بتقديم تقرير يومي مفصَّل عن كل تحركاتي',        // 32
  'منع الاسترخاء والترفيه لمدة زمنية محددة',               // 33
  'الإشارة إلى أخطائي أمام المجموعة صراحةً',              // 34
  'طلب الشرح والمبرر عن كل قرار شخصي أتخذه',             // 35
  'فرض قيود مفاجئة وغير متوقعة دون سابق إنذار',           // 36
  'إلغاء وقت الراحة المقرر لي مسبقاً',                    // 37
  'الإجبار على الاعتذار بصوت مرتفع أمام الآخرين',         // 38
  'مطالبتي بتقديم دليل صوري على موقعي في أي وقت',         // 39
  'الخضوع لعقوبة الشاشة الحمراء طوال اليوم',              // 40
  'إلغاء جميع امتيازاتي دفعة واحدة في لحظة',              // 41
  'تجميد محادثاتي مع باقي الأعضاء كلياً',                 // 42
  'طلب فيديو توضيحي عن حالتي فوراً عند الطلب',            // 43
  'الدخول في وضع المحكوم عليه مؤقتاً',                    // 44
  'الإجبار على الغياب الاجتماعي الكامل لمدة معينة',        // 45
  'تعليق انضمامي مؤقتاً كرسالة تأديبية رسمية',            // 46
  'خصم نقاط مضاعفة على نفس المخالفة المتكررة',             // 47
  'الإعلان عن عقوبتي لجميع أعضاء المجموعة',               // 48
  'العيش في وضع التجربة القصوى لمدة أسبوع كامل',          // 49
];

class Section9AdvancedPsych extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const Section9AdvancedPsych({super.key, this.initialData, required this.onChanged});
  @override
  State<Section9AdvancedPsych> createState() => _Section9State();
}

class _Section9State extends State<Section9AdvancedPsych> {
  // ── المحفزات ──────────────────────────────────────────────────
  final Set<String> _triggers = {};
  final _customTrigger1 = TextEditingController();
  final _customTrigger2 = TextEditingController();
  final _customTrigger3 = TextEditingController();

  // ── أنماط الاستجابة للضغط ────────────────────────────────────
  final Set<String> _stressPatterns = {};
  final _afterStressCtrl = TextEditingController();

  // ── التعامل مع النقد ─────────────────────────────────────────
  String _criticismHandling = '';
  final _worstCriticismCtrl    = TextEditingController();
  final _sensitiveWordsCtrl    = TextEditingController();

  // ── مصفوفة حدود الكرامة (50 بنداً) ──────────────────────────
  final Map<String, String> _dignityMatrix = {
    for (int i = 0; i < 50; i++) 'dignity_$i': '',
  };

  // ── المخاوف والرهاب ──────────────────────────────────────────
  final Set<String> _phobiaItems = {};
  String _phobiaUsageAcceptance = '';
  final _phobiaUsageDetailCtrl = TextEditingController();

  // ── العلاقات ─────────────────────────────────────────────────
  final Set<String> _relationshipsAcceptance = {};
  final _relationsRedLinesCtrl = TextEditingController();

  // ── القدرة على التحمل ────────────────────────────────────────
  String _enduranceTime  = '';
  final _enduranceCustomCtrl = TextEditingController();
  final _breakingPointCtrl   = TextEditingController();

  // ── التشخيصات النفسية ────────────────────────────────────────
  bool _hasPtsd        = false;
  bool _hasAnxiety     = false;
  bool _hasDepression  = false;
  bool _hasBipolar     = false;

  // ── الشخصية والارتباط ────────────────────────────────────────
  String _personalityType  = '';
  String _attachmentStyle  = '';
  String _riskTolerance    = '';
  String _authorityAcceptance = '';

  // ── نصوص حرة ─────────────────────────────────────────────────
  final _traumaCtrl   = TextEditingController();
  final _fearCtrl     = TextEditingController();
  final _scenarioCtrl = TextEditingController();

  List<TextEditingController> get _ctrls => [
    _customTrigger1, _customTrigger2, _customTrigger3,
    _afterStressCtrl, _worstCriticismCtrl, _sensitiveWordsCtrl,
    _phobiaUsageDetailCtrl, _relationsRedLinesCtrl,
    _enduranceCustomCtrl, _breakingPointCtrl,
    _traumaCtrl, _fearCtrl, _scenarioCtrl,
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      final tr = (d['triggers'] as List<dynamic>?) ?? [];
      _triggers.addAll(tr.cast<String>());
      final ct = (d['custom_triggers'] as Map<String, dynamic>?) ?? {};
      _customTrigger1.text = ct['trigger_other_1'] ?? '';
      _customTrigger2.text = ct['trigger_other_2'] ?? '';
      _customTrigger3.text = ct['trigger_other_3'] ?? '';

      final sp = (d['stress_response_patterns'] as List<dynamic>?) ?? [];
      _stressPatterns.addAll(sp.cast<String>());
      _afterStressCtrl.text = d['after_stress_details'] ?? '';

      _criticismHandling     = d['criticism_handling']     ?? '';
      _worstCriticismCtrl.text = d['worst_criticism_ever'] ?? '';
      _sensitiveWordsCtrl.text = d['sensitive_words_list'] ?? '';

      final dm = (d['dignity_thresholds_matrix'] as Map<String, dynamic>?) ?? {};
      dm.forEach((k, v) { if (_dignityMatrix.containsKey(k)) _dignityMatrix[k] = v?.toString() ?? ''; });

      final ph = (d['phobia_items'] as List<dynamic>?) ?? [];
      _phobiaItems.addAll(ph.cast<String>());
      _phobiaUsageAcceptance   = d['phobia_usage_acceptance'] ?? '';
      _phobiaUsageDetailCtrl.text = d['phobia_usage_detail'] ?? '';

      final ra = (d['relationships_acceptance'] as List<dynamic>?) ?? [];
      _relationshipsAcceptance.addAll(ra.cast<String>());
      _relationsRedLinesCtrl.text = d['relations_red_lines'] ?? '';

      _enduranceTime = d['endurance_time'] ?? '';
      _enduranceCustomCtrl.text = d['endurance_custom'] ?? '';
      _breakingPointCtrl.text   = d['breaking_point_signs'] ?? '';

      _hasPtsd       = d['has_ptsd']           ?? false;
      _hasAnxiety    = d['has_anxiety']         ?? false;
      _hasDepression = d['has_depression']      ?? false;
      _hasBipolar    = d['has_bipolar']         ?? false;

      _personalityType    = d['personality_type']    ?? '';
      _attachmentStyle    = d['attachment_style']    ?? '';
      _riskTolerance      = d['risk_tolerance']      ?? '';
      _authorityAcceptance = d['authority_acceptance'] ?? '';

      _traumaCtrl.text   = d['trauma_history']    ?? '';
      _fearCtrl.text     = d['deepest_fears']      ?? '';
      _scenarioCtrl.text = d['scenario_response']  ?? '';
    }
    for (final c in _ctrls) c.addListener(_notify);
  }

  void _notify() {
    widget.onChanged({
      'triggers': _triggers.toList(),
      'custom_triggers': {
        'trigger_other_1': _customTrigger1.text.trim(),
        'trigger_other_2': _customTrigger2.text.trim(),
        'trigger_other_3': _customTrigger3.text.trim(),
      },
      'stress_response_patterns': _stressPatterns.toList(),
      'after_stress_details': _afterStressCtrl.text.trim(),
      'criticism_handling':   _criticismHandling,
      'worst_criticism_ever': _worstCriticismCtrl.text.trim(),
      'sensitive_words_list': _sensitiveWordsCtrl.text.trim(),
      'dignity_thresholds_matrix': Map.from(_dignityMatrix),
      'phobia_items': _phobiaItems.toList(),
      'phobia_usage_acceptance': _phobiaUsageAcceptance,
      if (_phobiaUsageAcceptance == 'other') 'phobia_usage_detail': _phobiaUsageDetailCtrl.text.trim(),
      'relationships_acceptance': _relationshipsAcceptance.toList(),
      'relations_red_lines': _relationsRedLinesCtrl.text.trim(),
      'endurance_time':   _enduranceTime,
      if (_enduranceTime == 'more') 'endurance_custom': _enduranceCustomCtrl.text.trim(),
      'breaking_point_signs': _breakingPointCtrl.text.trim(),
      'has_ptsd':       _hasPtsd,
      'has_anxiety':    _hasAnxiety,
      'has_depression': _hasDepression,
      'has_bipolar':    _hasBipolar,
      'personality_type':    _personalityType,
      'attachment_style':    _attachmentStyle,
      'risk_tolerance':      _riskTolerance,
      'authority_acceptance': _authorityAcceptance,
      'trauma_history':   _traumaCtrl.text.trim(),
      'deepest_fears':    _fearCtrl.text.trim(),
      'scenario_response': _scenarioCtrl.text.trim(),
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF805AD5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _hdr('المحفزات، الحدود، ومصفوفة الكرامة', 'الباب الرابع عشر — التقييم النفسي المتقدم'),

        // ── المحفزات النفسية ──────────────────────────────────────
        _sub('محفزات الضغط النفسي', purple),
        const SizedBox(height: 12),
        const Text('ما الأساليب التي تُثيرك وتُضعف مقاومتك؟ (اختر كل ما ينطبق)',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal'), textAlign: TextAlign.right),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
          children: _kTriggerOptions.map((t) {
            final active = _triggers.contains(t.key);
            return GestureDetector(
              onTap: () { setState(() { active ? _triggers.remove(t.key) : _triggers.add(t.key); }); _notify(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? purple.withOpacity(0.15) : AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? purple : AppColors.border, width: active ? 1.5 : 1)),
                child: Text(t.label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: active ? purple : AppColors.textSecondary, fontFamily: 'Tajawal')),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        GoldInput(label: 'محفز إضافي 1', controller: _customTrigger1, hint: 'اذكر محفزاً غير مذكور أعلاه'),
        const SizedBox(height: 8),
        GoldInput(label: 'محفز إضافي 2', controller: _customTrigger2, hint: 'اختياري'),
        const SizedBox(height: 8),
        GoldInput(label: 'محفز إضافي 3', controller: _customTrigger3, hint: 'اختياري'),
        const SizedBox(height: 20),

        // ── أنماط الاستجابة للضغط ────────────────────────────────
        _sub('أنماط الاستجابة للضغط والأزمات', purple),
        const SizedBox(height: 12),
        _multiChips('ماذا تفعل عادةً في أوقات الضغط الشديد؟', {
          'calm': 'أبقى هادئاً وأفكر', 'time': 'أحتاج وقتاً للهدوء',
          'impulsive': 'أتصرف بتهور', 'withdraw': 'أنسحب وأعتزل الجميع',
          'seek_help': 'أطلب المساعدة فوراً', 'other': 'أخرى',
        }, _stressPatterns, purple, (k) {
          setState(() { _stressPatterns.contains(k) ? _stressPatterns.remove(k) : _stressPatterns.add(k); });
          _notify();
        }),
        const SizedBox(height: 10),
        GoldInput(label: 'ما الذي تفعله بعد انتهاء الأزمة؟', controller: _afterStressCtrl,
            hint: 'كيف تستعيد توازنك؟', maxLines: 3),
        const SizedBox(height: 20),

        // ── التعامل مع النقد ─────────────────────────────────────
        _sub('التعامل مع النقد والانتقادات', purple),
        const SizedBox(height: 12),
        _radioChips('أسلوبك في التعامل مع النقد المباشر',
            ['أقبله باتزان', 'أحتاج وقتاً', 'أنفعل فوراً', 'أنسحب صامتاً', 'أدافع عن نفسي'],
            ['calm', 'time', 'impulsive', 'withdraw', 'defensive'],
            _criticismHandling, purple, (v) { setState(() => _criticismHandling = v); _notify(); }),
        const SizedBox(height: 10),
        GoldInput(label: 'أسوأ نقد تلقيته في حياتك', controller: _worstCriticismCtrl,
            hint: 'ما الذي قيل لك وكيف أثّر فيك؟', maxLines: 3),
        const SizedBox(height: 8),
        GoldInput(label: 'كلمات حساسة تؤذيك إذا سمعتها', controller: _sensitiveWordsCtrl,
            hint: 'اذكر الكلمات أو العبارات التي تجرحك بشكل خاص', maxLines: 2),
        const SizedBox(height: 20),

        // ── الرهاب والمخاوف ──────────────────────────────────────
        _sub('المخاوف والرهاب', purple),
        const SizedBox(height: 12),
        _multiChips('ما المخاوف أو الرهاب المُشخَّص لديك؟ (كل ما ينطبق)', {
          'darkness': 'الظلام الكامل', 'heights': 'الأماكن العالية',
          'crowds': 'التجمعات الكبيرة', 'isolation': 'الوحدة المطلقة',
          'failure': 'الفشل العلني', 'abandonment': 'الهجر والرفض',
          'insects': 'الحشرات والزواحف', 'medical': 'الإبر والإجراءات الطبية',
          'loss_control': 'فقدان السيطرة', 'confrontation': 'المواجهة المباشرة',
          'humiliation': 'الإذلال العلني', 'noise': 'الأصوات المفاجئة العالية',
        }, _phobiaItems, purple, (k) {
          setState(() { _phobiaItems.contains(k) ? _phobiaItems.remove(k) : _phobiaItems.add(k); });
          _notify();
        }),
        const SizedBox(height: 10),
        _radioChips('قبولك لاستخدام هذه المخاوف في إطار النظام',
            ['بحذر وتحكم', 'لا أقبل ذلك', 'أخرى'],
            ['careful', 'no', 'other'],
            _phobiaUsageAcceptance, purple, (v) { setState(() => _phobiaUsageAcceptance = v); _notify(); }),
        if (_phobiaUsageAcceptance == 'other') ...[
          const SizedBox(height: 8),
          GoldInput(label: 'تفاصيل الاستخدام المقبول', controller: _phobiaUsageDetailCtrl, hint: 'حدد شروطك'),
        ],
        const SizedBox(height: 20),

        // ── العلاقات ─────────────────────────────────────────────
        _sub('قبول طبيعة العلاقات والأدوار', purple),
        const SizedBox(height: 12),
        _multiChips('ما أنواع العلاقات التي تقبلها داخل النظام؟', {
          'obedience': 'علاقة طاعة وتبعية', 'mentor': 'علاقة معلم ومتعلم',
          'employer': 'علاقة عمل وخدمة رسمية', 'guardian': 'علاقة ولاية وحماية',
          'strict': 'علاقة صارمة جداً', 'transactional': 'علاقة مصلحية واضحة',
        }, _relationshipsAcceptance, purple, (k) {
          setState(() { _relationshipsAcceptance.contains(k) ? _relationshipsAcceptance.remove(k) : _relationshipsAcceptance.add(k); });
          _notify();
        }),
        const SizedBox(height: 10),
        GoldInput(label: 'خطوطك الحمراء في العلاقات', controller: _relationsRedLinesCtrl,
            hint: 'ما الذي لن تقبله تحت أي ظرف؟', maxLines: 3),
        const SizedBox(height: 20),

        // ── القدرة على التحمل ────────────────────────────────────
        _sub('حدود التحمل ونقاط الانهيار', purple),
        const SizedBox(height: 12),
        _radioChips('أقصى فترة تحتمل فيها الضغط الشديد دون انهيار',
            ['ساعات', '3 أيام', 'أسبوع', 'أكثر من ذلك'],
            ['hours', '3days', 'week', 'more'],
            _enduranceTime, purple, (v) { setState(() => _enduranceTime = v); _notify(); }),
        if (_enduranceTime == 'more') ...[
          const SizedBox(height: 8),
          GoldInput(label: 'حدد المدة التقريبية', controller: _enduranceCustomCtrl, hint: 'مثال: شهر كامل'),
        ],
        const SizedBox(height: 10),
        GoldInput(label: 'علامات الانهيار عندك', controller: _breakingPointCtrl,
            hint: 'كيف يبدو انهيارك؟ ماذا تفعل عند بلوغ الحد؟', maxLines: 4),
        const SizedBox(height: 20),

        // ── مصفوفة حدود الكرامة والاحترام (50 بنداً) ────────────
        _sub('مصفوفة حدود الكرامة والاحترام — 50 بنداً', AppColors.error),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withOpacity(0.3))),
          child: const Text(
            'لكل بند أدناه، حدد موقفك بدقة:\n🟢 أقبل — مقبول كلياً\n🟡 مقبول بحدود — مقبول بشروط معينة فقط\n🔴 أرفض — خط أحمر مطلق',
            style: TextStyle(fontSize: 13, color: AppColors.error, fontFamily: 'Tajawal', height: 1.5),
            textAlign: TextAlign.right),
        ),
        const SizedBox(height: 16),
        ...List.generate(_kDignityItems.length, (i) {
          final key = 'dignity_$i';
          final val = _dignityMatrix[key] ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: val == 'accept' ? AppColors.success.withOpacity(0.06)
                  : val == 'limited' ? AppColors.warning.withOpacity(0.06)
                  : val == 'reject' ? AppColors.error.withOpacity(0.06)
                  : AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: val == 'accept' ? AppColors.success.withOpacity(0.4)
                    : val == 'limited' ? AppColors.warning.withOpacity(0.4)
                    : val == 'reject' ? AppColors.error.withOpacity(0.4)
                    : AppColors.border,
                width: val.isNotEmpty ? 1.5 : 1)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // عنوان البند
              Text('${i + 1}. ${_kDignityItems[i]}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text, fontFamily: 'Tajawal'),
                  textAlign: TextAlign.right),
              const SizedBox(height: 8),
              // أزرار الاختيار
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _DignityBtn(label: 'أرفض', value: 'reject',  selected: val == 'reject',  color: AppColors.error,
                    onTap: () { setState(() => _dignityMatrix[key] = 'reject');  _notify(); }),
                const SizedBox(width: 6),
                _DignityBtn(label: 'بحدود', value: 'limited', selected: val == 'limited', color: AppColors.warning,
                    onTap: () { setState(() => _dignityMatrix[key] = 'limited'); _notify(); }),
                const SizedBox(width: 6),
                _DignityBtn(label: 'أقبل', value: 'accept',  selected: val == 'accept',  color: AppColors.success,
                    onTap: () { setState(() => _dignityMatrix[key] = 'accept');  _notify(); }),
              ]),
            ]),
          );
        }),
        // ملخص المصفوفة
        const SizedBox(height: 8),
        _DignityMatrixSummary(matrix: _dignityMatrix),
        const SizedBox(height: 20),

        // ── التشخيصات النفسية ────────────────────────────────────
        _sub('التشخيصات النفسية', purple),
        const SizedBox(height: 12),
        _switchRow('اضطراب ما بعد الصدمة (PTSD)',   _hasPtsd,       (v) { setState(() => _hasPtsd = v);       _notify(); }),
        _switchRow('اضطراب القلق المزمن',            _hasAnxiety,    (v) { setState(() => _hasAnxiety = v);    _notify(); }),
        _switchRow('الاكتئاب السريري',               _hasDepression, (v) { setState(() => _hasDepression = v); _notify(); }),
        _switchRow('الاضطراب ثنائي القطب',           _hasBipolar,    (v) { setState(() => _hasBipolar = v);    _notify(); }),
        const SizedBox(height: 14),
        GoldInput(label: 'صدماتك أو تجاربك القاسية', controller: _traumaCtrl,
            hint: 'اذكر الصدمات الكبرى التي مررت بها وكيف تعاملت معها', maxLines: 3),
        const SizedBox(height: 14),
        GoldInput(label: 'أعمق مخاوفك في الحياة',   controller: _fearCtrl,
            hint: 'ما الذي يُقلقك أكثر من أي شيء آخر؟', maxLines: 3),
        const SizedBox(height: 20),

        // ── الشخصية ──────────────────────────────────────────────
        _sub('أنماط الشخصية والارتباط', purple),
        const SizedBox(height: 12),
        _radioChips('نمط شخصيتك العام',
            ['انطوائي', 'انبساطي', 'متوازن', 'غير مستقر'],
            ['introvert', 'extrovert', 'balanced', 'unstable'],
            _personalityType, purple, (v) { setState(() => _personalityType = v); _notify(); }),
        const SizedBox(height: 10),
        _radioChips('أسلوب ارتباطك العاطفي',
            ['آمن', 'قلق', 'تجنبي', 'مضطرب'],
            ['secure', 'anxious', 'avoidant', 'disorganized'],
            _attachmentStyle, purple, (v) { setState(() => _attachmentStyle = v); _notify(); }),
        const SizedBox(height: 10),
        _radioChips('تحمّلك للمخاطرة',
            ['مرتفع جداً', 'مرتفع', 'متوسط', 'منخفض', 'منخفض جداً'],
            ['very_high', 'high', 'medium', 'low', 'very_low'],
            _riskTolerance, purple, (v) { setState(() => _riskTolerance = v); _notify(); }),
        const SizedBox(height: 10),
        _radioChips('قبولك للسلطة المطلقة',
            ['مرتاح جداً', 'مرتاح', 'محتاج ضمانات', 'متردد', 'رافض'],
            ['very_comfortable', 'comfortable', 'needs_assurance', 'hesitant', 'rejected'],
            _authorityAcceptance, purple, (v) { setState(() => _authorityAcceptance = v); _notify(); }),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: purple.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: purple.withOpacity(0.2))),
          child: const Text(
            'سيناريو: كنت مُوجِّهاً لشخص ما وأخطأ خطأ فادحاً ينعكس عليك. كيف ستتصرف وكيف سيبدو ردّك الأول؟',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF805AD5), fontFamily: 'Tajawal'),
            textAlign: TextAlign.right),
        ),
        const SizedBox(height: 8),
        GoldInput(label: 'إجابتك على السيناريو', controller: _scenarioCtrl,
            hint: 'اشرح قرارك وتبريره بالتفصيل', maxLines: 4),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _hdr(String t, String s) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
      const SizedBox(height: 4),
      Text(s, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
      const SizedBox(height: 16),
      const Divider(color: AppColors.border),
    ]),
  );

  Widget _sub(String t, [Color? color]) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      const Expanded(child: Divider(color: AppColors.border)),
      const SizedBox(width: 10),
      Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? AppColors.accent, fontFamily: 'Tajawal')),
    ]),
  );

  Widget _multiChips(String label, Map<String, String> items, Set<String> selected, Color color, ValueChanged<String> onToggle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
          children: items.entries.map((e) {
            final act = selected.contains(e.key);
            return GestureDetector(
              onTap: () => onToggle(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: act ? color.withOpacity(0.12) : AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: act ? color : AppColors.border, width: act ? 1.5 : 1)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.value, style: TextStyle(fontSize: 13, fontWeight: act ? FontWeight.w600 : FontWeight.normal,
                      color: act ? color : AppColors.textSecondary, fontFamily: 'Tajawal')),
                  if (act) ...[const SizedBox(width: 4), Icon(Icons.check, size: 13, color: color)],
                ]),
              ),
            );
          }).toList()),
    ]);
  }

  Widget _radioChips(String label, List<String> opts, List<String> vals, String val, Color color, ValueChanged<String> onChange) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
          children: List.generate(opts.length, (i) {
            final sel = val == vals[i];
            return GestureDetector(
              onTap: () => onChange(vals[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? color.withOpacity(0.15) : AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? color : AppColors.border, width: sel ? 1.5 : 1)),
                child: Text(opts[i], style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    color: sel ? color : AppColors.textSecondary, fontFamily: 'Tajawal')),
              ),
            );
          })),
    ]);
  }

  Widget _switchRow(String label, bool val, ValueChanged<bool> onChange) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Switch(value: val, onChanged: onChange, activeColor: const Color(0xFF805AD5)),
      Flexible(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text, fontFamily: 'Tajawal'), textAlign: TextAlign.right)),
    ]),
  );
}

// ── زر مصفوفة الكرامة ─────────────────────────────────────────
class _DignityBtn extends StatelessWidget {
  final String label, value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _DignityBtn({required this.label, required this.value, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.2) : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          color: selected ? color : AppColors.textMuted, fontFamily: 'Tajawal')),
    ),
  );
}

// ── ملخص مصفوفة الكرامة ──────────────────────────────────────
class _DignityMatrixSummary extends StatelessWidget {
  final Map<String, String> matrix;
  const _DignityMatrixSummary({required this.matrix});
  @override
  Widget build(BuildContext context) {
    int accept = 0, limited = 0, reject = 0, empty = 0;
    matrix.values.forEach((v) {
      if (v == 'accept')  accept++;
      else if (v == 'limited') limited++;
      else if (v == 'reject')  reject++;
      else empty++;
    });
    final total = matrix.length;
    final done  = accept + limited + reject;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: done == total ? AppColors.success.withOpacity(0.4) : AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('تقدم المصفوفة: $done / $total بنداً',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'Tajawal')),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _Pill(label: 'أرفض: $reject',     color: AppColors.error),
          const SizedBox(width: 6),
          _Pill(label: 'بحدود: $limited',   color: AppColors.warning),
          const SizedBox(width: 6),
          _Pill(label: 'أقبل: $accept',     color: AppColors.success),
          if (empty > 0) ...[
            const SizedBox(width: 6),
            _Pill(label: 'لم يُحدَّد: $empty', color: AppColors.textMuted),
          ],
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
  );
}

// ── قائمة المحفزات (extension مساعدة) ────────────────────────
const List<({String key, String label})> _kTriggerOptions = [
  (key: 'yelling',              label: 'الصراخ والرفع الصوت'),
  (key: 'public_scolding',      label: 'التوبيخ العلني'),
  (key: 'comparison',           label: 'المقارنة بالآخرين'),
  (key: 'silent_treatment',     label: 'العقوبة الصامتة (تجاهل كامل)'),
  (key: 'disappointment',       label: 'إبداء خيبة الأمل الصريحة'),
  (key: 'criticism_intelligence',label: 'التشكيك في الذكاء'),
  (key: 'criticism_appearance', label: 'الانتقاد الجسدي'),
  (key: 'isolation',            label: 'العزل الاجتماعي القسري'),
  (key: 'financial_pressure',   label: 'الضغط المالي والخصم'),
  (key: 'physical_fatigue',     label: 'الإرهاق الجسدي الممتد'),
  (key: 'sleep_deprivation',    label: 'الحرمان من النوم'),
  (key: 'task_overload',        label: 'تراكم المهام المتزامنة'),
];
