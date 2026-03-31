import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../services/firestore_service.dart'; // المكتبة الجديدة للإشعارات
import '../form/section1_basic_info.dart';
import '../form/section2_health_profile.dart';
import '../form/section3_psych_profile.dart';
import '../form/section4_skills.dart';
import '../form/section5_socioeconomic.dart';
import '../form/section6_behavioral.dart';
import '../form/section7_consent.dart';
import '../form/section8_red_lines.dart';
import '../form/section9_advanced_psych.dart';
import '../form/section10_verification.dart';

class ApplicationScreen extends StatefulWidget {
  const ApplicationScreen({super.key});

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  int _currentSection = 0;
  bool _saving = false;
  final Map<String, Map<String, dynamic>> _formData = {};

  final List<Map<String, dynamic>> _sections = [
    {'title': 'البيانات الأساسية', 'icon': Icons.person_outline, 'color': const Color(0xFFC9A84C)},
    {'title': 'الصحة الجسدية', 'icon': Icons.favorite_outline, 'color': const Color(0xFFE53E3E)},
    {'title': 'الصحة النفسية', 'icon': Icons.psychology_outlined, 'color': const Color(0xFF805AD5)},
    {'title': 'المهارات والقدرات', 'icon': Icons.star_outline, 'color': const Color(0xFF3182CE)},
    {'title': 'الوضع الاجتماعي', 'icon': Icons.home_outlined, 'color': const Color(0xFF38A169)},
    {'title': 'السلوك والتاريخ', 'icon': Icons.history_outlined, 'color': const Color(0xFFDD6B20)},
    {'title': 'الموافقة المستنيرة', 'icon': Icons.handshake_outlined, 'color': const Color(0xFF319795)},
    {'title': 'الخطوط الحمراء', 'icon': Icons.block_outlined, 'color': const Color(0xFFE53E3E)},
    {'title': 'التقييم النفسي المتقدم', 'icon': Icons.psychology, 'color': const Color(0xFF805AD5)},
    {'title': 'التحقق والإرسال', 'icon': Icons.verified_outlined, 'color': const Color(0xFFC9A84C)},
  ];

  void _onSectionData(String key, Map<String, dynamic> data) {
    setState(() => _formData[key] = data);
  }

  Future<void> _handleNext() async {
    if (_currentSection < _sections.length - 1) {
      await _saveProgress();
      setState(() => _currentSection++);
    } else {
      await _submitForm();
    }
  }

  // حفظ التقدم المؤقت (تم توحيده على مجموعة users ليتماشى مع DPC)
  Future<void> _saveProgress() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        ..._formData,
        'lastUpdated': FieldValue.serverTimestamp(),
        'completedSections': _currentSection + 1,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // الإرسال النهائي وتنبيه السيدة
  Future<void> _submitForm() async {
    final user = context.read<AuthProvider>().user;
    final uid = user?.uid;
    if (uid == null) return;
    
    setState(() => _saving = true);
    try {
      // 1. حفظ البيانات النهائية في ملف المستخدم
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        ..._formData,
        'submittedAt': FieldValue.serverTimestamp(),
        'applicationStatus': 'submitted',
        'completedSections': 10,
      }, SetOptions(merge: true));
      
      await context.read<AuthProvider>().updateApplicationStatus('submitted');

      // 2. استخراج كود القائد المرتبط لإرسال الإشعار له
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final leaderCode = userDoc.data()?['linkedLeaderCode'] ?? '';

      if (leaderCode.isNotEmpty) {
        // البحث عن السيدة (المالكة للكود)
        final leaderQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('leaderCode', isEqualTo: leaderCode)
            .where('role', isEqualTo: 'leader')
            .limit(1).get();

        if (leaderQuery.docs.isNotEmpty) {
          final leaderUid = leaderQuery.docs.first.id;
          
          // إرسال الاستمارة كإشعار رسمي للسيدة (الربط مع المرحلة الثانية)
          await FirestoreService().sendNotification(
            leaderUid: leaderUid,
            senderUid: uid,
            senderName: user?.fullName ?? 'عنصر جديد',
            type: 'form',
            title: 'استمارة انضمام جديدة',
            body: 'أرسل ${user?.fullName} استمارة التقييم الشاملة (10 أقسام). بانتظار المراجعة والقرار السيادي.',
            payload: _formData, // البيانات تذهب بالكامل للسيدة لتقرأها
          );
        }
      }

