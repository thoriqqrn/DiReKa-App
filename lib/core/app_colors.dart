import 'package:flutter/material.dart';

class AppColors {
  // Primary palette – biru-teal medis
  static const Color primary = Color(0xFF1A73E8);
  static const Color primaryDark = Color(0xFF1557B0);
  static const Color primaryLight = Color(0xFFD2E3FC);
  static const Color accent = Color(0xFF00BCD4);

  // Dark Mode specific colors
  static const Color darkBackground = Color(0xFF000621);
  static const Color darkSurface = Color(0xFF0A1235);
  static const Color darkAccent = Color(0xFF62E7D9);

  // Background
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFFB0B8C4);

  // Status
  static const Color success = Color(0xFF34A853);
  static const Color warning = Color(0xFFFBBC04);
  static const Color error = Color(0xFFEA4335);
  static const Color info = Color(0xFF4285F4);

  // Penyakit
  static const Color kidneyColor = Color(0xFFE53935);
  static const Color diabetesColor = Color(0xFFFF8F00);
  static const Color heartColor = Color(0xFFEC407A);

  // Splash
  static const Color splashBackground = Color(0xFF000621);

  // Divider & border
  static const Color divider = Color(0xFFE8ECF0);
  static const Color border = Color(0xFFDDE3EA);

  // Bottom nav
  static const Color navSelected = primary;
  static const Color navUnselected = Color(0xFF9AA0A6);
}

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color kidneyColor;
  final Color diabetesColor;
  final Color heartColor;
  final Color border;
  final Color divider;
  final Color surface;
  final Color primaryLight;

  const AppThemeExtension({
    required this.kidneyColor,
    required this.diabetesColor,
    required this.heartColor,
    required this.border,
    required this.divider,
    required this.surface,
    required this.primaryLight,
  });

  @override
  AppThemeExtension copyWith({
    Color? kidneyColor,
    Color? diabetesColor,
    Color? heartColor,
    Color? border,
    Color? divider,
    Color? surface,
    Color? primaryLight,
  }) {
    return AppThemeExtension(
      kidneyColor: kidneyColor ?? this.kidneyColor,
      diabetesColor: diabetesColor ?? this.diabetesColor,
      heartColor: heartColor ?? this.heartColor,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      surface: surface ?? this.surface,
      primaryLight: primaryLight ?? this.primaryLight,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      kidneyColor: Color.lerp(kidneyColor, other.kidneyColor, t)!,
      diabetesColor: Color.lerp(diabetesColor, other.diabetesColor, t)!,
      heartColor: Color.lerp(heartColor, other.heartColor, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
    );
  }

  static const AppThemeExtension light = AppThemeExtension(
    kidneyColor: AppColors.kidneyColor,
    diabetesColor: AppColors.diabetesColor,
    heartColor: AppColors.heartColor,
    border: AppColors.border,
    divider: AppColors.divider,
    surface: AppColors.surface,
    primaryLight: AppColors.primaryLight,
  );

  static const AppThemeExtension dark = AppThemeExtension(
    kidneyColor: Color(0xFFFF5252),
    diabetesColor: Color(0xFFFFD180),
    heartColor: Color(0xFFFF80AB),
    border: Color(0xFF1E2A5E),
    divider: Color(0xFF1E2A5E),
    surface: AppColors.darkSurface,
    primaryLight: Color(0xFF1A237E),
  );
}
