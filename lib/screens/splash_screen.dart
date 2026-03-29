import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/stage_light_background.dart';
import '../widgets/gold_button.dart';
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
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoY;
  late Animation<double> _buttonsOpacity;
  late Animation<double> _buttonsY;

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

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoY = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _buttonsOpacity = Tween<double>(begin: 0, end: 1).animate(_buttonsController);
    _buttonsY = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _buttonsController, curve: Curves.easeOut),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Auto-route if already logged in
    if (!auth.isLoading && auth.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final role = auth.user?.role;
        if (role == 'leader') context.go('/leader/dashboard');
        if (role == 'participant') context.go('/participant/home');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const StageLightBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo + title
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
                          child: const Icon(
                            Icons.star_outline_rounded,
                            size: 50,
                            color: AppColors.background,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'نظام الالتزام',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                            fontFamily: 'Tajawal',
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'منصة متكاملة لإدارة العناصر',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            fontFamily: 'Tajawal',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Role selection buttons
                  AnimatedBuilder(
                    animation: _buttonsController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _buttonsY.value),
                        child: Opacity(opacity: _buttonsOpacity.value, child: child),
                      );
                    },
                    child: Column(
                      children: [
                        // Leader button
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.accent.withOpacity(0.3),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => context.push('/auth/leader'),
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.goldGradient,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.shield_outlined,
                                        color: AppColors.background,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('أنا السيدة',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.text,
                                                fontFamily: 'Tajawal',
                                              )),
                                          Text('إدارة العناصر والاستمارات',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textMuted,
                                                fontFamily: 'Tajawal',
                                              )),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_left,
                                        color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Participant button
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.backgroundCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => context.push('/auth/participant'),
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.accent.withOpacity(0.25),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.person_outline,
                                        color: AppColors.accent,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('أنا العنصر',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.text,
                                                fontFamily: 'Tajawal',
                                              )),
                                          Text('ملء استمارة الانضمام والولاء',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textMuted,
                                                fontFamily: 'Tajawal',
                                              )),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_left,
                                        color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'اتصال آمن ومشفر عبر OAuth 2.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