      // 3. عرض رسالة النجاح بتصميمك الأصلي
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.backgroundCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: const Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline, size: 60, color: AppColors.success),
              SizedBox(height: 16),
              Text('تم إرسال استمارتك بنجاح!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal'),
                  textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text('تم رفع الاستمارة إلى غرفة التحكم. سيتم مراجعتها من قِبل القيادة قريباً.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Tajawal'),
                  textAlign: TextAlign.center),
            ]),
            actions: [
              Center(child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/participant/home');
                },
                child: const Text('العودة للرئيسية',
                    style: TextStyle(fontSize: 16, color: AppColors.accent, fontFamily: 'Tajawal')),
              )),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ في الإرسال. تأكد من اتصالك بالإنترنت وحاول مرة أخرى.'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildSection() {
    final onData = _onSectionData;
    switch (_currentSection) {
      case 0: return Section1BasicInfo(initialData: _formData['basic_info'], onChanged: (d) => onData('basic_info', d));
      case 1: return Section2HealthProfile(initialData: _formData['health_profile'], onChanged: (d) => onData('health_profile', d));
      case 2: return Section3PsychProfile(initialData: _formData['psych_profile'], onChanged: (d) => onData('psych_profile', d));
      case 3: return Section4Skills(initialData: _formData['skills'], onChanged: (d) => onData('skills', d));
      case 4: return Section5Socioeconomic(initialData: _formData['socioeconomic'], onChanged: (d) => onData('socioeconomic', d));
      case 5: return Section6Behavioral(initialData: _formData['behavioral'], onChanged: (d) => onData('behavioral', d));
      case 6: return Section7Consent(initialData: _formData['consent'], onChanged: (d) => onData('consent', d));
      case 7: return Section8RedLines(initialData: _formData['red_lines'], onChanged: (d) => onData('red_lines', d));
      case 8: return Section9AdvancedPsych(initialData: _formData['advanced_psych'], onChanged: (d) => onData('advanced_psych', d));
      case 9: return Section10Verification(formData: _formData, onChanged: (d) => onData('verification', d));
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = _sections[_currentSection];
    final color = section['color'] as Color;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header - تصميمك الأصلي المنسق
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16, right: 16, bottom: 14,
            ),
            color: AppColors.background,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, color: AppColors.textSecondary),
                      onPressed: _currentSection > 0
                          ? () => setState(() => _currentSection--)
                          : () => context.pop(),
                    ),
                    Expanded(
                      child: Column(children: [
                        Text(section['title'] as String,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'Tajawal')),
                        const SizedBox(height: 2),
                        Text('القسم ${_currentSection + 1} من ${_sections.length}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'Tajawal')),
                      ]),
                    ),
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Icon(section['icon'] as IconData, color: color, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (_currentSection + 1) / _sections.length,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),

          // Section content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _buildSection(),
            ),
          ),

          // Bottom bar - مع أزرار التدرج اللوني الفخمة
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (_currentSection < _sections.length - 1)
                  TextButton(
                    onPressed: _saving ? null : _saveProgress,
                    child: const Text('حفظ وإكمال لاحقاً',
                        style: TextStyle(fontSize: 14, color: AppColors.textMuted, fontFamily: 'Tajawal')),
                  ),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withOpacity(0.9), color]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: MaterialButton(
                    onPressed: _saving ? null : _handleNext,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            _currentSection < _sections.length - 1 ? 'التالي ←' : 'إرسال الاستمارة',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Tajawal'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

