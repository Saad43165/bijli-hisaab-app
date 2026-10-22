import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Rounded card used for every block. Soft shadow in light mode, hairline
/// border in dark mode. Pass [gradient] for hero cards.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color,
    this.borderColor,
    this.gradient,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;

  /// Set false for cards nested in other cards or tinted alert cards.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = BorderRadius.circular(AppTheme.radiusCard);
    final showShadow = elevated && !p.isDark && gradient == null && color == null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? p.surface) : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color: borderColor ??
              (gradient != null
                  ? Colors.transparent
                  : p.isDark
                      ? p.border
                      : p.border.withValues(alpha: color == null ? 0.7 : 0)),
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : gradient != null
                ? [
                    BoxShadow(
                      color: p.isDark
                          ? AppColors.navy.withValues(alpha: 0.4)
                          : AppColors.amberDeep.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
