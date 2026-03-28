import 'package:cloud_firestore/cloud_firestore.dart';

/// ApprovalMeta — بيانات الموافقة التي تضعها السيدة عند قبول العنصر
///
/// تُرسَل لجهاز العنصر عبر Firestore وتُعرض في شاشة الانتقال (Step 2).
class ApprovalMeta {
  final String ladyName;
  final String assetCode;

  /// توقيت الجرد — نص يُعرض في الرسالة
  /// مثال: "خلال ساعتين من الإخطار" أو "2026-01-01 14:00"
  final String auditSchedule;

  /// توقيت المقابلة — ISO 8601
  final String interviewTimeIso;

  /// مكان المقابلة
  final String interviewLocation;

  /// الزي الرسمي المطلوب
  final String dressCode;

  /// ملاحظات إضافية (اختياري)
  final String? additionalNotes;

  const ApprovalMeta({
    required this.ladyName,
    required this.assetCode,
    required this.auditSchedule,
    required this.interviewTimeIso,
    required this.interviewLocation,
    required this.dressCode,
    this.additionalNotes,
  });

  Map<String, dynamic> toMap() => {
        'ladyName': ladyName,
        'assetCode': assetCode,
        'auditSchedule': auditSchedule,
        'interviewTimeIso': interviewTimeIso,
        'interviewLocation': interviewLocation,
        'dressCode': dressCode,
        if (additionalNotes != null) 'additionalNotes': additionalNotes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory ApprovalMeta.fromMap(Map<String, dynamic> map) => ApprovalMeta(
        ladyName: map['ladyName'] ?? 'السيدة',
        assetCode: map['assetCode'] ?? '—',
        auditSchedule: map['auditSchedule'] ?? 'غير محدد',
        interviewTimeIso: map['interviewTimeIso'] ?? '',
        interviewLocation: map['interviewLocation'] ?? 'غير محدد',
        dressCode: map['dressCode'] ?? 'غير محدد',
        additionalNotes: map['additionalNotes'],
      );

  /// يُنسَّق وقت المقابلة بصيغة عربية مقروءة
  String get formattedInterviewTime {
    if (interviewTimeIso.isEmpty) return 'غير محدد';
    try {
      final dt = DateTime.parse(interviewTimeIso).toLocal();
      final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
      final months = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${days[dt.weekday % 7]} ${dt.day} ${months[dt.month - 1]} ${dt.year} — $h:$m';
    } catch (_) {
      return interviewTimeIso;
    }
  }

  /// يُحوَّل إلى DateTime — null إذا كان فارغاً أو غير صالح
  DateTime? get interviewDateTime {
    if (interviewTimeIso.isEmpty) return null;
    try {
      return DateTime.parse(interviewTimeIso).toLocal();
    } catch (_) {
      return null;
    }
  }
}
