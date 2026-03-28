import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../widgets/gold_input.dart';

class Section3PsychProfile extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const Section3PsychProfile({super.key, this.initialData, required this.onChanged});

  @override
  State<Section3PsychProfile> createState() => _Section3State();
}

class _Section3State extends State<Section3PsychProfile> {
  String _mentalHealth = '';
  String _stressLevel = '';
  String _sleepQuality = '';
  bool _hasPsychHistory = false;
  bool _hasTherapy = false;
  bool _takingPsychMeds = false;
  final _psychHistoryCtrl = TextEditingController();
  final _therapyCtrl = TextEditingController();
  final _strengthsCtrl = TextEditingController();
  final _weaknessesCtrl = TextEditingController();
  final _copingCtrl = TextEditingController();
  final _motivationCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _mentalHealth = d['mental_health_status'] ?? '';
      _stressLevel = d['stress_level'] ?? '';
      _sleepQuality = d['sleep_quality'] ?? '';
      _hasPsychHistory = d['has_psych_history'] ?? false;
      _hasTherapy = d['has_therapy'] ?? false;
      _takingPsychMeds = d['taking_psych_meds'] ?? false;
      _psychHistoryCtrl.text = d['psych_history_detail'] ?? '';
      _therapyCtrl.text = d['therapy_detail'] ?? '';
      _strengthsCtrl.text = d['strengths'] ?? '';
      _weaknessesCtrl.text = d['weaknesses'] ?? '';
      _copingCtrl.text = d['coping_mechanisms'] ?? '';
      _motivationCtrl.text = d['motivation'] ?? '';
    }
    for (final c in [_psychHistoryCtrl, _therapyCtrl, _strengthsCtrl, _weaknessesCtrl, _copingCtrl, _motivationCtrl]) {
      c.addListener(_notify);
    }
  }

  void _notify() {
    widget.onChanged({
      'mental_health_status': _mentalHealth,
      'stress_level': _stressLevel,
      'sleep_quality': _sleepQuality,
      'has_psych_history': _hasPsychHistory,
      'psych_history_detail': _psychHistoryCtrl.text,
      'has_therapy': _hasTherapy,
      'therapy_detail': _therapyCtrl.text,
      'taking_psych_meds': _takingPsychMeds,
      'strengths': _strengthsCtrl.text,
      'weaknesses': _weaknessesCtrl.text,
      'coping_mechanisms': _copingCtrl.text,
      'motivation': _motivationCtrl.text,
    });
  }

  @override
  void dispose() {
    for (final c in [_psychHistoryCtrl, _therapyCtrl, _strengthsCtrl, _weaknessesCtrl, _copingCtrl, _motivationCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _header(),
        _ratingRow('الحالة النفسية العامة', ['ممتاز', 'جيد', 'متوسط', 'ضعيف'], _mentalHealth, (v) { setState(() => _mentalHealth = v); _notify(); }),
        const SizedBox(height: 14),
        _ratingRow('مستوى الضغط والتوتر', ['منخفض جداً', 'منخفض', 'متوسط', 'مرتفع', 'مرتفع جداً'], _stressLevel, (v) { setState(() => _stressLevel = v); _notify(); }),
        const SizedBox(height: 14),
        _ratingRow('جودة النوم', ['ممتاز', 'جيد', 'متوسط', 'سيء'], _sleepQuality, (v) { setState(() => _sleepQuality = v); _notify(); }),
        const SizedBox(height: 16),
        _boolRow('هل لديك تاريخ مرضي نفسي؟', _hasPsychHistory, (v) { setState(() => _hasPsychHistory = v); _notify(); }),
        if (_hasPsychHistory) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل التاريخ النفسي', controller: _psychHistoryCtrl, hint: 'اذكر التشخيصات السابقة', maxLines: 3),
        ],
        const SizedBox(height: 12),
        _boolRow('هل تلقيت جلسات علاج نفسي سابقاً؟', _hasTherapy, (v) { setState(() => _hasTherapy = v); _notify(); }),
        if (_hasTherapy) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل العلاج', controller: _therapyCtrl, hint: 'نوع العلاج ومدته', maxLines: 2),
        ],
        const SizedBox(height: 12),
        _boolRow('هل تتناول أدوية نفسية حالياً؟', _takingPsychMeds, (v) { setState(() => _takingPsychMeds = v); _notify(); }),
        const SizedBox(height: 16),
        GoldInput(label: 'نقاط قوتك الشخصية', controller: _strengthsCtrl, hint: 'ما الذي تتميز به؟', maxLines: 3),
        const SizedBox(height: 14),
        GoldInput(label: 'نقاط الضعف والتحديات', controller: _weaknessesCtrl, hint: 'ما الذي تعمل على تحسينه؟', maxLines: 3),
        const SizedBox(height: 14),
        GoldInput(label: 'طرق تعاملك مع الضغوط', controller: _copingCtrl, hint: 'كيف تتعامل مع صعوبات الحياة؟', maxLines: 3),
        const SizedBox(height: 14),
        GoldInput(label: 'دوافعك للمشاركة', controller: _motivationCtrl, hint: 'لماذا تريد المشاركة في هذا البرنامج؟', maxLines: 3),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      const Text('الملف النفسي والعاطفي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
      const SizedBox(height: 4),
      const Text('معلومات سرية تساعدنا في تقديم الدعم المناسب', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
      const SizedBox(height: 16),
      const Divider(color: AppColors.border),
    ]),
  );

  Widget _ratingRow(String label, List<String> opts, String val, ValueChanged<String> onChange) {
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
                color: val == o ? const Color(0xFF805AD5).withOpacity(0.15) : AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: val == o ? const Color(0xFF805AD5) : AppColors.border, width: val == o ? 1.5 : 1),
              ),
              child: Text(o, style: TextStyle(fontSize: 13, fontWeight: val == o ? FontWeight.w600 : FontWeight.normal,
                  color: val == o ? const Color(0xFF805AD5) : AppColors.textSecondary, fontFamily: 'Tajawal')),
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
        Switch(value: val, onChanged: onChange, activeColor: const Color(0xFF805AD5)),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text, fontFamily: 'Tajawal'), textAlign: TextAlign.right)),
      ],
    );
  }
}
