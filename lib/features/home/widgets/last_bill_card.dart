import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/bill.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import '../../../core/l10n/l10n.dart';

/// The latest bill at a glance, or a prompt to add one.
class LastBillCard extends StatelessWidget {
  const LastBillCard({super.key, required this.bill, required this.onOpen, required this.onScan});

  final Bill? bill;

  /// Opens History.
  final VoidCallback onOpen;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = bill;
    if (b == null) {
      return AppCard(
        onTap: onScan,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const ArtTile(Art.receipt, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add your last bill'.tr, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Scan it to fill in your meter reading and see if you\'re on protected rates.'.tr,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.document_scanner_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      );
    }

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const ArtTile(Art.receipt, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LAST BILL · ${Fmt.month(b.monthDate).toUpperCase()}', style: theme.textTheme.labelSmall),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${Fmt.whole(b.units)} units', style: theme.textTheme.titleMedium),
                      if (b.amount > 0)
                        TextSpan(
                          text: '  ·  ${Fmt.rs(b.amount)}',
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (b.dueDate != null)
                  Text('Due ${Fmt.day(b.dueDate!)}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
