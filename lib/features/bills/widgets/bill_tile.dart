import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/bill.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../core/l10n/l10n.dart';
import '../../../state/app_state.dart';

class BillTile extends StatelessWidget {
  const BillTile({super.key, required this.bill, this.previousUnits, this.onTap, this.threshold = 200});

  final Bill bill;

  /// Units of the bill before this one, for the change badge.
  final int? previousUnits;
  final VoidCallback? onTap;

  /// Protected limit — bills above it are marked.
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final prev = previousUnits;
    final int? change = prev == null || prev == 0 || prev == bill.units
        ? null
        : ((bill.units - prev) / prev * 100).round();
    final over = bill.units > threshold;
    final badgeColor = over ? p.danger : (bill.units <= 100 ? p.safe : AppColors.amberDeep);

    // "Due in 3 days" / "Overdue" for recent bills.
    String? due;
    Color? dueColor;
    final d = bill.dueDate;
    if (d != null && context.watch<AppState>().isBillPaid(bill)) {
      due = 'Paid ✓'.tr;
      dueColor = p.safe;
    } else if (d != null) {
      final days = DateX.daysBetween(DateX.today(), d);
      if (days >= 0 && days <= 10) {
        due = days == 0 ? 'Due today'.tr : 'Due in {0} {1}'.trf({'0': days, '1': days == 1 ? 'day'.tr : 'days'.tr});
        dueColor = days <= 2 ? p.danger : p.warn;
      } else if (days < 0 && days > -20) {
        due = 'Due date passed'.tr;
        dueColor = p.muted;
      }
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        children: [
          // Calendar-style month badge, coloured by slab.
          Container(
            width: 52,
            height: 56,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Fmt.monthShort(bill.monthDate).toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(color: badgeColor, fontWeight: FontWeight.w800),
                ),
                Text("'${bill.monthDate.year % 100}", style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(Fmt.units(bill.units), style: theme.textTheme.titleMedium),
                    if (change != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        change > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 13,
                        color: change > 0 ? p.danger : p.safe,
                      ),
                      Text(
                        '${change.abs()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: change > 0 ? p.danger : p.safe,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Slab {0}'.trf({'0': AppConstants.slabBand(bill.units)}), style: theme.textTheme.bodySmall),
                    if (bill.source == 'scan') TagBadge('Scanned', color: theme.colorScheme.onSurfaceVariant),
                    if (due != null) TagBadge(due, color: dueColor),
                  ],
                ),
              ],
            ),
          ),
          Text(
            bill.amount > 0 ? Fmt.rs(bill.amount) : '—',
            style: theme.textTheme.titleSmall,
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
