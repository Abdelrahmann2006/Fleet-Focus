import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../widgets/gold_input.dart';

class Section5Socioeconomic extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const Section5Socioeconomic({super.key, this.initialData, required this.onChanged});

  @override
  State<Section5Socioeconomic> createState() => _Section5State();
}

class _Section5State extends State<Section5Socioeconomic> {
  String _incomeLevel = '';
  String _housingType = '';
  String _familySize = '';
  String _socialStatus = '';
  bool _hasDependents = false;
  bool _hasDebts = false;
  final _dependentsCtrl = TextEditingController();
  final _socialSupportCtrl = TextEditingController();
  final _challengesCtrl = TextEditingController();
  final _financialGoalsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _incomeLevel = d['income_level'] ?? '';
      _housingType = d['housing_type'] ?? '';
      _familySize = d['family_size'] ?? '';
      _socialStatus = d['social_status'] ?? '';
      _hasDependents = d['has_dependents'] ?? false;
      _hasDebts = d['has_debts'] ?? false;
      _dependentsCtrl.text = d['dependents_detail'] ?? '';
      _socialSupportCtrl.text = d['social_support'] ?? '';
      _challengesCtrl.text = d['current_challenges'] ?? '';
      _financialGoalsCtrl.text = d['financial_goals'] ?? '';
    }
    for (final c in [_dependentsCtrl, _socialSupportCtrl, _challengesCtrl, _financialGoalsCtrl]) {
      c.addListener(_notify);
    }
  }

  void _notify() {
    widget.onChanged({
      'income_level': _incomeLevel,
      'housing_type': _housingType,
      'family_size': _familySize,
      'social_status': _socialStatus,
      'has_dependents': _hasDependents,
      'dependents_detail': _dependentsCtrl.text,
      'has_debts': _hasDebts,
      'social_support': _socialSupportCtrl.text,
      'current_challenges': _challengesCtrl.text,
      'financial_goals': _financialGoalsCtrl.text,
    });
  }

  @override
  void dispose() {
    for (final c in [_dependentsCtrl, _socialSupportCtrl, _challengesCtrl, _financialGoalsCtrl]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF38A169);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _hdr(),
        _opts('المستوى المادي', ['منخفض', 'متوسط', 'جيد', 'ممتاز'], _incomeLevel, green, (v) { setState(() => _incomeLevel = v); _notify(); }),
        const SizedBox(height: 14),
        _opts('نوع السكن', ['ملك', 'إيجار', 'مع الأسرة', 'سكن جامعي', 'أخرى'], _housingType, green, (v) { setState(() => _housingType = v); _notify(); }),
        const SizedBox(height: 14),
        _opts('حجم الأسرة', ['فرد واحد', '2-4', '5-7', '8+'], _familySize, green, (v) { setState(() => _familySize = v); _notify(); }),
        const SizedBox(height: 14),
        _opts('الوضع الاجتماعي العام', ['مستقر جداً', 'مستقر', 'متذبذب', 'صعب'], _socialStatus, green, (v) { setState(() => _socialStatus = v); _notify(); }),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Switch(value: _hasDependents, onChanged: (v) { setState(() => _hasDependents = v); _notify(); }, activeColor: green),
          const Text('هل تعول أشخاصاً آخرين؟', style: TextStyle(fontSize: 14, color: AppColors.text, fontFamily: 'Tajawal')),
        ]),
        if (_hasDependents) ...[
          const SizedBox(height: 10),
          GoldInput(label: 'تفاصيل المعالين', controller: _dependentsCtrl, hint: 'العدد وصلة القرابة', maxLines: 2),
        ],
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Switch(value: _hasDebts, onChanged: (v) { setState(() => _hasDebts = v); _notify(); }, activeColor: green),
          const Text('هل لديك ديون أو التزامات مالية؟', style: TextStyle(fontSize: 14, color: AppColors.text, fontFamily: 'Tajawal')),
        ]),
        const SizedBox(height: 14),
        GoldInput(label: 'شبكة الدعم الاجتماعي', controller: _socialSupportCtrl, hint: 'من يمكنك الاستناد إليه عند الأزمات؟', maxLines: 2),
        const SizedBox(height: 14),
        GoldInput(label: 'تحديات حالية', controller: _challengesCtrl, hint: 'ما أبرز تحديات حياتك الحالية؟', maxLines: 3),
        const SizedBox(height: 14),
        GoldInput(label: 'أهداف مستقبلية', controller: _financialGoalsCtrl, hint: 'ما الذي تسعى لتحقيقه في المستقبل؟', maxLines: 3),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _hdr() => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      const Text('الوضع الاجتماعي والاقتصادي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
      const SizedBox(height: 4),
      const Text('الظروف المعيشية والبيئة الاجتماعية', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
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
}
