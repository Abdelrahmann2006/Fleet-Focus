import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class Section10Verification extends StatefulWidget {
  final Map<String, dynamic> formData;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const Section10Verification({super.key, required this.formData, required this.onChanged});

  @override
  State<Section10Verification> createState() => _Section10State();
}

class _Section10State extends State<Section10Verification> {
  bool _finalConfirmation = false;
  bool _accuracyDeclaration = false;
  bool _responsibilityAcceptance = false;

  final List<Map<String, dynamic>> _sections = [
    {'key': 'basic_info', 'title': 'البيانات الأساسية', 'icon': Icons.person_outline, 'color': Color(0xFFC9A84C)},
    {'key': 'health_profile', 'title': 'الصحة الجسدية', 'icon': Icons.favorite_outline, 'color': Color(0xFFE53E3E)},
    {'key': 'psych_profile', 'title': 'الصحة النفسية', 'icon': Icons.psychology_outlined, 'color': Color(0xFF805AD5)},
    {'key': 'skills', 'title': 'المهارات والقدرات', 'icon': Icons.star_outline, 'color': Color(0xFF3182CE)},
    {'key': 'socioeconomic', 'title': 'الوضع الاجتماعي', 'icon': Icons.home_outlined, 'color': Color(0xFF38A169)},
    {'key': 'behavioral', 'title': 'السلوك والتاريخ', 'icon': Icons.history_outlined, 'color': Color(0xFFDD6B20)},
    {'key': 'consent', 'title': 'الموافقة المستنيرة', 'icon': Icons.handshake_outlined, 'color': Color(0xFF319795)},
    {'key': 'red_lines', 'title': 'الخطوط الحمراء', 'icon': Icons.block_outlined, 'color': Color(0xFFE53E3E)},
    {'key': 'advanced_psych', 'title': 'التقييم النفسي المتقدم', 'icon': Icons.psychology, 'color': Color(0xFF805AD5)},
  ];

  bool _sectionComplete(String key) {
    final data = widget.formData[key];
    if (data == null) return false;
    return (data as Map<String, dynamic>).values.any((v) => v != null && v.toString().isNotEmpty && v != false);
  }

  int get _completedCount => _sections.where((s) => _sectionComplete(s['key'] as String)).length;
  bool get _canSubmit => _completedCount == _sections.length && _finalConfirmation && _accuracyDeclaration && _responsibilityAcceptance;

  @override
  void initState() {
    super.initState();
    _notify();
  }

  void _notify() {
    widget.onChanged({
      'final_confirmation': _finalConfirmation,
      'accuracy_declaration': _accuracyDeclaration,
      'responsibility_acceptance': _responsibilityAcceptance,
      'completed_sections': _completedCount,
      'ready_to_submit': _canSubmit,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('مراجعة الاستمارة والإرسال', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
        const SizedBox(height: 4),
        const Text('راجع استمارتك قبل الإرسال النهائي', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        const SizedBox(height: 16),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),

        // Progress summary
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_completedCount/${_sections.length}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent, fontFamily: 'Tajawal')),
                  const Text('ملخص الإكمال', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'Tajawal')),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _completedCount / _sections.length,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Section status list
        ..._sections.map((s) {
          final complete = _sectionComplete(s['key'] as String);
          final color = s['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: complete ? AppColors.success.withOpacity(0.06) : AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: complete ? AppColors.success.withOpacity(0.25) : AppColors.border),
            ),
            child: Row(
              children: [
                Icon(complete ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: complete ? AppColors.success : AppColors.textMuted, size: 18),
                const Spacer(),
                Text(s['title'] as String,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: complete ? AppColors.text : AppColors.textMuted, fontFamily: 'Tajawal')),
                const SizedBox(width: 10),
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(s['icon'] as IconData, color: color, size: 16),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 20),

        if (!_canSubmit && _completedCount == _sections.length) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('أكمل تأكيدات الإرسال أدناه قبل المتابعة.',
                  style: TextStyle(fontSize: 13, color: AppColors.warning, fontFamily: 'Tajawal'), textAlign: TextAlign.right)),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        if (_completedCount < _sections.length) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('${_sections.length - _completedCount} أقسام لم تكتمل. عد إليها قبل الإرسال.',
                  style: const TextStyle(fontSize: 13, color: AppColors.error, fontFamily: 'Tajawal'), textAlign: TextAlign.right)),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // Final checkboxes
        _confirmItem('أُقر بأن جميع المعلومات المُدخلة صحيحة ودقيقة وكاملة', _accuracyDeclaration, (v) { setState(() => _accuracyDeclaration = v); _notify(); }),
        const SizedBox(height: 10),
        _confirmItem('أتحمل المسؤولية الكاملة عن أي معلومات مضللة أو غير دقيقة', _responsibilityAcceptance, (v) { setState(() => _responsibilityAcceptance = v); _notify(); }),
        const SizedBox(height: 10),
        _confirmItem('أوافق على الإرسال النهائي للاستمارة وأُدرك أنه لا يمكن تعديلها بعد الإرسال', _finalConfirmation, (v) { setState(() => _finalConfirmation = v); _notify(); }),

        const SizedBox(height: 20),

        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _canSubmit ? AppColors.accent.withOpacity(0.1) : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _canSubmit ? AppColors.accent.withOpacity(0.4) : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(_canSubmit ? Icons.send_outlined : Icons.lock_outlined,
                  color: _canSubmit ? AppColors.accent : AppColors.textMuted, size: 22),
              const SizedBox(width: 12),
              Text(
                _canSubmit ? 'الاستمارة جاهزة للإرسال!' : 'أكمل جميع الأقسام والتأكيدات',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: _canSubmit ? AppColors.accent : AppColors.textMuted, fontFamily: 'Tajawal'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _confirmItem(String label, bool val, ValueChanged<bool> onChange) {
    return GestureDetector(
      onTap: () => onChange(!val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: val ? AppColors.accent.withOpacity(0.06) : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: val ? AppColors.accent.withOpacity(0.3) : AppColors.border, width: val ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Checkbox(value: val, onChanged: (v) => onChange(v ?? false),
                activeColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 10),
            Expanded(child: Text(label,
                style: TextStyle(fontSize: 13, color: val ? AppColors.text : AppColors.textSecondary, fontFamily: 'Tajawal'),
                textAlign: TextAlign.right)),
          ],
        ),
      ),
    );
  }
}
