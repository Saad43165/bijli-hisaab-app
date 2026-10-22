import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/year_comparison.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';

/// "Nov 2026 vs Nov 2025": units and amount against the same month last year.
class YearCompareCard extends StatelessWidget {
  const YearCompareCard({super.key, required this.items});

  final List<YearComparison> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ArtTile(Art.calendar, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text('Compared with last year', style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            _Line(item: items[i]),
            if (i < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.item});

  final YearComparison item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final change = item.unitChange;
    final more = item.unitDiff > 0;
    final same = item.unitDiff == 0;
    final color = same ? p.muted : (more ? p.danger : p.safe);
    final month = Fmt.parseMonthKey(item.month);
    final lastMonth = item.lastYear.monthDate;

    final amountDiff = item.amountDiff;
    final money = amountDiff == null
        ? null
        : '${amountDiff >= 0 ? '+' : '−'}${Fmt.rs(amountDiff.abs())}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.title} · ${Fmt.month(month)}',
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${item.projected ? '~' : ''}${Fmt.whole(item.units)}',
                        style: theme.textTheme.titleLarge,
                      ),
                      TextSpan(
                        text: '  vs ${Fmt.whole(item.lastYear.units)} in ${Fmt.month(lastMonth)}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (money != null || item.projected)
                  Text(
                    [
                      if (item.projected) 'Projected for month end',
                      if (money != null) '$money on the bill',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  same
                      ? Icons.trending_flat_rounded
                      : (more ? Icons.trending_up_rounded : Icons.trending_down_rounded),
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  change == null ? '—' : '${(change.abs() * 100).round()}%',
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
