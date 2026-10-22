import 'package:flutter/material.dart';

/// Brand and semantic colours. See docs/DESIGN.md -> Design tokens.
class AppColors {
  AppColors._();

  static const Color navy = Color(0xFF0E1A2B);
  static const Color navySoft = Color(0xFF1B2A41);
  static const Color amber = Color(0xFFF5B700);
  static const Color amberDeep = Color(0xFFD99A00);

  // Light
  static const Color backgroundLight = Color(0xFFF6F4EE);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color inkLight = Color(0xFF101828);
  static const Color mutedLight = Color(0xFF667085);
  static const Color borderLight = Color(0xFFE7E3D8);
  static const Color safeLight = Color(0xFF1F9D6B);
  static const Color warnLight = Color(0xFFE58A00);
  static const Color dangerLight = Color(0xFFD64545);

  // Dark
  static const Color backgroundDark = Color(0xFF0B1220);
  static const Color surfaceDark = Color(0xFF131C2E);
  static const Color inkDark = Color(0xFFEEF1F6);
  static const Color mutedDark = Color(0xFF98A2B3);
  static const Color borderDark = Color(0xFF243049);
  static const Color safeDark = Color(0xFF34C38F);
  static const Color warnDark = Color(0xFFF5A524);
  static const Color dangerDark = Color(0xFFF06565);

  /// Categorical colours for charts (appliance pie, etc.).
  static const List<Color> chart = [
    Color(0xFFF5B700),
    Color(0xFF3E7BFA),
    Color(0xFF1F9D6B),
    Color(0xFFE5484D),
    Color(0xFF8E4EC6),
    Color(0xFF12A594),
    Color(0xFFF76B15),
    Color(0xFF7C8AA5),
  ];
}

/// Theme-aware palette so widgets don't branch on brightness themselves.
class AppPalette {
  const AppPalette._({
    required this.ink,
    required this.muted,
    required this.border,
    required this.surface,
    required this.background,
    required this.safe,
    required this.warn,
    required this.danger,
    required this.isDark,
  });

  final Color ink;
  final Color muted;
  final Color border;
  final Color surface;
  final Color background;
  final Color safe;
  final Color warn;
  final Color danger;
  final bool isDark;

  static const AppPalette light = AppPalette._(
    ink: AppColors.inkLight,
    muted: AppColors.mutedLight,
    border: AppColors.borderLight,
    surface: AppColors.surfaceLight,
    background: AppColors.backgroundLight,
    safe: AppColors.safeLight,
    warn: AppColors.warnLight,
    danger: AppColors.dangerLight,
    isDark: false,
  );

  static const AppPalette dark = AppPalette._(
    ink: AppColors.inkDark,
    muted: AppColors.mutedDark,
    border: AppColors.borderDark,
    surface: AppColors.surfaceDark,
    background: AppColors.backgroundDark,
    safe: AppColors.safeDark,
    warn: AppColors.warnDark,
    danger: AppColors.dangerDark,
    isDark: true,
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
