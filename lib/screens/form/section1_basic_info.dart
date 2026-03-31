import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../widgets/gold_input.dart';

class Section1BasicInfo extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const Section1BasicInfo({super.key, this.initialData, required this.onChanged});
  @override
  State<Section1BasicInfo> createState() => _Section1BasicInfoState();
}

class _Section1BasicInfoState extends State<Section1BasicInfo> {
  // الاسم الرباعي
  final _firstNameCtrl       = TextEditingController();
  final _fatherNameCtrl      = TextEditingController();
  final _grandfatherNameCtrl = TextEditingController();
  final _familyNameCtrl      = TextEditingController();

  // البيانات الأساسية
  final _birthDateCtrl   = TextEditingController();
  final _birthPlaceCtrl  = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _idCtrl          = TextEditingController();
  String _maritalStatus  = '';

  // جنسية أخرى (شرطي)
  bool _hasOtherNationality = false;
  final _otherNationalitiesCtrl = TextEditingController();

  // أبناء (شرطي + ديناميكي)
  bool _hasChildren = false;
  int  _childrenCount = 0;
  final List<TextEditingController> _childNameCtrls = [];
  final List<TextEditingController> _childAgeCtrls  = [];

  // نفقة (شرطي)
  bool _hasAlimony = false;
  final _alimonyDetailsCtrl = TextEditingController();

  // نوع المشاركة
  String _participationType = '';
  final _commuterReasonsCtrl = TextEditingController();

  // التواصل
  final _mobileCtrl  = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();

  // جهة الطوارئ
  final _emergencyNameCtrl     = TextEditingController();
  final _emergencyRelationCtrl = TextEditingController();
  final _emergencyPhoneCtrl    = TextEditingController();

