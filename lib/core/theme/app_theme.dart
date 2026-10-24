import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const double radiusCard = 22;
  static const double radiusInput = 14;
  static const String fontFamily = 'PlusJakartaSans';
  static const String urduFontFamily = 'NotoNastaliqUrdu';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final p = isDark ? AppPalette.dark : AppPalette.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.amber,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.amber : AppColors.navy,
      onPrimary: isDark ? AppColors.navy : Colors.white,
      secondary: AppColors.amber,
      onSecondary: AppColors.navy,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      outline: p.border,
      outlineVariant: p.border,
      error: p.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      fontFamily: fontFamily,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink);

    return base.copyWith(
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14.5, height: 1.45),
        bodySmall: text.bodySmall?.copyWith(color: p.muted, height: 1.4),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        labelSmall: text.labelSmall?.copyWith(
          color: p.muted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: p.background,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        systemOverlayStyle: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isDark ? AppColors.navySoft : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.amber, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: p.danger, width: 2),
        ),
        labelStyle: TextStyle(color: p.muted),
        helperStyle: TextStyle(color: p.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.navy,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInput),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: p.border),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInput),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.amber : AppColors.navy,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.navy,
        elevation: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: AppColors.amber.withValues(alpha: 0.28),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? p.ink : p.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.ink : p.muted,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.surface,
        selectedColor: AppColors.amber.withValues(alpha: 0.3),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(fontFamily: fontFamily, color: p.ink, fontWeight: FontWeight.w600),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.amber.withValues(alpha: 0.3),
          selectedForegroundColor: p.ink,
          foregroundColor: p.muted,
          side: BorderSide(color: p.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        headerForegroundColor: p.ink,
        dividerColor: p.border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
        todayBorder: const BorderSide(color: AppColors.amber, width: 1.5),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : p.ink,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.amber : AppColors.navy,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w800),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.inkDark : AppColors.navy,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.navy : Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.amber,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.navy : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.amber : null,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : null,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.amber,
        thumbColor: AppColors.amber,
        inactiveTrackColor: p.border,
        overlayColor: AppColors.amber.withValues(alpha: 0.15),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.amber : null,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.navy),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // Follows the back swipe on Android 14+ (predictive back).
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white, fontSize: 12),
      ),
    );
  }
}
