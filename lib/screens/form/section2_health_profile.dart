import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../widgets/gold_input.dart';

class Section2HealthProfile extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const Section2HealthProfile({super.key, this.initialData, required this.onChanged});

  @override
  State<Section2HealthProfile> createState() => _Section2State();
}

class _Section2State extends State<Section2HealthProfile> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _bloodTypeCtrl = TextEditingController();
  final _diseasesCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _surgeriesCtrl = TextEditingController();
  String _bloodType = '';
  bool _hasChronicDiseases = false;
  bool _hasAllergies = false;
  bool _hasSurgeries = false;
  bool _disabled = false;
  final _disabilityCtrl = TextEditingController();

  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _heightCtrl.text = d['height']?.toString() ?? '';
      _weightCtrl.text = d['weight']?.toString() ?? '';
      _bloodType = d['blood_type'] ?? '';
      _hasChronicDiseases = d['has_chronic_diseases'] ?? false;
      _diseasesCtrl.text = d['diseases_detail'] ?? '';
      _hasSurgeries = d['has_surgeries'] ?? false;
      _surgeriesCtrl.text = d['surgeries_detail'] ?? '';
      _hasAllergies = d['has_allergies'] ?? false;
      _allergiesCtrl.text = d['allergies_detail'] ?? '';
      _medicationsCtrl.text = d['current_medications'] ?? '';
      _disabled = d['has_disability'] ?? false;
      _disabilityCtrl.text = d['disability_detail'] ?? '';
    }
    for (final c in [_heightCtrl, _weightCtrl, _diseasesCtrl, _medicationsCtrl, _allergiesCtrl, _surgeriesCtrl, _disabilityCtrl]) {
      c.addListener(_notify);
    }
  }

  void _notify() {
    widget.onChanged({
      'height': _heightCtrl.text,
      'weight': _weightCtrl.text,
      'blood_type': _bloodType,
      'has_chronic_diseases': _hasChronicDiseases,
      'diseases_detail': _diseasesCtrl.text,
      'has_surgeries': _hasSurgeries,
      'surgeries_detail': _surgeriesCtrl.text,
      'has_allergies': _hasAllergies,
      'allergies_detail': _allergiesCtrl.text,
      'current_medications': _medicationsCtrl.text,
      'has_disability': _disabled,
      'disability_detail': _disabilityCtrl.text,
    });
  }

  @override
  void dispose() {
    for (final c in [_heightCtrl, _weightCtrl, _diseasesCtrl, _medicationsCtrl, _allergiesCtrl, _surgeriesCtrl, _disabilityCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _header(),
        Row(
          children: [
            Expanded(child: GoldInput(label: 'الوزن (كغ)', controller: _weightCtrl, hint: 'مثال: 75', keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: GoldInput(label: 'الطول (سم)', controller: _heightCtrl, hint: 'مثال: 175', keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 14),
        const Text('فصيلة الدم', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8, alignment: WrapAlignment.end,
          children: _bloodTypes.map((t) => GestureDetector(
            onTap: () { setState(() => _bloodType = t); _notify(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _bloodType == t ? const Color(0xFFE53E3E).withOpacity(0.15) : AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _bloodType == t ? const Color(0xFFE53E3E) : AppColors.border,
                    width: _bloodType == t ? 1.5 : 1),
              ),
              child: Text(t, style: TextStyle(fontSize: 13, fontWeight: _bloodType == t ? FontWeight.w700 : FontWeight.normal,
                  color: _bloodType == t ? const Color(0xFFE53E3E) : AppColors.textSecondary, fontFamily: 'Tajawal')),
            ),
          )).toList(),
        ),
        const SizedBox(height: 16),
        _toggleRow('هل تعاني من أمراض مزمنة؟', _hasChronicDiseases, (v) { setState(() => _hasChronicDiseases = v); _notify(); }),
        if (_hasChronicDiseases) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل الأمراض المزمنة', controller: _diseasesCtrl, hint: 'اذكر الأمراض بالتفصيل', maxLines: 3),
        ],
        const SizedBox(height: 12),
        _toggleRow('هل تتناول أدوية بشكل دوري؟', _medicationsCtrl.text.isNotEmpty, (_) {}),
        const SizedBox(height: 10),
        GoldInput(label: 'الأدوية الحالية', controller: _medicationsCtrl, hint: 'اذكر الأدوية والجرعات (اختياري)'),
        const SizedBox(height: 12),
        _toggleRow('هل لديك حساسية من أي شيء؟', _hasAllergies, (v) { setState(() => _hasAllergies = v); _notify(); }),
        if (_hasAllergies) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل الحساسية', controller: _allergiesCtrl, hint: 'نوع الحساسية ودرجتها', maxLines: 2),
        ],
        const SizedBox(height: 12),
        _toggleRow('هل أجريت عمليات جراحية سابقة؟', _hasSurgeries, (v) { setState(() => _hasSurgeries = v); _notify(); }),
        if (_hasSurgeries) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل العمليات', controller: _surgeriesCtrl, hint: 'نوع العملية وتاريخها', maxLines: 2),
        ],
        const SizedBox(height: 12),
        _toggleRow('هل لديك إعاقة أو حالة خاصة؟', _disabled, (v) { setState(() => _disabled = v); _notify(); }),
        if (_disabled) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل الإعاقة / الحالة', controller: _disabilityCtrl, hint: 'وصف الحالة ودرجتها', maxLines: 2),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      const Text('الملف الصحي والجسدي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
      const SizedBox(height: 4),
      const Text('المعلومات الطبية السرية — تُستخدم للسلامة الشخصية فقط', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
      const SizedBox(height: 16),
      const Divider(color: AppColors.border),
    ]),
  );

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Switch(value: value, onChanged: (v) { onChanged(v); _notify(); }, activeColor: AppColors.accent),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text, fontFamily: 'Tajawal'), textAlign: TextAlign.right)),
      ],
    );
  }
}
