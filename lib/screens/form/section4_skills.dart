import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../widgets/gold_input.dart';

// ── الـ 48 مهارة الخدمية (skill_1 … skill_48) ────────────────
const List<String> _kSkillLabels = [
  'الطهي والإعداد', 'تنظيف المطبخ', 'ترتيب وتنظيم الغرف', 'الغسيل والكوي',
  'تلميع الأحذية', 'ترتيب الملابس والخزائن', 'صناعة المشروبات الساخنة', 'تقديم الضيافة',
  'تنظيم المواعيد والجداول', 'إعداد التقارير الكتابية', 'التعامل مع الطباعة والمستندات', 'إدارة البريد الإلكتروني',
  'البحث عبر الإنترنت', 'حجز التذاكر والفنادق', 'التعامل مع الجهات الحكومية', 'قيادة السيارة في المدينة',
  'قيادة السيارة على الطرق السريعة', 'التنقل باستخدام الخرائط الرقمية', 'الإسعافات الأولية الأساسية', 'التعامل مع الأجهزة الإلكترونية',
  'استخدام برامج Microsoft Office', 'إدارة مواقع التواصل الاجتماعي', 'التصوير الفوتوغرافي', 'تحرير الفيديو الأساسي',
  'التعامل مع الحيوانات الأليفة', 'العناية بالنباتات', 'إدارة المشتريات والتسوق', 'التفاوض والشراء بأسعار مناسبة',
  'حمل الأحمال الثقيلة', 'التحمل الجسدي الممتد', 'السرعة في تنفيذ المهام', 'الدقة والانتباه للتفاصيل',
  'الهدوء تحت الضغط', 'العمل بصمت ودون ضجيج', 'تقدير الحاجة دون الطلب', 'الاستجابة الفورية للنداء',
  'إعداد الملفات والأرشفة', 'التعامل مع الأجهزة المنزلية', 'إصلاح الأعطال البسيطة', 'النظافة الشخصية المستمرة',
  'اللباقة في التواصل', 'ضبط النفس أمام الانتقادات', 'الكتمان وعدم الإفصاح', 'الولاء والأمانة',
  'التكيف مع التغيير الفوري', 'العمل لساعات ممتدة دون شكوى', 'التعامل مع ضيوف السيدة', 'التمثيل وإخفاء المشاعر',
];

class Section4Skills extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const Section4Skills({super.key, this.initialData, required this.onChanged});
  @override
  State<Section4Skills> createState() => _Section4State();
}

class _Section4State extends State<Section4Skills> {
  // ── التعليم ──────────────────────────────────────────────────
  String _degree        = '';
  final _majorCtrl      = TextEditingController();
  final _gradYearCtrl   = TextEditingController();
  final _gpaCtrl        = TextEditingController();

  // ── المهارات التقنية ─────────────────────────────────────────
  final Set<String> _techSkills  = {};
  final _programmingCtrl  = TextEditingController();
  final _otherTechCtrl    = TextEditingController();

  // ── القيادة ──────────────────────────────────────────────────
  bool _driveManual    = false;
  bool _driveAutomatic = false;
  final Set<String> _licenses = {};
  String _carLicenseDegree = '';

  // ── اللغات (ديناميكي) ────────────────────────────────────────
  bool _hasOtherLanguages = false;
  int  _langCount = 0;
  final List<TextEditingController> _langNameCtrls  = [];
  final List<TextEditingController> _langLevelCtrls = [];

  // ── الخدمة العسكرية ──────────────────────────────────────────
  String _militaryStatus = '';
  final _militaryDurationCtrl  = TextEditingController();
  final _militaryStartCtrl     = TextEditingController();
  final _militaryEndCtrl       = TextEditingController();
  final _militaryRankCtrl      = TextEditingController();

  // ── القيادة والمواهب ─────────────────────────────────────────
  bool _leadershipExp = false;
  final _leadershipDetailsCtrl = TextEditingController();
  final Set<String> _talents   = {};
  final _otherTalentCtrl       = TextEditingController();

  // ── مستوى اللياقة ────────────────────────────────────────────
  String _fitnessLevel = '';
  final _sportTypeCtrl  = TextEditingController();

  // ── جدول التقييم 48 مهارة (1-10) ────────────────────────────
  final Map<String, int> _skillScores = {
    for (int i = 0; i < _kSkillLabels.length; i++) 'skill_${i + 1}': 0,
  };

