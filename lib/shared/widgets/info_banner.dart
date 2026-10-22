import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'art.dart';

/// Tinted one-line-or-two notice with optional action and close button.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.color,
    this.actionLabel,
    this.onAction,
    this.onClose,
    this.leadingArt,
  });

  final IconData icon;

  /// Optional 3D illustration shown instead of [icon].
  final String? leadingArt;
  final String? title;
  final String message;
  final Color? color;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? AppColors.amberDeep;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: leadingArt != null
                ? ArtImage(leadingArt!, size: 26)
                : Icon(icon, color: c, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!, style: theme.textTheme.titleSmall?.copyWith(color: c)),
                Text(message, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface)),
                if (actionLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: onAction,
                      child: Text(
                        actionLabel!,
                        style: theme.textTheme.labelLarge?.copyWith(color: c),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
