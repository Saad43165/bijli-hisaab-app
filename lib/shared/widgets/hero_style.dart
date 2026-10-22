import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Colours for the big "hero" cards (usage ring, this month, summaries).
/// Navy in dark mode; a warm amber card with dark text in light mode, so
/// they follow the app's theme instead of always being dark.
class HeroStyle {
  const HeroStyle._({
    required this.dark,
    required this.gradient,
    required this.fg,
    required this.muted,
    required this.faint,
    required this.track,
    required this.accent,
  });

  final bool dark;
  final Gradient gradient;

  /// Main text.
  final Color fg;

  /// Secondary text.
  final Color muted;

  /// Fill for chips and inner panels on the card.
  final Color faint;

  /// Empty part of rings and bars.
  final Color track;

  /// Highlight colour that reads well on this card.
  final Color accent;

  static const HeroStyle _dark = HeroStyle._(
    dark: true,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF15253D), AppColors.navy],
    ),
    fg: Colors.white,
    muted: Color(0xADFFFFFF),
    faint: Color(0x14FFFFFF),
    track: Color(0x1AFFFFFF),
    accent: AppColors.amber,
  );

  static const HeroStyle _light = HeroStyle._(
    dark: false,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF7DE), Color(0xFFFFE7A6)],
    ),
    fg: AppColors.inkLight,
    muted: Color(0xFF5B6475),
    faint: Color(0x0F0E1A2B),
    track: Color(0x170E1A2B),
    accent: AppColors.navy,
  );

  static HeroStyle of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}
