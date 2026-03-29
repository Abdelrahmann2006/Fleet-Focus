import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/stage_light_background.dart';
import '../constants/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _buttonsController;
  late AnimationController _spotlightController; // للتحكم في حركة الكشاف

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoY;
  late Animation<double> _buttonsOpacity;
  late Animation<double> _buttonsY;
  late Animation<double> _spotlightMovement; // حركة الكشاف الأفقية

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _buttonsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _spotlightController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // مدة الحركة كاملة
    )..repeat(reverse: true); // اجعلها تتكرر للأمام والخلف

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoY = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _buttonsOpacity =
        Tween<double>(begin: 0, end: 1).animate(_buttonsController);
    _buttonsY = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _buttonsController, curve: Curves.easeOut),
    );

    // حركة الكشاف الأفقية (رايح جاي)
    _spotlightMovement = Tween<double>(begin: -15.0, end: 15.0).animate(
      CurvedAnimation(parent: _spotlightController, curve: Curves.easeInOutSine),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      _logoController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _buttonsController.forward();
        });
      });
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _buttonsController.dispose();
    _spotlightController.dispose(); // تخلص من المتحكم الجديد
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // توجيه تلقائي إذا كان المستخدم مسجلاً بالفعل
    if (!auth.isLoading && auth.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final role = auth.user?.role;
        if (role == 'leader') context.go('/leader/dashboard');
        if (role == 'participant') context.go('/participant/home');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background.withOpacity(0.95), // خلفية أغمق قليلاً
      body: Stack(
        children: [
          const StageLightBackground(), // خلفية Matrix الخفيفة
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // الشعار + العنوان الجديد (Panopticon) + الكشاف المتحرك
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _logoY.value),
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        const Text(
                          'Panopticon', // الاسم في الأعلى
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent, // لون ذهبي/نحاسي
                            fontFamily: 'Tajawal',
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Stack لعزل الدرع والكشاف
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. الكشاف الضوئي (تحت الدرع)
                            AnimatedBuilder(
                              animation: _spotlightController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(_spotlightMovement.value, 20),
                                  child: child,
                                );
                              },
                              child: Opacity(
                                opacity: 0.6, // شفافية الكشاف
                                child: Container(
                                  width: 250, // عرض المخروط
                                  height: 120, // طول الكشاف
                                  decoration: const BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.accent, // نحاسي مركز
                                        Colors.transparent, // يتلاشى
                                      ],
                                      center: Alignment.topCenter,
                                      radius: 1.0,
                                      focal: Alignment.topCenter,
                                      focalRadius: 0.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 2. شعار الدرع ذي العين (فوق الكشاف)
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: AppGradients.goldGradientVertical,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withOpacity(0.5),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 70,
                                    color: AppColors.background,
                                  ),
                                  Icon(
                                    Icons.visibility_outlined, // العين داخل الدرع
                                    size: 40,
                                    color: AppColors.background,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40), // مسافة كافية قبل الأزرار
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // أزرار اختيار الأدوار
                  AnimatedBuilder(
                    animation: _buttonsController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _buttonsY.value),
                        child:
                            Opacity(opacity: _buttonsOpacity.value, child: child),
                      );
                    },
                    child: Column(
                      children: [
                        // زر السيدة (تصميم ذهبي بالكامل)
                        _buildGoldButton(
                          context,
                          'أنا السيدة',
                          'إدارة العناصر والاستمارات',
                          Icons.workspace_premium, // أيقونة التاج
                          () => context.push('/auth/leader'),
                        ),

                        const SizedBox(height: 16),

                        // زر العنصر (تصميم ذهبي بالكامل)
                        _buildGoldButton(
                          context,
                          'أنا العنصر',
                          'ملء استمارة الانضمام والولاء',
                          Icons.fingerprint, // أيقونة بصمة الإصبع
                          () => context.push('/auth/participant'),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1), // مسافة صغيرة في الأسفل
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة مساعدة لبناء الأزرار الذهبية المصقولة
  Widget _buildGoldButton(BuildContext context, String title, String subtitle,
      IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.goldGradient, // ذهبي مصقول للزر بالكامل
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: -5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Row(
              children: [
                // أيقونة الزر باللون الغامق
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2), // خلفية داكنة للأيقونة
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.background, // لون الأيقونة
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.background, // لون النص الرئيسي
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.background
                              .withOpacity(0.8), // لون النص الوصفي
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_left,
                  color: AppColors.background, // لون السهم
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
