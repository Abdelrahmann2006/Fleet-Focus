import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../services/loyalty_economy_service.dart';

/// Tab 30 — اقتصاد الثواب والعقاب
///
/// • عملات الولاء (Loyalty Coins)
/// • سجل الديون (Debt Ledger)
/// • الدرجة التراكمية الكاملة
/// • عقوبة مالية
class DpcEconomyTab extends StatefulWidget {
  final String uid;
  final String assetName;
  const DpcEconomyTab({super.key, required this.uid, required this.assetName});

  @override
  State<DpcEconomyTab> createState() => _DpcEconomyTabState();
}

class _DpcEconomyTabState extends State<DpcEconomyTab> {
  final _reasonCtrl  = TextEditingController();
  final _amountCtrl  = TextEditingController();
  final _fineCtrl    = TextEditingController();
  bool _loading      = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _amountCtrl.dispose();
    _fineCtrl.dispose();
    super.dispose();
  }

  Future<void> _award() async {
    final reason = _reasonCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text) ?? 0;
    if (reason.isEmpty || amount <= 0) return;
    setState(() => _loading = true);
    await LoyaltyEconomyService.instance.awardCoins(widget.uid, amount, reason);
    _reasonCtrl.clear();
    _amountCtrl.clear();
    if (mounted) { setState(() => _loading = false); _feedback('✓ مُنح $amount نقطة'); }
  }

  Future<void> _addDebt() async {
    final reason = _reasonCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text) ?? 0;
    if (reason.isEmpty || amount <= 0) return;
    setState(() => _loading = true);
    await LoyaltyEconomyService.instance.addDebt(widget.uid, amount, reason);
    _reasonCtrl.clear();
    _amountCtrl.clear();
    if (mounted) { setState(() => _loading = false); _feedback('⚠ دين: $amount نقطة'); }
  }

  Future<void> _imposeFine() async {
    final amount = double.tryParse(_fineCtrl.text) ?? 0;
    if (amount <= 0) return;
    await LoyaltyEconomyService.instance.imposeFine(widget.uid, amount, 'SAR');
    _fineCtrl.clear();
    if (mounted) _feedback('⛔ غرامة مالية: $amount ر.س');
  }

  void _feedback(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return const Center(child: Text('اختر عنصراً', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

        // ── البطاقة الاقتصادية الرئيسية ─────────────────────────────────
        _EcoHdr(label: 'الوضع الاقتصادي', icon: Icons.account_balance_wallet_outlined),
        const SizedBox(height: 8),
        StreamBuilder<EconomyState>(
          stream: LoyaltyEconomyService.instance.watchState(widget.uid),
          builder: (_, snap) {
            final state = snap.data ?? const EconomyState(coins: 0, debt: 0, frozen: false, monetaryFines: []);
            return _EconomyCard(state: state,
                onSettle: (a) => LoyaltyEconomyService.instance.settleDebt(widget.uid, a));
          },
        ),
        const SizedBox(height: 20),

        // ── إضافة معاملة ─────────────────────────────────────────────────
        _EcoHdr(label: 'إضافة معاملة', icon: Icons.add_circle_outline),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            TextField(controller: _reasonCtrl, textAlign: TextAlign.right, textDirection: TextDirection.rtl,
              style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
              decoration: const InputDecoration(hintText: 'السبب',
                hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal'),
                isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
            const SizedBox(height: 8),
            TextField(controller: _amountCtrl, textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
              decoration: const InputDecoration(hintText: 'المقدار',
                hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal'),
                isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _loading ? null : _addDebt,
                icon: const Icon(Icons.remove, size: 14),
                label: const Text('دين', style: TextStyle(fontFamily: 'Tajawal')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.12),
                  foregroundColor: AppColors.error, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.4))),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: _loading ? null : _award,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('نقاط ولاء', style: TextStyle(fontFamily: 'Tajawal')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success.withValues(alpha: 0.12),
                  foregroundColor: AppColors.success, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.success.withValues(alpha: 0.4))),
                ),
              )),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // ── غرامة مالية ─────────────────────────────────────────────────
        _EcoHdr(label: 'غرامة مالية', icon: Icons.money_off_outlined),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            ElevatedButton(
              onPressed: _imposeFine,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('تطبيق', style: TextStyle(fontFamily: 'Tajawal')),
            ),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _fineCtrl, textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal'),
              decoration: const InputDecoration(
                hintText: 'المبلغ (ر.س)',
                hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11),
                isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            )),
          ]),
        ),
        const SizedBox(height: 20),

        // ── سجل المعاملات ────────────────────────────────────────────────
        _EcoHdr(label: 'سجل المعاملات', icon: Icons.history_outlined),
        const SizedBox(height: 8),
        StreamBuilder<List<EconomyTransaction>>(
          stream: LoyaltyEconomyService.instance.watchHistory(widget.uid),
          builder: (_, snap) {
            final txs = snap.data ?? [];
            if (txs.isEmpty) {
              return Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: const Text('لا توجد معاملات بعد.',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)));
            }
            return Column(children: txs.map((t) => _TxRow(tx: t)).toList());
          },
        ),
        const SizedBox(height: 20),

        // ── الدرجة التراكمية ─────────────────────────────────────────────
        _EcoHdr(label: 'الدرجة التراكمية الكاملة', icon: Icons.leaderboard_outlined),
        const SizedBox(height: 8),
        StreamBuilder<int>(
          stream: LoyaltyEconomyService.instance.watchMasterScore(widget.uid),
          builder: (_, snap) {
            final score = snap.data ?? 0;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.accent.withValues(alpha: 0.12), AppColors.backgroundCard]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.emoji_events_outlined, color: AppColors.accent, size: 28),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$score', style: const TextStyle(
                      color: AppColors.accent, fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w800, fontSize: 32)),
                  const Text('نقطة تراكمية — لا تُصفَّر أبداً',
                      style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
                ]),
              ]),
            );
          },
        ),
      ]),
    );
  }
}

