import 'package:flutter/material.dart';

class AppColors {
  // Background
  static const Color background = Color(0xFF0D0D1A);
  static const Color backgroundCard = Color(0xFF161628);
  static const Color backgroundElevated = Color(0xFF1E1E35);

  // Gold accent
  static const Color accent = Color(0xFFC9A84C);
  static const Color gold = accent;
  static const Color accentLight = Color(0xFFE8C97A);
  static const Color accentDark = Color(0xFF8B6914);

  // Text
  static const Color text = Color(0xFFF0EDE8);
  static const Color textPrimary = Color(0xFFF0EDE8);
  static const Color textSecondary = Color(0xFFB0A898);
  static const Color textMuted = Color(0xFF6B6580);

  // Borders
  static const Color border = Color(0xFF2A2740);
  static const Color borderLight = Color(0xFF332F50);

  // Status
  static const Color success = Color(0xFF38A169);
  static const Color warning = Color(0xFFDD6B20);
  static const Color error = Color(0xFFE53E3E);
  static const Color info = Color(0xFF3182CE);

  // Stage lights
  static const Color stageLight1 = Color(0xFFC9A84C);
  static const Color stageLight2 = Color(0xFF8B6914);
}

class AppGradients {
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFE8C97A), Color(0xFFC9A84C), Color(0xFFA8873A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient goldGradientVertical = LinearGradient(
    colors: [Color(0xFFE8C97A), Color(0xFFC9A84C), Color(0xFF8B6914)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
