import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../widgets/gold_input.dart';

class Section6Behavioral extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const Section6Behavioral({super.key, this.initialData, required this.onChanged});

  @override
  State<Section6Behavioral> createState() => _Section6State();
}

class _Section6State extends State<Section6Behavioral> {
  String _conflictStyle = '';
  String _authorityResponse = '';
  String _teamRole = '';
  bool _hasCriminalRecord = false;
  bool _hasViolenceHistory = false;
  bool _hasSubstanceHistory = false;
  final _criminalCtrl = TextEditingController();
  final _violenceCtrl = TextEditingController();
  final _substanceCtrl = TextEditingController();
  final _behaviorChangeCtrl = TextEditingController();
  final _ethicsCtrl = TextEditingController();
  final _decisionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _conflictStyle = d['conflict_style'] ?? '';
      _authorityResponse = d['authority_response'] ?? '';
      _teamRole = d['team_role'] ?? '';
      _hasCriminalRecord = d['has_criminal_record'] ?? false;
      _hasViolenceHistory = d['has_violence_history'] ?? false;
      _hasSubstanceHistory = d['has_substance_history'] ?? false;
      _criminalCtrl.text = d['criminal_detail'] ?? '';
      _violenceCtrl.text = d['violence_detail'] ?? '';
      _substanceCtrl.text = d['substance_detail'] ?? '';
      _behaviorChangeCtrl.text = d['behavior_change'] ?? '';
      _ethicsCtrl.text = d['personal_ethics'] ?? '';
      _decisionCtrl.text = d['decision_under_pressure'] ?? '';
    }
    for (final c in [_criminalCtrl, _violenceCtrl, _substanceCtrl, _behaviorChangeCtrl, _ethicsCtrl, _decisionCtrl]) {
      c.addListener(_notify);
    }
  }

  void _notify() {
    widget.onChanged({
      'conflict_style': _conflictStyle,
      'authority_response': _authorityResponse,
      'team_role': _teamRole,
      'has_criminal_record': _hasCriminalRecord,
      'criminal_detail': _criminalCtrl.text,
      'has_violence_history': _hasViolenceHistory,
      'violence_detail': _violenceCtrl.text,
      'has_substance_history': _hasSubstanceHistory,
      'substance_detail': _substanceCtrl.text,
      'behavior_change': _behaviorChangeCtrl.text,
      'personal_ethics': _ethicsCtrl.text,
      'decision_under_pressure': _decisionCtrl.text,
    });
  }

  @override
  void dispose() {
    for (final c in [_criminalCtrl, _violenceCtrl, _substanceCtrl, _behaviorChangeCtrl, _ethicsCtrl, _decisionCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFDD6B20);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _hdr(),
        _opts('أسلوب التعامل مع النزاعات', ['تجنب', 'تسوية', 'تعاون', 'مواجهة', 'تنازل'], _conflictStyle, orange, (v) { setState(() => _conflictStyle = v); _notify(); }),
        const SizedBox(height: 14),
        _opts('الاستجابة للسلطة والقيادة', ['امتثال كامل', 'امتثال مشروط', 'تشكيك بناء', 'مقاومة'], _authorityResponse, orange, (v) { setState(() => _authorityResponse = v); _notify(); }),
        const SizedBox(height: 14),
        _opts('دورك في الفريق عادة', ['قائد', 'منسق', 'منفذ', 'مبدع', 'محلل'], _teamRole, orange, (v) { setState(() => _teamRole = v); _notify(); }),
        const SizedBox(height: 16),
        _boolRow('هل لديك سجل جنائي أو مخالفات قانونية؟', _hasCriminalRecord, (v) { setState(() => _hasCriminalRecord = v); _notify(); }),
        if (_hasCriminalRecord) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل السجل الجنائي', controller: _criminalCtrl, hint: 'التهمة، التاريخ، والحكم', maxLines: 2),
        ],
        const SizedBox(height: 12),
        _boolRow('هل لديك تاريخ مع العنف أو الاعتداء؟', _hasViolenceHistory, (v) { setState(() => _hasViolenceHistory = v); _notify(); }),
        if (_hasViolenceHistory) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل تاريخ العنف', controller: _violenceCtrl, hint: 'وصف موجز للحادثة/الحوادث', maxLines: 2),
        ],
        const SizedBox(height: 12),
        _boolRow('هل سبق لك تعاطي مواد مخدرة أو مسكرة؟', _hasSubstanceHistory, (v) { setState(() => _hasSubstanceHistory = v); _notify(); }),
        if (_hasSubstanceHistory) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل تاريخ المواد', controller: _substanceCtrl, hint: 'الفترة والنوع والوضع الحالي', maxLines: 2),
        ],
        const SizedBox(height: 14),
        GoldInput(label: 'أبرز تغيير في حياتك خلال 3 سنوات', controller: _behaviorChangeCtrl, hint: 'كيف تطور سلوكك واتجاهاتك؟', maxLines: 3),
        const SizedBox(height: 14),
        GoldInput(label: 'مبادئك الأخلاقية الشخصية', controller: _ethicsCtrl, hint: 'ما الخطوط التي لن تتجاوزها في أي ظرف؟', maxLines: 3),
        const SizedBox(height: 14),
        GoldInput(label: 'اتخاذ القرار تحت الضغط', controller: _decisionCtrl, hint: 'صف موقفاً صعباً كيف تعاملت معه', maxLines: 3),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _hdr() => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      const Text('التاريخ السلوكي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
      const SizedBox(height: 4),
      const Text('الأنماط السلوكية والتاريخ الشخصي', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
      const SizedBox(height: 16),
      const Divider(color: AppColors.border),
    ]),
  );

  Widget _opts(String label, List<String> opts, String val, Color color, ValueChanged<String> onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
          children: opts.map((o) => GestureDetector(
            onTap: () => onChange(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: val == o ? color.withOpacity(0.15) : AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: val == o ? color : AppColors.border, width: val == o ? 1.5 : 1),
              ),
              child: Text(o, style: TextStyle(fontSize: 13, fontWeight: val == o ? FontWeight.w600 : FontWeight.normal,
                  color: val == o ? color : AppColors.textSecondary, fontFamily: 'Tajawal')),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _boolRow(String label, bool val, ValueChanged<bool> onChange) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Switch(value: val, onChanged: onChange, activeColor: const Color(0xFFDD6B20)),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text, fontFamily: 'Tajawal'), textAlign: TextAlign.right)),
      ],
    );
  }
}