class _EconomyCard extends StatelessWidget {
  final EconomyState state;
  final void Function(int) onSettle;
  const _EconomyCard({required this.state, required this.onSettle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: state.frozen ? AppColors.error.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          if (state.frozen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('الامتيازات مجمَّدة',
                  style: TextStyle(color: AppColors.error, fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          const Spacer(),
          _EcoStat(label: 'ديون', value: state.debt, color: AppColors.error),
          const SizedBox(width: 16),
          _EcoStat(label: 'ولاء', value: state.coins, color: AppColors.success),
        ]),
        if (state.debt > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            ElevatedButton(
              onPressed: () => onSettle(state.debt),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('سداد كامل الدين', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
            ),
          ]),
        ],
        if (state.monetaryFines.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...state.monetaryFines.where((f) => !(f['cleared'] as bool? ?? false)).map((f) => Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const Spacer(),
              Text('غرامة: ${f['amount']} ${f['currency']}',
                  style: const TextStyle(color: AppColors.error, fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          )),
        ],
      ]),
    );
  }
}

class _EcoStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _EcoStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$value', style: TextStyle(color: color, fontFamily: 'Tajawal',
        fontWeight: FontWeight.w800, fontSize: 24)),
    Text(label, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
  ]);
}

class _TxRow extends StatelessWidget {
  final EconomyTransaction tx;
  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final color = tx.type == 'AWARD' ? AppColors.success
        : tx.type == 'DEBT'  ? AppColors.error
        : AppColors.info;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Text('${tx.type == 'AWARD' ? '+' : '-'}${tx.amount}',
            style: TextStyle(color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(width: 10),
        const Spacer(),
        Flexible(child: Text(tx.reason, textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 11))),
      ]),
    );
  }
}

class _EcoHdr extends StatelessWidget {
  final String label;
  final IconData icon;
  const _EcoHdr({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Spacer(),
    Text(label, style: const TextStyle(color: AppColors.textSecondary,
        fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13)),
    const SizedBox(width: 6),
    Icon(icon, color: AppColors.accent, size: 16),
  ]);
}
