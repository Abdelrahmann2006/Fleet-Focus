import 'package:flutter/material.dart';

/// Breakpoints — نقاط التكيّف مع أحجام الشاشات
///
/// موبايل:  < 768px   → ملء الشاشة، قائمة سفلية أو Drawer
/// تابلت:   768-1100  → شريط جانبي مُطوي
/// ديسكتوب: > 1100px  → شريط جانبي كامل + محتوى رئيسي

class Breakpoints {
  static const double mobile  = 768.0;
  static const double tablet  = 1100.0;
  static const double desktop = 1400.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobile && w < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}

/// DeviceType — نوع الجهاز الحالي
enum DeviceType { mobile, tablet, desktop }

extension BreakpointContext on BuildContext {
  DeviceType get deviceType {
    final w = MediaQuery.sizeOf(this).width;
    if (w < Breakpoints.mobile) return DeviceType.mobile;
    if (w < Breakpoints.tablet) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  bool get isMobile  => deviceType == DeviceType.mobile;
  bool get isTablet  => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;
}

/// ResponsiveValue — قيمة مختلفة حسب حجم الشاشة
class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  T resolve(BuildContext context) {
    switch (context.deviceType) {
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }
}
