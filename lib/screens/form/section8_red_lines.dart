import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../widgets/gold_input.dart';

class Section8RedLines extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const Section8RedLines({super.key, this.initialData, required this.onChanged});

  @override
  State<Section8RedLines> createState() => _Section8State();
}

class _Section8State extends State<Section8RedLines> {
  final _personalLimitsCtrl = TextEditingController();
  final _emotionalTriggersCtrl = TextEditingController();
  final _dealBreakersCtrl = TextEditingController();
  final _physicalLimitsCtrl = TextEditingController();
  final _spiritualLimitsCtrl = TextEditingController();
  final List<String> _selectedCategories = [];

  static const _categories = [
    'المسائل الدينية والعقدية',
    'مسائل الشرف والكرامة',
    'المحتوى الإباحي أو الجنسي',
    'الإيذاء الجسدي',
    'العنف أو التهديد',
    'الإكراه النفسي المتطرف',
    'التجاوز على الأسرة',
    'انتهاك الخصوصية المطلقة',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _personalLimitsCtrl.text = d['personal_limits'] ?? '';
      _emotionalTriggersCtrl.text = d['emotional_triggers'] ?? '';
      _dealBreakersCtrl.text = d['deal_breakers'] ?? '';
      _physicalLimitsCtrl.text = d['physical_limits'] ?? '';
      _spiritualLimitsCtrl.text = d['spiritual_limits'] ?? '';
      final cats = d['limit_categories'];
      if (cats != null) _selectedCategories.addAll(List<String>.from(cats));
    }
    for (final c in [_personalLimitsCtrl, _emotionalTriggersCtrl, _dealBreakersCtrl, _physicalLimitsCtrl, _spiritualLimitsCtrl]) {
      c.addListener(_notify);
    }
  }

  void _notify() {
    widget.onChanged({
      'personal_limits': _personalLimitsCtrl.text,
      'emotional_triggers': _emotionalTriggersCtrl.text,
      'deal_breakers': _dealBreakersCtrl.text,
      'physical_limits': _physicalLimitsCtrl.text,
      'spiritual_limits': _spiritualLimitsCtrl.text,
      'limit_categories': List.from(_selectedCategories),
    });
  }

  @override
  void dispose() {
    for (final c in [_personalLimitsCtrl, _emotionalTriggersCtrl, _dealBreakersCtrl, _physicalLimitsCtrl, _spiritualLimitsCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE53E3E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('الخطوط الحمراء الشخصية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
        const SizedBox(height: 4),
        const Text('حدد الأشياء التي لن تقبلها تحت أي ظرف', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        const SizedBox(height: 16),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: red.withOpacity(0.25)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppColors.warning, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('هذه المعلومات سرية وتُستخدم فقط لضمان سلامتك وعدم تجاوز حدودك خلال البرنامج.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal'), textAlign: TextAlign.right)),
          ]),
        ),

        const SizedBox(height: 20),
        const Text('فئات الخطوط الحمراء (اختر ما ينطبق عليك)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
          children: _categories.map((c) {
            final selected = _selectedCategories.contains(c);
            return GestureDetector(
              onTap: () {
                setState(() {
                  selected ? _selectedCategories.remove(c) : _selectedCategories.add(c);
                });
                _notify();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? red.withOpacity(0.15) : AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? red : AppColors.border, width: selected ? 1.5 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(c, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? red : AppColors.textSecondary, fontFamily: 'Tajawal')),
                  if (selected) ...[const SizedBox(width: 4), const Icon(Icons.close, size: 12, color: Color(0xFFE53E3E))],
                ]),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        GoldInput(label: 'حدودك الشخصية والنفسية', controller: _personalLimitsCtrl,
            hint: 'ما هي الأشياء التي تعتبرها انتهاكاً لخصوصيتك أو كرامتك؟', maxLines: 3),
        const SizedBox(height: 14),
        GoldInput(label: 'المحفزات العاطفية السلبية', controller: _emotionalTriggersCtrl,
            hint: 'ما الذي يثير ردود أفعال عاطفية حادة لديك؟', maxLines: 3),
        const SizedBox(height: 14),
        GoldInput(label: 'نقاط الانسحاب المطلق', controller: _dealBreakersCtrl,
            hint: 'في أي حالة ستنسحب من البرنامج فوراً؟', maxLines: 3),
        const SizedBox(height: 14),
        GoldInput(label: 'الحدود الجسدية', controller: _physicalLimitsCtrl,
            hint: 'ما الأنشطة الجسدية أو التدخلات التي لا تقبلها؟', maxLines: 2),
        const SizedBox(height: 14),
        GoldInput(label: 'الحدود الدينية والروحية', controller: _spiritualLimitsCtrl,
            hint: 'ما الذي يتعارض مع معتقداتك الدينية أو قيمك الروحية؟', maxLines: 2),
        const SizedBox(height: 20),
      ],
    );
  }
}
