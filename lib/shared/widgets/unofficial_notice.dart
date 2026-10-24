import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/l10n.dart';

/// "Independent app — not an official government app." Small and calm, but
/// always visible where it matters (setup, bill pages, About).
class UnofficialNotice extends StatelessWidget {
  const UnofficialNotice({super.key, this.compact = false});

  /// One short line instead of the full sentence.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            compact
                ? 'Independent app — not an official government or electricity company app.'.tr
                : AppConstants.unofficialNotice.tr,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
