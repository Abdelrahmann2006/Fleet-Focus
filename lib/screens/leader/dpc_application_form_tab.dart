import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/colors.dart';

class DpcApplicationFormTab extends StatelessWidget {
  final String uid;

  const DpcApplicationFormTab({super.key, required this.uid});

  static const Map<String, _SectionMeta> _sectionsMeta = {
    'basic_info': _SectionMeta('البيانات الأساسية', Icons.person_outline, Color(0xFFC9A84C)),
    'health_profile': _SectionMeta('الصحة الجسدية', Icons.favorite_outline, Color(0xFFE53E3E)),
    'psych_profile': _SectionMeta('الصحة النفسية', Icons.psychology_outlined, Color(0xFF805AD5)),
    'skills': _SectionMeta('المهارات والقدرات', Icons.star_outline, Color(0xFF3182CE)),
    'socioeconomic': _SectionMeta('الوضع الاجتماعي', Icons.home_outlined, Color(0xFF38A169)),
    'behavioral': _SectionMeta('السلوك والتاريخ', Icons.history_outlined, Color(0xFFDD6B20)),
    'consent': _SectionMeta('الموافقة المستنيرة', Icons.handshake_outlined, Color(0xFF319795)),
    'red_lines': _SectionMeta('الخطوط الحمراء', Icons.block_outlined, Color(0xFFE53E3E)),
    'advanced_psych': _SectionMeta('التقييم النفسي المتقدم', Icons.psychology, Color(0xFF805AD5)),
    'verification': _SectionMeta('التحقق والإرسال', Icons.verified_outlined, Color(0xFFC9A84C)),
  };

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(
        child: Text('اختر عنصراً لعرض استمارته الشاملة',
            style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 14)),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        if (!snap.hasData || !snap.data!.exists) {
          return const Center(child: Text('لا توجد بيانات لهذا العنصر', style: TextStyle(color: AppColors.textMuted)));
        }

        final data = snap.data!.data() as Map<String, dynamic>? ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(data),
            const SizedBox(height: 20),
            ..._sectionsMeta.entries.map((entry) {
              final sectionKey = entry.key;
              final meta = entry.value;
              final sectionData = data[sectionKey] as Map<String, dynamic>?;

              if (sectionData == null || sectionData.isEmpty) {
                return const SizedBox.shrink(); // إخفاء القسم إذا كان فارغاً
              }

              return _buildExpansionTile(meta, sectionData);
            }).toList(),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    final status = data['applicationStatus'] ?? 'مجهول';
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.assignment_ind, color: AppColors.accent, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الاستمارة الشاملة للتابع',
                    style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(submittedAt != null ? 'تاريخ التقديم: ${submittedAt.day}/${submittedAt.month}/${submittedAt.year}' : 'تاريخ التقديم: غير متوفر',
                    style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('مقبولة', style: TextStyle(color: AppColors.success, fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
          )
        ],
      ),
    );
  }

  Widget _buildExpansionTile(_SectionMeta meta, Map<String, dynamic> sectionData) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedBackgroundColor: AppColors.backgroundCard,
          backgroundColor: AppColors.backgroundCard,
          iconColor: meta.color,
          collapsedIconColor: meta.color,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: meta.color.withOpacity(0.5)),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(meta.title, style: TextStyle(color: meta.color, fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(width: 10),
              Icon(meta.icon, color: meta.color, size: 20),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sectionData.entries.map((e) => _buildDataRow(e.key, e.value)).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String key, dynamic value) {
    // تحسين عرض القوائم إذا كانت الإجابة عبارة عن قائمة خيارات
    String displayValue = value.toString();
    if (value is List) {
      displayValue = value.join(' ، ');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(key, textDirection: TextDirection.rtl, textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(displayValue, textDirection: TextDirection.rtl, textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 14, height: 1.4)),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, thickness: 0.5, height: 1),
        ],
      ),
    );
  }
}

class _SectionMeta {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionMeta(this.title, this.icon, this.color);
}
