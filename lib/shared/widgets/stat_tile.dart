import 'package:flutter/material.dart';

/// Small label + big value, used in summary rows.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.caption, this.valueColor});

  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(color: valueColor),
            maxLines: 1,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption!, style: theme.textTheme.bodySmall, maxLines: 2),
        ],
      ],
    );
  }
}
