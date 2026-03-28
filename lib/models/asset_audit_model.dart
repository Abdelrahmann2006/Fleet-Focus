import 'dart:io';

// ─── أنواع قواعد تعبئة البنود ────────────────────────────────
enum AuditRuleType {
  /// اسأل عن الكمية → أنشئ N مجموعة من حقول الفرعية + صورة إلزامية
  askQty,
  /// عرض حقول محددة فوراً (رقم الهوية، إلخ)
  singleForm,
  /// منطقة نصية واحدة "التفاصيل الدقيقة"
  detailsOnly,
  /// قائمة اختيار (مقيم / متنقل)
  roleSelect,
}

// ─── حقل فردي في نموذج singleForm ───────────────────────────
class AuditField {
  final String key;
  final String labelAr;
  final bool isRequired;
  final bool isPassword; // للحسابات الرقمية — سيُشفَّر
  final TextInputConfig inputConfig;

  const AuditField({
    required this.key,
    required this.labelAr,
    this.isRequired = true,
    this.isPassword = false,
    this.inputConfig = const TextInputConfig(),
  });
}

class TextInputConfig {
  final bool isMultiline;
  final bool isNumeric;
  final int? maxLength;

  const TextInputConfig({
    this.isMultiline = false,
    this.isNumeric = false,
    this.maxLength,
  });
}

// ─── تعريف فئة الجرد ─────────────────────────────────────────
class AuditCategory {
  final String id;
  final String titleAr;
  final String subtitleAr;
  final String emoji;
  final AuditRuleType ruleType;

  /// للـ askQty: الحقول التي تظهر لكل وحدة مع الصورة
  final List<AuditField> subItemFields;

  /// للـ singleForm: حقول محددة تظهر فوراً
  final List<AuditField> singleFields;

  /// للـ roleSelect: خيارات النوع
  final List<String> roleOptions;

  /// هل يحتاج تشفير (الحسابات الرقمية)
  final bool requiresEncryption;

  const AuditCategory({
    required this.id,
    required this.titleAr,
    required this.subtitleAr,
    required this.emoji,
    required this.ruleType,
    this.subItemFields = const [],
    this.singleFields = const [],
    this.roleOptions = const [],
    this.requiresEncryption = false,
  });
}

// ─── 13 فئة جرد كاملة ────────────────────────────────────────