  List<TextEditingController> get _staticCtrls => [
    _majorCtrl, _gradYearCtrl, _gpaCtrl, _programmingCtrl, _otherTechCtrl,
    _militaryDurationCtrl, _militaryStartCtrl, _militaryEndCtrl, _militaryRankCtrl,
    _leadershipDetailsCtrl, _otherTalentCtrl, _sportTypeCtrl,
    ..._langNameCtrls, ..._langLevelCtrls,
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      final edu = (d['education'] as Map<String, dynamic>?) ?? {};
      _degree = edu['degree'] ?? '';
      _majorCtrl.text    = edu['major']     ?? '';
      _gradYearCtrl.text = edu['grad_year'] ?? '';
      _gpaCtrl.text      = edu['gpa']?.toString() ?? '';

      final ts = (d['tech_skills'] as List<dynamic>?) ?? [];
      _techSkills.addAll(ts.cast<String>());
      _programmingCtrl.text = d['programming_languages'] ?? '';
      _otherTechCtrl.text   = d['other_tech_details']    ?? '';

      final ds = (d['driving_skills'] as Map<String, dynamic>?) ?? {};
      _driveManual    = ds['manual']    ?? false;
      _driveAutomatic = ds['automatic'] ?? false;
      final dl = (d['driving_licenses'] as List<dynamic>?) ?? [];
      _licenses.addAll(dl.cast<String>());
      _carLicenseDegree = d['car_license_degree'] ?? '';

      _hasOtherLanguages = d['has_other_languages'] ?? false;
      final ll = (d['languages_list'] as List<dynamic>?) ?? [];
      _langCount = ll.length;
      _rebuildLangCtrls(ll);

      _militaryStatus = d['military_service_status'] ?? '';
      final md = (d['military_details'] as Map<String, dynamic>?) ?? {};
      _militaryDurationCtrl.text = md['duration']   ?? '';
      _militaryStartCtrl.text    = md['start_date'] ?? '';
      _militaryEndCtrl.text      = md['end_date']   ?? '';
      _militaryRankCtrl.text     = md['rank']       ?? '';

      _leadershipExp = d['leadership_experience'] ?? false;
      _leadershipDetailsCtrl.text = d['leadership_details'] ?? '';
      final ta = (d['talents'] as List<dynamic>?) ?? [];
      _talents.addAll(ta.cast<String>());
      _otherTalentCtrl.text = d['other_talent_details'] ?? '';

      _fitnessLevel = d['fitness_level'] ?? '';
      _sportTypeCtrl.text = d['sport_type'] ?? '';

      final se = (d['service_skills_evaluation'] as Map<String, dynamic>?) ?? {};
      for (int i = 0; i < _kSkillLabels.length; i++) {
        final k = 'skill_${i + 1}';
        _skillScores[k] = (se[k] as num?)?.toInt() ?? 0;
      }
    }
    for (final c in _staticCtrls) c.addListener(_notify);
  }

  void _rebuildLangCtrls(List<dynamic> list) {
    for (final c in [..._langNameCtrls, ..._langLevelCtrls]) {
      c.removeListener(_notify);
      c.dispose();
    }
    _langNameCtrls.clear();
    _langLevelCtrls.clear();
    for (int i = 0; i < _langCount; i++) {
      final l = (i < list.length ? list[i] as Map<String, dynamic>? : null) ?? {};
      final n = TextEditingController(text: l['lang_name']  ?? '');
      final lv = TextEditingController(text: l['lang_level'] ?? '');
      n.addListener(_notify);
      lv.addListener(_notify);
      _langNameCtrls.add(n);
      _langLevelCtrls.add(lv);
    }
  }

  void _setLangCount(int count) {
    final prev = List.generate(_langCount, (i) => {
      'lang_name':  _langNameCtrls[i].text,
      'lang_level': _langLevelCtrls[i].text,
    });
    setState(() { _langCount = count; _rebuildLangCtrls(prev); });
    _notify();
  }

  void _notify() {
    widget.onChanged({
      'education': {
        'degree':    _degree,
        'major':     _majorCtrl.text.trim(),
        'grad_year': _gradYearCtrl.text.trim(),
        'gpa':       double.tryParse(_gpaCtrl.text) ?? 0,
      },
      'tech_skills': _techSkills.toList(),
      if (_techSkills.contains('programming'))     'programming_languages': _programmingCtrl.text.trim(),
      if (_techSkills.contains('other_tech'))      'other_tech_details': _otherTechCtrl.text.trim(),
      'driving_skills': {'manual': _driveManual, 'automatic': _driveAutomatic},
      'driving_licenses': _licenses.toList(),
      if (_licenses.contains('car')) 'car_license_degree': _carLicenseDegree,
      'has_other_languages': _hasOtherLanguages,
      if (_hasOtherLanguages) 'lang_count': _langCount,
      if (_hasOtherLanguages) 'languages_list': List.generate(_langCount, (i) => {
        'lang_name':  _langNameCtrls[i].text.trim(),
        'lang_level': _langLevelCtrls[i].text.trim(),
      }),
      'military_service_status': _militaryStatus,
      if (_militaryStatus == 'served') 'military_details': {
        'duration':   _militaryDurationCtrl.text.trim(),
        'start_date': _militaryStartCtrl.text.trim(),
        'end_date':   _militaryEndCtrl.text.trim(),
        'rank':       _militaryRankCtrl.text.trim(),
      },
      'leadership_experience': _leadershipExp,
      if (_leadershipExp) 'leadership_details': _leadershipDetailsCtrl.text.trim(),
      'talents': _talents.toList(),
      if (_talents.contains('other_talent')) 'other_talent_details': _otherTalentCtrl.text.trim(),
      'fitness_level': _fitnessLevel,
      if (_fitnessLevel == 'intermediate' || _fitnessLevel == 'advanced') 'sport_type': _sportTypeCtrl.text.trim(),
      'service_skills_evaluation': Map.from(_skillScores),
    });
  }

  @override
  void dispose() {
    for (final c in _staticCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF3182CE);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _hdr('المهارات والقدرات العملية', 'القسم الرابع — المؤهلات والتقييم الشامل'),

        // ── التعليم ──────────────────────────────────────────────
        _sub('المؤهل التعليمي'),
        const SizedBox(height: 12),
        _radioChips('الدرجة العلمية',
            ['ثانوي', 'دبلوم', 'بكالوريوس', 'ماجستير', 'دكتوراه', 'أخرى'],
            _degree, blue, (v) { setState(() => _degree = v); _notify(); }),
        const SizedBox(height: 10),
        GoldInput(label: 'التخصص الدراسي', controller: _majorCtrl, hint: 'مثال: هندسة حاسبات'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: GoldInput(label: 'سنة التخرج', controller: _gradYearCtrl, hint: '2020', keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: GoldInput(label: 'المعدل / GPA', controller: _gpaCtrl, hint: '3.5', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 20),

        // ── المهارات التقنية ─────────────────────────────────────
        _sub('المهارات التقنية'),
        const SizedBox(height: 12),
        _multiSelect('المهارات التقنية المتوفرة', const {
          'programming': 'البرمجة', 'design': 'التصميم الجرافيكي',
          'data_analysis': 'تحليل البيانات', 'video_editing': 'تحرير الفيديو',
          'social_media': 'إدارة السوشيال ميديا', 'office': 'Microsoft Office',
          'networking': 'الشبكات', 'other_tech': 'أخرى',
        }, _techSkills, blue, (k) {
          setState(() { _techSkills.contains(k) ? _techSkills.remove(k) : _techSkills.add(k); });
          _notify();
        }),
        if (_techSkills.contains('programming')) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'لغات البرمجة', controller: _programmingCtrl, hint: 'Python, Dart, Java...'),
        ],
        if (_techSkills.contains('other_tech')) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل المهارات الأخرى', controller: _otherTechCtrl, hint: 'اذكرها بالتفصيل'),
        ],
        const SizedBox(height: 20),

        // ── القيادة ──────────────────────────────────────────────
        _sub('القيادة والمواصلات'),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _switchRow('قيادة أوتوماتيك', _driveAutomatic,
              (v) { setState(() => _driveAutomatic = v); _notify(); }),
          const SizedBox(width: 20),
          _switchRow('قيادة يدوية', _driveManual,
              (v) { setState(() => _driveManual = v); _notify(); }),
        ]),
        const SizedBox(height: 10),
        _multiSelect('رخص القيادة المتوفرة', const {
          'car': 'سيارة خاصة', 'motorcycle': 'دراجة نارية',
          'truck': 'شاحنة', 'bus': 'حافلة',
        }, _licenses, blue, (k) {
          setState(() { _licenses.contains(k) ? _licenses.remove(k) : _licenses.add(k); });
          _notify();
        }),
        if (_licenses.contains('car')) ...[
          const SizedBox(height: 10),
          _radioChips('درجة رخصة السيارة',
              ['أول', 'ثاني', 'ثالث', 'رابع'],
              _carLicenseDegree, blue,
              (v) { setState(() => _carLicenseDegree = v); _notify(); }),
        ],
        const SizedBox(height: 20),

        // ── اللغات ───────────────────────────────────────────────
        _sub('اللغات'),
        const SizedBox(height: 12),
        _toggleRow('هل تتحدث لغات غير العربية؟', _hasOtherLanguages, (v) {
          setState(() { _hasOtherLanguages = v; if (!v) { _langCount = 0; _rebuildLangCtrls([]); } });
          _notify();
        }),
        if (_hasOtherLanguages) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text('عدد اللغات:', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
            const SizedBox(width: 10),
            _CWidget(value: _langCount, onChanged: _setLangCount),
          ]),
          const SizedBox(height: 10),
          ...List.generate(_langCount, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('اللغة ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent, fontFamily: 'Tajawal')),
                const SizedBox(height: 8),
                GoldInput(label: 'اسم اللغة', controller: _langNameCtrls[i], hint: 'مثال: الإنجليزية'),
                const SizedBox(height: 8),
                GoldInput(label: 'المستوى', controller: _langLevelCtrls[i], hint: 'مثال: متقدم / B2'),
              ]),
            ),
          )),
        ],
        const SizedBox(height: 20),

        // ── الخدمة العسكرية ──────────────────────────────────────
        _sub('الخدمة العسكرية'),
        const SizedBox(height: 12),
        _radioChips('حالة الخدمة',
            ['أديتها', 'معفي منها', 'لم يحن موعدها'],
            _militaryStatus, blue,
            (v) { setState(() => _militaryStatus = v); _notify(); },
            vals: ['served', 'exempt', 'not_yet']),
        if (_militaryStatus == 'served') ...[
          const SizedBox(height: 10),
          GoldInput(label: 'مدة الخدمة', controller: _militaryDurationCtrl, hint: 'مثال: سنتان'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: GoldInput(label: 'تاريخ البداية', controller: _militaryStartCtrl, hint: 'YYYY-MM', keyboardType: TextInputType.datetime)),
            const SizedBox(width: 8),
            Expanded(child: GoldInput(label: 'تاريخ النهاية', controller: _militaryEndCtrl, hint: 'YYYY-MM', keyboardType: TextInputType.datetime)),
          ]),
          const SizedBox(height: 8),
          GoldInput(label: 'الرتبة الأخيرة', controller: _militaryRankCtrl, hint: 'مثال: رقيب أول'),
        ],
        const SizedBox(height: 20),

        // ── القيادة والمواهب ─────────────────────────────────────
        _sub('القيادة والمواهب'),
        const SizedBox(height: 12),
        _toggleRow('هل لديك تجربة قيادة فرق أو مشاريع؟', _leadershipExp, (v) {
          setState(() => _leadershipExp = v); _notify();
        }),
        if (_leadershipExp) ...[
          const SizedBox(height: 8),
          GoldInput(label: 'تفاصيل تجربة القيادة', controller: _leadershipDetailsCtrl, hint: 'صف تجاربك', maxLines: 3),
        ],
        const SizedBox(height: 10),
        _multiSelect('المواهب والهوايات', const {
          'art': 'الرسم والفنون', 'music': 'الموسيقى', 'cooking_talent': 'الطهي الإبداعي',
          'writing': 'الكتابة', 'photography': 'التصوير', 'sports_talent': 'الرياضة',
          'crafts': 'الحرف اليدوية', 'other_talent': 'أخرى',
        }, _talents, blue, (k) {
          setState(() { _talents.contains(k) ? _talents.remove(k) : _talents.add(k); });
          _notify();
        }),
        if (_talents.contains('other_talent')) ...[
          const SizedBox(height: 8),
          GoldInput(label: 'تفاصيل المواهب الأخرى', controller: _otherTalentCtrl, hint: 'اذكرها'),
        ],
        const SizedBox(height: 20),

        // ── اللياقة البدنية ──────────────────────────────────────
        _sub('اللياقة البدنية'),
        const SizedBox(height: 12),
        _radioChips('مستوى اللياقة',
            ['مبتدئ', 'متوسط', 'متقدم'],
            _fitnessLevel, blue,
            (v) { setState(() => _fitnessLevel = v); _notify(); },
            vals: ['beginner', 'intermediate', 'advanced']),
        if (_fitnessLevel == 'intermediate' || _fitnessLevel == 'advanced') ...[
          const SizedBox(height: 8),
          GoldInput(label: 'نوع الرياضة الممارسة', controller: _sportTypeCtrl, hint: 'مثال: كمال أجسام، عدو...'),
        ],
        const SizedBox(height: 24),

        // ── جدول تقييم 48 مهارة خدمية ───────────────────────────
        _sub('جدول التقييم الذاتي للمهارات الخدمية (48 مهارة)'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(0.3))),
          child: const Text(
            'قيّم نفسك بصدق من 1 (لا أجيده) إلى 10 (متقن تماماً). هذه البيانات ستُستخدم لبناء مخطط الرادار الخاص بك.',
            style: TextStyle(fontSize: 13, color: AppColors.warning, fontFamily: 'Tajawal'),
            textAlign: TextAlign.right),
        ),
        const SizedBox(height: 16),
        ...List.generate(_kSkillLabels.length, (i) {
          final key   = 'skill_${i + 1}';
          final score = _skillScores[key] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: score >= 7 ? blue.withOpacity(0.15) : score >= 4 ? AppColors.warning.withOpacity(0.12) : AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: score >= 7 ? blue : score >= 4 ? AppColors.warning : AppColors.border)),
                  child: Text('$score / 10',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: score >= 7 ? blue : score >= 4 ? AppColors.warning : AppColors.textMuted,
                          fontFamily: 'Tajawal')),
                ),
                Text('${i + 1}. ${_kSkillLabels[i]}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text, fontFamily: 'Tajawal'),
                    textAlign: TextAlign.right),
              ]),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: score >= 7 ? blue : score >= 4 ? AppColors.warning : AppColors.error,
                  inactiveTrackColor: AppColors.border,
                  thumbColor: AppColors.accent,
                  overlayColor: AppColors.accent.withOpacity(0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: score.toDouble(),
                  min: 0, max: 10, divisions: 10,
                  onChanged: (v) {
                    setState(() => _skillScores[key] = v.round());
                    _notify();
                  },
                ),
              ),
            ]),
          );
        }),
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

  Widget _sub(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      const Expanded(child: Divider(color: AppColors.border)),
      const SizedBox(width: 10),
      Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent, fontFamily: 'Tajawal')),
    ]),
  );

  Widget _radioChips(String label, List<String> opts, String val, Color color, ValueChanged<String> onChange, {List<String>? vals}) {
    final effectiveVals = vals ?? opts;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
          children: List.generate(opts.length, (i) {
            final sel = val == effectiveVals[i];
            return GestureDetector(
              onTap: () => onChange(effectiveVals[i]),
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

  Widget _multiSelect(String label, Map<String, String> items, Set<String> selected, Color color, ValueChanged<String> onToggle) {
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

  Widget _toggleRow(String label, bool val, ValueChanged<bool> onChange) =>
      GestureDetector(
        onTap: () => onChange(!val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: val ? AppColors.accent.withOpacity(0.08) : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: val ? AppColors.accent : AppColors.border, width: val ? 1.5 : 1)),
          child: Row(children: [
            Icon(val ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: val ? AppColors.accent : AppColors.textMuted),
            const SizedBox(width: 10),
            const Spacer(),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: val ? FontWeight.w600 : FontWeight.normal,
                color: val ? AppColors.text : AppColors.textSecondary, fontFamily: 'Tajawal')),
          ]),
        ),
      );

  Widget _switchRow(String label, bool val, ValueChanged<bool> onChange) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Switch(value: val, onChanged: onChange, activeColor: const Color(0xFF3182CE)),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text, fontFamily: 'Tajawal')),
      ]);
}

class _CWidget extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _CWidget({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    _IBtn(icon: Icons.add, onTap: () => onChanged(value + 1)),
    const SizedBox(width: 6),
    Container(
      width: 36, height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Text('$value', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'Tajawal')),
    ),
    const SizedBox(width: 6),
    _IBtn(icon: Icons.remove, onTap: () { if (value > 0) onChanged(value - 1); }),
  ]);
}

class _IBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.accent.withOpacity(0.3))),
      child: Icon(icon, size: 14, color: AppColors.accent),
    ),
  );
}
