import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/bill.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';

/// Protected rates need every one of the last N bills at or under the limit
/// (200 units, 6 months). One dot per month: green under, red over, grey missing.
class ProtectionCard extends StatelessWidget {
  const ProtectionCard({super.key, required this.bills, required this.months, required this.limit});

  /// Any order.
  final List<Bill> bills;
  final int months;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final byMonth = {for (final b in bills) b.month: b};
    final latest = bills.isEmpty
        ? DateTime.now()
        : (bills.map((b) => b.monthDate).reduce((a, b) => a.isAfter(b) ? a : b));
    // Oldest → newest, ending at the latest bill month.
    final slots = [
      for (var i = months - 1; i >= 0; i--) DateTime(latest.year, latest.month - i),
    ];
    final found = [for (final m in slots) byMonth[Fmt.monthKey(m)]];
    final over = found.whereType<Bill>().where((b) => b.units > limit).toList();
    final missing = found.where((b) => b == null).length;

    final (String title, String body, Color color) = over.isNotEmpty
        ? (
            'Not protected right now',
            '${over.length == 1 ? '${Fmt.month(over.last.monthDate)} was' : '${over.length} bills were'} above $limit '
                'units. Keep every bill at $limit or less for $months months in a row to get protected rates back.',
            p.danger,
          )
        : missing > 0
            ? (
                'On the way to protected rates',
                'No bill above $limit units so far. Add the missing ${missing == 1 ? 'month' : '$missing months'} '
                    'to confirm — protected rates are much cheaper.',
                AppColors.amberDeep,
              )
            : (
                'You qualify for protected rates',
                'All of your last $months bills were $limit units or less. Stay under $limit to keep them.',
                p.safe,
              );

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ArtTile(Art.shield, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PROTECTED RATES · LAST $months BILLS', style: theme.textTheme.labelSmall),
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(color: color)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < slots.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 34,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: found[i] == null
                              ? theme.colorScheme.outline.withValues(alpha: 0.5)
                              : (found[i]!.units > limit ? p.danger : p.safe).withValues(alpha: 0.16),
                          border: Border.all(
                            color: found[i] == null
                                ? Colors.transparent
                                : (found[i]!.units > limit ? p.danger : p.safe),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          found[i] == null ? '?' : '${found[i]!.units}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: found[i] == null
                                ? theme.colorScheme.onSurfaceVariant
                                : (found[i]!.units > limit ? p.danger : p.safe),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(Fmt.monthShort(slots[i]), style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