const List<AuditCategory> kAuditCategories = [
  // 1 — الأجهزة الإلكترونية
  AuditCategory(
    id: 'electronics',
    titleAr: 'الأجهزة الإلكترونية والرقمية',
    subtitleAr: 'كمبيوتر، هاتف، تابلت، كاميرا...',
    emoji: '📱',
    ruleType: AuditRuleType.askQty,
    subItemFields: [
      AuditField(key: 'name', labelAr: 'اسم الجهاز / النوع'),
      AuditField(key: 'brand', labelAr: 'الماركة'),
      AuditField(key: 'model', labelAr: 'الموديل'),
      AuditField(key: 'condition', labelAr: 'الحالة (جديد / جيد / مستهلك)'),
      AuditField(key: 'value', labelAr: 'القيمة التقريبية (ريال)', inputConfig: TextInputConfig(isNumeric: true)),
    ],
  ),

  // 2 — الأصول المالية
  AuditCategory(
    id: 'financials',
    titleAr: 'الأصول المالية والبنكية',
    subtitleAr: 'حسابات بنكية، نقود، استثمارات...',
    emoji: '💳',
    ruleType: AuditRuleType.askQty,
    subItemFields: [
      AuditField(key: 'type', labelAr: 'النوع (حساب بنكي / نقود / استثمار / دين)'),
      AuditField(key: 'bank_name', labelAr: 'اسم البنك / الجهة', isRequired: false),
      AuditField(key: 'account_last4', labelAr: 'آخر 4 أرقام من رقم الحساب', isRequired: false, inputConfig: TextInputConfig(maxLength: 4, isNumeric: true)),
      AuditField(key: 'balance_estimate', labelAr: 'الرصيد التقريبي', inputConfig: TextInputConfig(isNumeric: true)),
    ],
  ),

  // 3 — المستندات الثبوتية
  AuditCategory(
    id: 'documents',
    titleAr: 'المستندات والأوراق الثبوتية',
    subtitleAr: 'هوية، جواز، رخصة، وثائق...',
    emoji: '📄',
    ruleType: AuditRuleType.askQty,
    subItemFields: [
      AuditField(key: 'doc_type', labelAr: 'نوع المستند (هوية / جواز / رخصة / أخرى)'),
      AuditField(key: 'doc_number', labelAr: 'رقم المستند'),
      AuditField(key: 'expiry', labelAr: 'تاريخ الانتهاء', isRequired: false),
    ],
  ),

  // 4 — المفاتيح والكروت
  AuditCategory(
    id: 'keys',
    titleAr: 'المفاتيح وكروت العضوية',
    subtitleAr: 'مفاتيح منزل، سيارة، كروت بنكية...',
    emoji: '🔑',
    ruleType: AuditRuleType.askQty,
    subItemFields: [
      AuditField(key: 'key_desc', labelAr: 'وصف المفتاح / الكرت'),
      AuditField(key: 'location', labelAr: 'مكان الاحتفاظ به', isRequired: false),
    ],
  ),

  // 5 — الملابس والأغراض الشخصية
  AuditCategory(
    id: 'clothes',
    titleAr: 'الملابس والأغراض الشخصية',
    subtitleAr: 'حقائب، ملابس، إكسسوارات...',
    emoji: '👔',
    ruleType: AuditRuleType.askQty,
    subItemFields: [
      AuditField(key: 'category', labelAr: 'الفئة (ملابس رسمية / كاجوال / حقيبة / أخرى)'),
      AuditField(key: 'qty_est', labelAr: 'العدد التقريبي', inputConfig: TextInputConfig(isNumeric: true)),
      AuditField(key: 'notes', labelAr: 'ملاحظات', isRequired: false, inputConfig: TextInputConfig(isMultiline: true)),
    ],
  ),

  // 6 — منتجات العناية والصحة
  AuditCategory(
    id: 'care',
    titleAr: 'منتجات العناية والصحة',
    subtitleAr: 'أدوية، مستحضرات تجميل، أدوات...',
    emoji: '🧴',
    ruleType: AuditRuleType.askQty,
    subItemFields: [
      AuditField(key: 'product_name', labelAr: 'اسم المنتج'),
      AuditField(key: 'product_type', labelAr: 'النوع (دواء / عناية / أخرى)'),
    ],
  ),

  // 7 — وسائل النقل
  AuditCategory(
    id: 'transport',
    titleAr: 'وسائل النقل',
    subtitleAr: 'سيارة، دراجة، مركبة...',
    emoji: '🚗',
    ruleType: AuditRuleType.askQty,
    subItemFields: [
      AuditField(key: 'vehicle_type', labelAr: 'النوع (سيارة / دراجة نارية / دراجة / أخرى)'),
      AuditField(key: 'make', labelAr: 'الماركة'),
      AuditField(key: 'model', labelAr: 'الموديل'),
      AuditField(key: 'year', labelAr: 'سنة الصنع', inputConfig: TextInputConfig(isNumeric: true, maxLength: 4)),
      AuditField(key: 'ownership', labelAr: 'ملكية (مملوك / مستأجر)'),
    ],
  ),

  // 8 — الممتلكات الثمينة
  AuditCategory(
    id: 'valuables',
    titleAr: 'الممتلكات الثمينة',
    subtitleAr: 'مجوهرات، ساعات، تحف...',
    emoji: '💎',
    ruleType: AuditRuleType.askQty,
    subItemFields: [
      AuditField(key: 'item_desc', labelAr: 'وصف القطعة'),
      AuditField(key: 'est_value', labelAr: 'القيمة التقريبية (ريال)', inputConfig: TextInputConfig(isNumeric: true)),
      AuditField(key: 'storage', labelAr: 'مكان الاحتفاظ', isRequired: false),
    ],
  ),

  // 9 — الأغراض الدينية / الشخصية
  AuditCategory(
    id: 'personal_religious',
    titleAr: 'الأغراض الدينية والأدوات الشخصية',
    subtitleAr: 'مصحف، سبحة، أدوات خاصة...',
    emoji: '📿',
    ruleType: AuditRuleType.askQty,
    subItemFields: [
      AuditField(key: 'item_desc', labelAr: 'وصف الغرض'),
      AuditField(key: 'significance', labelAr: 'الأهمية أو الاستخدام', isRequired: false),
    ],
  ),

  // 10 — الحسابات الرقمية (مشفَّرة)
  AuditCategory(
    id: 'digital_accounts',
    titleAr: 'الحسابات الرقمية',
    subtitleAr: 'بريد إلكتروني، شبكات اجتماعية، مالية...',
    emoji: '🔐',
    ruleType: AuditRuleType.askQty,
    requiresEncryption: true,
    subItemFields: [
      AuditField(key: 'platform', labelAr: 'المنصة / الخدمة'),
      AuditField(key: 'username', labelAr: 'اسم المستخدم / البريد'),
      AuditField(key: 'password', labelAr: 'كلمة المرور', isPassword: true),
      AuditField(key: 'phone_linked', labelAr: 'رقم الهاتف المرتبط', isRequired: false),
    ],
  ),

  // 11 — تصنيف المشاركة
  AuditCategory(
    id: 'participation_type',
    titleAr: 'طلب تصنيف المشاركة',
    subtitleAr: 'هل ستشارك كمقيم أم متنقل؟',
    emoji: '🏷️',
    ruleType: AuditRuleType.roleSelect,
    roleOptions: ['مقيم', 'متنقل'],
  ),

  // 12 — المسؤوليات الخارجية
  AuditCategory(
    id: 'responsibilities',
    titleAr: 'المسؤوليات الخارجية والرعاية',
    subtitleAr: 'أفراد يعتمدون عليك، وظائف، التزامات...',
    emoji: '👨‍👩‍👧',
    ruleType: AuditRuleType.detailsOnly,
  ),

  // 13 — ممتلكات أخرى
  AuditCategory(
    id: 'misc',
    titleAr: 'ممتلكات أخرى إضافية',
    subtitleAr: 'أي ممتلكات لم تُذكر أعلاه',
    emoji: '📦',
    ruleType: AuditRuleType.askQty,
    subItemFields: [
      AuditField(key: 'item_desc', labelAr: 'وصف البند'),
      AuditField(key: 'est_value', labelAr: 'القيمة التقريبية', isRequired: false, inputConfig: TextInputConfig(isNumeric: true)),
    ],
  ),
];

