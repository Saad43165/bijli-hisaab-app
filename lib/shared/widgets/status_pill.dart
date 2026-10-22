import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/usage_forecaster.dart';
import 'art.dart';
import '../../core/l10n/l10n.dart';

/// Colour + label for a [UsageStatus], used across the app.
class StatusStyle {
  const StatusStyle(this.color, this.label, this.icon, this.art);

  final Color color;
  final String label;
  final IconData icon;

  /// 3D illustration for cards.
  final String art;

  /// Brighter variant for text on the navy hero card.
  StatusStyle onNavy() => StatusStyle(
        Color.lerp(color, Colors.white, 0.25)!,
        label,
        icon,
        art,
      );

  static StatusStyle of(BuildContext context, UsageStatus status) {
    final p = AppPalette.of(context);
    return switch (status) {
      UsageStatus.safe => StatusStyle(p.safe, 'On track'.tr, Icons.check_circle_rounded, Art.check),
      UsageStatus.warn => StatusStyle(p.warn, 'Close to limit'.tr, Icons.error_rounded, Art.warning),
      UsageStatus.danger => StatusStyle(p.danger, 'Will cross limit'.tr, Icons.warning_rounded, Art.warning),
      UsageStatus.overLimits => StatusStyle(p.danger, 'Highest slab'.tr, Icons.local_fire_department_rounded, Art.fire),
      UsageStatus.noData => StatusStyle(p.muted, 'Need readings'.tr, Icons.info_rounded, Art.hourglass),
    };
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.label, this.onDark = false});

  final UsageStatus status;
  final String? label;

  /// Use on the navy hero card.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final base = StatusStyle.of(context, status);
    final s = onDark ? StatusStyle.of(context, status).onNavy() : base;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: onDark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 14, color: s.color),
          const SizedBox(width: 5),
          Text(
            label ?? s.label,
            style: TextStyle(color: s.color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Small rounded badge, e.g. "Scanned", "Protected".
class TagBadge extends StatelessWidget {
  const TagBadge(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.amberDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