  List<TextEditingController> get _staticCtrls => [
    _firstNameCtrl, _fatherNameCtrl, _grandfatherNameCtrl, _familyNameCtrl,
    _birthDateCtrl, _birthPlaceCtrl, _nationalityCtrl, _idCtrl,
    _otherNationalitiesCtrl, _alimonyDetailsCtrl, _commuterReasonsCtrl,
    _mobileCtrl, _emailCtrl, _addressCtrl,
    _emergencyNameCtrl, _emergencyRelationCtrl, _emergencyPhoneCtrl,
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _firstNameCtrl.text       = d['first_name']       ?? '';
      _fatherNameCtrl.text      = d['father_name']      ?? '';
      _grandfatherNameCtrl.text = d['grandfather_name'] ?? '';
      _familyNameCtrl.text      = d['family_name']      ?? '';
      _birthDateCtrl.text       = d['birth_date']       ?? '';
      _birthPlaceCtrl.text      = d['birth_place']      ?? '';
      _nationalityCtrl.text     = d['current_nationality'] ?? '';
      _idCtrl.text              = d['id_number']        ?? '';
      _maritalStatus            = d['marital_status']   ?? '';
      _hasOtherNationality      = d['has_other_nationality'] ?? false;
      _otherNationalitiesCtrl.text = d['other_nationalities'] ?? '';
      _hasChildren              = d['has_children']     ?? false;
      _hasAlimony               = d['has_alimony']      ?? false;
      _alimonyDetailsCtrl.text  = d['alimony_details']  ?? '';
      _participationType        = d['participation_type'] ?? '';
      _commuterReasonsCtrl.text = d['commuter_reasons'] ?? '';
      final ci = (d['contact_info'] as Map<String, dynamic>?) ?? {};
      _mobileCtrl.text  = ci['mobile']  ?? '';
      _emailCtrl.text   = ci['email']   ?? '';
      _addressCtrl.text = ci['address'] ?? '';
      final ec = (d['emergency_contact'] as Map<String, dynamic>?) ?? {};
      _emergencyNameCtrl.text     = ec['name']     ?? '';
      _emergencyRelationCtrl.text = ec['relation'] ?? '';
      _emergencyPhoneCtrl.text    = ec['phone']    ?? '';
      final cl = (d['children_list'] as List<dynamic>?) ?? [];
      _childrenCount = cl.length;
      _rebuildChildCtrls(cl);
    }
    for (final c in _staticCtrls) c.addListener(_notify);
  }

  void _rebuildChildCtrls(List<dynamic> list) {
    for (final c in [..._childNameCtrls, ..._childAgeCtrls]) {
      c.removeListener(_notify);
      c.dispose();
    }
    _childNameCtrls.clear();
    _childAgeCtrls.clear();
    for (int i = 0; i < _childrenCount; i++) {
      final child = (i < list.length ? list[i] as Map<String, dynamic>? : null) ?? {};
      final n = TextEditingController(text: child['child_name'] ?? '');
      final a = TextEditingController(text: child['child_age']?.toString() ?? '');
      n.addListener(_notify);
      a.addListener(_notify);
      _childNameCtrls.add(n);
      _childAgeCtrls.add(a);
    }
  }

  void _setChildCount(int count) {
    final prev = List.generate(_childrenCount, (i) => {
      'child_name': _childNameCtrls[i].text,
      'child_age': int.tryParse(_childAgeCtrls[i].text) ?? 0,
    });
    setState(() { _childrenCount = count; _rebuildChildCtrls(prev); });
    _notify();
  }

  int get _computedAge {
    try {
      final p = _birthDateCtrl.text.split('-');
      if (p.length == 3) {
        final bd  = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
        final now = DateTime.now();
        int a = now.year - bd.year;
        if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) a--;
        return a > 0 ? a : 0;
      }
    } catch (_) {}
    return 0;
  }

  void _notify() {
    widget.onChanged({
      'first_name':       _firstNameCtrl.text.trim(),
      'father_name':      _fatherNameCtrl.text.trim(),
      'grandfather_name': _grandfatherNameCtrl.text.trim(),
      'family_name':      _familyNameCtrl.text.trim(),
      'birth_date':       _birthDateCtrl.text,
      'age':              _computedAge,
      'birth_place':      _birthPlaceCtrl.text.trim(),
      'current_nationality': _nationalityCtrl.text.trim(),
      'id_number':        _idCtrl.text.trim(),
      'marital_status':   _maritalStatus,
      'has_other_nationality': _hasOtherNationality,
      if (_hasOtherNationality) 'other_nationalities': _otherNationalitiesCtrl.text.trim(),
      'has_children':  _hasChildren,
      if (_hasChildren) 'children_count': _childrenCount,
      if (_hasChildren) 'children_list': List.generate(_childrenCount, (i) => {
        'child_name': _childNameCtrls[i].text.trim(),
        'child_age':  int.tryParse(_childAgeCtrls[i].text) ?? 0,
      }),
      'has_alimony': _hasAlimony,
      if (_hasAlimony) 'alimony_details': _alimonyDetailsCtrl.text.trim(),
      'participation_type': _participationType,
      if (_participationType == 'commuter') 'commuter_reasons': _commuterReasonsCtrl.text.trim(),
      'contact_info': {
        'mobile':  _mobileCtrl.text.trim(),
        'email':   _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
      },
      'emergency_contact': {
        'name':     _emergencyNameCtrl.text.trim(),
        'relation': _emergencyRelationCtrl.text.trim(),
        'phone':    _emergencyPhoneCtrl.text.trim(),
      },
    });
  }

  @override
  void dispose() {
    for (final c in [..._staticCtrls, ..._childNameCtrls, ..._childAgeCtrls]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _hdr('البيانات الأساسية والهوية', 'القسم الأول — يرجى التعبئة بدقة تامة'),

        // ── الاسم الرباعي ───────────────────────────────────────
        _sub('الاسم الرباعي الكامل'),
        const SizedBox(height: 12),
        GoldInput(label: 'الاسم الأول',       controller: _firstNameCtrl,       hint: 'مثال: عبدالرحمن'),
        const SizedBox(height: 10),
        GoldInput(label: 'اسم الأب',          controller: _fatherNameCtrl,      hint: 'مثال: محمد'),
        const SizedBox(height: 10),
        GoldInput(label: 'اسم الجد',          controller: _grandfatherNameCtrl, hint: 'مثال: يوسف'),
        const SizedBox(height: 10),
        GoldInput(label: 'اسم العائلة / اللقب', controller: _familyNameCtrl,   hint: 'مثال: الغامدي'),
        const SizedBox(height: 20),

        // ── البيانات الأساسية ─────────────────────────────────────
        _sub('البيانات الشخصية'),
        const SizedBox(height: 12),
        // تاريخ الميلاد — يفتح تقويم
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1950),
              lastDate: DateTime.now().subtract(const Duration(days: 365 * 15)),
              locale: const Locale('ar'),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.accent,
                    onPrimary: Colors.black,
                    surface: AppColors.backgroundCard,
                    onSurface: AppColors.text,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              _birthDateCtrl.text =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
            }
          },
          child: AbsorbPointer(
            child: GoldInput(
              label: 'تاريخ الميلاد *',
              controller: _birthDateCtrl,
              hint: 'اضغط لاختيار التاريخ',
              prefixIcon: const Icon(Icons.calendar_today_outlined,
                  color: AppColors.textMuted, size: 18),
            ),
          ),
        ),
        if (_computedAge > 0) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('العمر المحسوب: $_computedAge سنة',
                style: const TextStyle(fontSize: 12, color: AppColors.accent, fontFamily: 'Tajawal')),
          ),
        ],
        const SizedBox(height: 10),
        GoldInput(label: 'مكان الميلاد',       controller: _birthPlaceCtrl,   hint: 'المدينة / البلد'),
        const SizedBox(height: 10),
        GoldInput(label: 'الجنسية الحالية',    controller: _nationalityCtrl,  hint: 'مثال: سعودي'),
        const SizedBox(height: 10),
        GoldInput(label: 'رقم الهوية الوطنية / الإقامة', controller: _idCtrl,
            hint: 'أدخل الرقم كاملاً', keyboardType: TextInputType.number),
        const SizedBox(height: 14),

        // جنسية أخرى
        _toggle('هل تحمل جنسية أخرى؟', _hasOtherNationality,
            (v) { setState(() => _hasOtherNationality = v); _notify(); }),
        if (_hasOtherNationality) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'الجنسيات الأخرى', controller: _otherNationalitiesCtrl, hint: 'اذكرها جميعاً'),
        ],
        const SizedBox(height: 14),

        // الحالة الاجتماعية
        _radio('الحالة الاجتماعية',
            ['أعزب', 'متزوج', 'مطلق', 'أرمل'],
            ['single', 'married', 'divorced', 'widowed'],
            _maritalStatus, (v) { setState(() => _maritalStatus = v); _notify(); }),
        const SizedBox(height: 14),

        // أبناء
        _toggle('هل لديك أبناء؟', _hasChildren, (v) {
          setState(() { _hasChildren = v; if (!v) { _childrenCount = 0; _rebuildChildCtrls([]); } });
          _notify();
        }),
        if (_hasChildren) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text('عدد الأبناء:', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
            const SizedBox(width: 14),
            _CounterWidget(value: _childrenCount, onChanged: _setChildCount),
          ]),
          const SizedBox(height: 10),
          ...List.generate(_childrenCount, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('الابن / الابنة ${i + 1}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent, fontFamily: 'Tajawal')),
                const SizedBox(height: 8),
                GoldInput(label: 'الاسم', controller: _childNameCtrls[i], hint: 'اسم الابن/الابنة'),
                const SizedBox(height: 8),
                GoldInput(label: 'العمر', controller: _childAgeCtrls[i], hint: 'بالسنوات', keyboardType: TextInputType.number),
              ]),
            ),
          )),
        ],
        const SizedBox(height: 14),

        // نفقة
        _toggle('هل عليك نفقة قانونية؟', _hasAlimony,
            (v) { setState(() => _hasAlimony = v); _notify(); }),
        if (_hasAlimony) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل النفقة', controller: _alimonyDetailsCtrl,
              hint: 'المبلغ وطبيعتها', maxLines: 2),
        ],
        const SizedBox(height: 20),

        // ── نوع المشاركة ─────────────────────────────────────────
        _sub('تصنيف المشاركة'),
        const SizedBox(height: 12),
        _radio('نوع الانضمام المطلوب',
            ['مقيم (داخلي)', 'متنقل (خارجي)'],
            ['resident', 'commuter'],
            _participationType, (v) { setState(() => _participationType = v); _notify(); }),
        if (_participationType == 'commuter') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.3))),
            child: const Text(
              'تنويه: القرار النهائي في تصنيف نوع المشاركة يعود للسيدة حصراً.',
              style: TextStyle(fontSize: 13, color: AppColors.warning, fontFamily: 'Tajawal'),
              textAlign: TextAlign.right),
          ),
          const SizedBox(height: 8),
          GoldInput(label: 'أسباب اختيار الانتقال',
              controller: _commuterReasonsCtrl, hint: 'وضّح أسبابك بالتفصيل', maxLines: 3),
        ],
        const SizedBox(height: 20),

        // ── بيانات التواصل ───────────────────────────────────────
        _sub('بيانات التواصل'),
        const SizedBox(height: 12),
        GoldInput(label: 'رقم الجوال',         controller: _mobileCtrl,  hint: '+966xxxxxxxxx', keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        GoldInput(label: 'البريد الإلكتروني',  controller: _emailCtrl,   hint: 'example@email.com', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        GoldInput(label: 'العنوان الكامل',      controller: _addressCtrl, hint: 'المدينة — الحي — الشارع', maxLines: 2),
        const SizedBox(height: 20),

        // ── جهة الطوارئ ──────────────────────────────────────────
        _sub('جهة الاتصال في الطوارئ'),
        const SizedBox(height: 12),
        GoldInput(label: 'الاسم الكامل',  controller: _emergencyNameCtrl,     hint: 'اسم الشخص'),
        const SizedBox(height: 10),
        GoldInput(label: 'صلة القرابة',   controller: _emergencyRelationCtrl,  hint: 'مثال: الأم، الأخ، الصديق'),
        const SizedBox(height: 10),
        GoldInput(label: 'رقم الهاتف',    controller: _emergencyPhoneCtrl,     hint: '+966xxxxxxxxx', keyboardType: TextInputType.phone),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _hdr(String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
      const SizedBox(height: 4),
      Text(sub,   style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
      const SizedBox(height: 16),
      const Divider(color: AppColors.border),
    ]),
  );

  Widget _sub(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      const Expanded(child: Divider(color: AppColors.border)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent, fontFamily: 'Tajawal')),
    ]),
  );

  Widget _toggle(String label, bool val, ValueChanged<bool> onChange) =>
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
            Icon(val ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20, color: val ? AppColors.accent : AppColors.textMuted),
            const SizedBox(width: 10),
            const Spacer(),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: val ? FontWeight.w600 : FontWeight.normal,
                color: val ? AppColors.text : AppColors.textSecondary, fontFamily: 'Tajawal')),
          ]),
        ),
      );

  Widget _radio(String label, List<String> opts, List<String> vals, String cur, ValueChanged<String> onChange) =>
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
          children: List.generate(opts.length, (i) {
            final sel = cur == vals[i];
            return GestureDetector(
              onTap: () => onChange(vals[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.accent.withOpacity(0.15) : AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? AppColors.accent : AppColors.border, width: sel ? 1.5 : 1)),
                child: Text(opts[i], style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    color: sel ? AppColors.accent : AppColors.textSecondary, fontFamily: 'Tajawal')),
              ),
            );
          }),
        ),
      ]);
}

class _CounterWidget extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _CounterWidget({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    _CBtn(icon: Icons.add, onTap: () => onChanged(value + 1)),
    const SizedBox(width: 8),
    Container(
      width: 40, height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'Tajawal')),
    ),
    const SizedBox(width: 8),
    _CBtn(icon: Icons.remove, onTap: () { if (value > 0) onChanged(value - 1); }),
  ]);
}

class _CBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.accent.withOpacity(0.3))),
      child: Icon(icon, size: 16, color: AppColors.accent),
    ),
  );
}
