import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/colors.dart';

/// Tab 31 — المراقبة المتبادلة والتقارير المشتركة
///
/// • تقارير الأقران السرية (Peer Sabotage Protocol)
/// • جلسة نهاية اليوم — المحاسبة الجماعية
/// • مسافة الرفيق (Proximity Breach)
class DpcPeerSurveillanceTab extends StatefulWidget {
  final String leaderUid;
  const DpcPeerSurveillanceTab({super.key, required this.leaderUid});

  @override
  State<DpcPeerSurveillanceTab> createState() => _DpcPeerSurveillanceTabState();
}

class _DpcPeerSurveillanceTabState extends State<DpcPeerSurveillanceTab> {
  final _eodController = TextEditingController();
  bool _sendingEod = false;

  @override
  void dispose() {
    _eodController.dispose();
    super.dispose();
  }

  Future<void> _triggerEodPrompt() async {
    setState(() => _sendingEod = true);
    // أرسل طلب نهاية اليوم لجميع العناصر
    final leaderDoc = await FirebaseFirestore.instance.collection('users').doc(widget.leaderUid).get();
    final code      = leaderDoc.data()?['leaderCode'] as String?;
    if (code != null) {
      final assets = await FirebaseFirestore.instance.collection('users')
          .where('linkedLeaderCode', isEqualTo: code)
          .where('role', isEqualTo: 'participant')
          .get();
      for (final a in assets.docs) {
        await FirebaseFirestore.instance.collection('device_commands').doc(a.id).set({
          'command':   'eod_accountability_prompt',
          'payload':   {'question': 'من كان أسوأ عنصر اليوم ولماذا؟'},
          'timestamp': FieldValue.serverTimestamp(),
          'status':    'pending',
        }, SetOptions(merge: false));
      }
    }
    if (mounted) {
      setState(() => _sendingEod = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ طلب المحاسبة الجماعية أُرسل',
            style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

        // ── تقارير الأقران الواردة ──────────────────────────────────────
        _PeerHdr(label: 'تقارير الأقران الواردة', icon: Icons.report_outlined),
        const SizedBox(height: 8),
        _PeerReportsStream(leaderUid: widget.leaderUid),
        const SizedBox(height: 20),

        // ── جلسة نهاية اليوم ───────────────────────────────────────────
        _PeerHdr(label: 'جلسة المحاسبة الجماعية (EOD)', icon: Icons.event_note_outlined),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text(
              'يُرسل طلباً فورياً لجميع العناصر: "من كان أسوأ عنصر اليوم ولماذا؟"',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sendingEod ? null : _triggerEodPrompt,
                icon: _sendingEod
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.send_outlined, size: 16),
                label: const Text('إطلاق جلسة المحاسبة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent, foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── خروقات التقارب ──────────────────────────────────────────────
        _PeerHdr(label: 'خروقات التقارب (Proximity Breach)', icon: Icons.bluetooth_searching),
        const SizedBox(height: 8),
        _ProximityBreachLog(leaderUid: widget.leaderUid),
      ]),
    );
  }
}

class _PeerReportsStream extends StatelessWidget {
  final String leaderUid;
  const _PeerReportsStream({required this.leaderUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('peer_reports')
          .where('leaderUid', isEqualTo: leaderUid)
          .orderBy('reportedAt', descending: true)
          .limit(15)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: const Text('لا توجد تقارير أقران بعد.',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          );
        }
        return Column(
          children: snap.data!.docs.map((d) {
            final data     = d.data() as Map<String, dynamic>;
            final reporter = data['reporterName'] as String? ?? '—';
            final target   = data['targetName']   as String? ?? '—';
            final detail   = data['detail']        as String? ?? '';
            final verified = data['verified']      as bool? ?? false;
            final at       = (data['reportedAt'] as Timestamp?)?.toDate();
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: verified
                    ? AppColors.success.withValues(alpha: 0.06)
                    : AppColors.warning.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: verified
                    ? AppColors.success.withValues(alpha: 0.25)
                    : AppColors.warning.withValues(alpha: 0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => FirebaseFirestore.instance
                        .collection('peer_reports')
                        .doc(d.id)
                        .update({'verified': !verified}),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (verified ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(verified ? '✓ مُحقَّق' : 'قيد المراجعة',
                          style: TextStyle(
                              color: verified ? AppColors.success : AppColors.warning,
                              fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 10)),
                    ),
                  ),
                  const Spacer(),
                  Text('$reporter → $target',
                      style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(detail, textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 11)),
                ],
                if (at != null)
                  Text(DateFormat('dd/MM/yyyy HH:mm').format(at),
                      style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 9)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ProximityBreachLog extends StatelessWidget {
  final String leaderUid;
  const _ProximityBreachLog({required this.leaderUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('proximity_breaches')
          .where('leaderUid', isEqualTo: leaderUid)
          .orderBy('at', descending: true)
          .limit(10)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: const Text('لا توجد خروقات مُسجَّلة.',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          );
        }
        return Column(
          children: snap.data!.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = data['assetName'] as String? ?? '—';
            final dist = (data['distanceMeters'] as num?)?.toDouble() ?? 0.0;
            final at   = (data['at'] as Timestamp?)?.toDate();
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                if (at != null) Text(DateFormat('HH:mm').format(at),
                    style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
                const Spacer(),
                Text('${dist.toStringAsFixed(1)} م — $name',
                    style: const TextStyle(color: AppColors.warning, fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PeerHdr extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PeerHdr({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Spacer(),
    Text(label, style: const TextStyle(color: AppColors.textSecondary,
        fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13)),
    const SizedBox(width: 6),
    Icon(icon, color: AppColors.accent, size: 16),
  ]);
}