// ─── نموذج بيانات جواب كل فئة ────────────────────────────────

class AuditCategoryState {
  final AuditCategory category;
  bool owned;
  int qty;
  List<Map<String, String>> subForms; // N sub-forms with field key→value
  List<List<File?>> subImages;        // N lists of images
  String detailsText;
  String selectedRole;
  List<String> ghostInputs;

  AuditCategoryState({
    required this.category,
    this.owned = false,
    this.qty = 1,
    List<Map<String, String>>? subForms,
    List<List<File?>>? subImages,
    this.detailsText = '',
    this.selectedRole = '',
    List<String>? ghostInputs,
  })  : subForms = subForms ?? [],
        subImages = subImages ?? [],
        ghostInputs = ghostInputs ?? [];

  /// هل اكتملت الصور الإلزامية (كل بند له صورة واحدة على الأقل)
  bool get imagesComplete {
    if (!owned) return true;
    if (category.ruleType != AuditRuleType.askQty) return true;
    for (final imgList in subImages) {
      if (imgList.isEmpty || imgList.every((f) => f == null)) return false;
    }
    return true;
  }

  /// هل يمكن المتابعة
  bool get isComplete {
    if (!owned) return true;
    switch (category.ruleType) {
      case AuditRuleType.roleSelect:
        return selectedRole.isNotEmpty;
      case AuditRuleType.detailsOnly:
        return detailsText.length >= 5;
      case AuditRuleType.askQty:
      case AuditRuleType.singleForm:
        return subForms.isNotEmpty && imagesComplete;
    }
  }

  Map<String, dynamic> toSubmitMap() => {
        'owned': owned,
        'qty': owned ? qty : 0,
        if (owned && category.ruleType == AuditRuleType.askQty)
          'items': subForms,
        if (owned && category.ruleType == AuditRuleType.singleForm)
          'fields': subForms.isNotEmpty ? subForms[0] : {},
        if (owned && category.ruleType == AuditRuleType.detailsOnly)
          'details': detailsText,
        if (category.ruleType == AuditRuleType.roleSelect)
          'selectedRole': selectedRole,
        if (ghostInputs.isNotEmpty) 'ghostInputs': ghostInputs,
      };
}
