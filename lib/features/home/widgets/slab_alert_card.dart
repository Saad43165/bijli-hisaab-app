import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/widgets/art.dart';
import '../../../core/l10n/l10n.dart';

/// Explains the slab situation and gives the safe daily budget.
class SlabAlertCard extends StatelessWidget {
  const SlabAlertCard({super.key, required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = StatusStyle.of(context, summary.status);
    final target = summary.targetLimit;
    final budget = summary.safeDailyBudget ?? 0;
    final days = summary.daysLeft;

    final String title;
    final String body;
    switch (summary.status) {
      case UsageStatus.safe:
        title = 'On track to stay under {0}'.trf({'0': target});
        body = 'You can use up to {0} units a day for the next {1} days.'.trf({'0': Fmt.oneDp(budget), '1': days});
      case UsageStatus.warn:
        title = 'Close to {0} units'.trf({'0': target});
        body = 'Keep it under {0} units a day for {1} days to stay in this slab.'.trf({'0': Fmt.oneDp(budget), '1': days});
      case UsageStatus.danger:
        title = 'Heading for {0} units'.trf({'0': Fmt.whole(summary.projectedUnits)});
        final extra = summary.extraCostIfCrossed > 0
            ? ' Crossing {0} adds about {1}.'.trf({'0': target, '1': Fmt.rs(summary.extraCostIfCrossed)})
            : '';
        body = 'Use at most {0} units a day for {1} days to stay under {2} (now {3} a day).{4}'.trf({'0': Fmt.oneDp(budget), '1': days, '2': target, '3': Fmt.oneDp(summary.dailyRate), '4': extra});
      case UsageStatus.overLimits:
        title = 'You\'re in the highest slab'.tr;
        body = 'Every extra unit costs {0} before taxes. Check Appliances to see what uses the most.'.trf({'0': Fmt.rate(summary.estimateProjected.slab.rate)});
      case UsageStatus.noData:
        title = 'Add readings to see your slab'.tr;
        body = '';
    }

    return AppCard(
      elevated: false,
      color: style.color.withValues(alpha: 0.08),
      borderColor: style.color.withValues(alpha: 0.30),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArtTile(style.art, tint: style.color, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(color: style.color)),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (summary.status != UsageStatus.overLimits && summary.safeDailyBudget != null) ...[
            const SizedBox(height: 14),
            _BudgetBar(rate: summary.dailyRate, budget: budget, color: style.color),
          ],
          if (summary.alternativeLimit != null) ...[
            const SizedBox(height: 12),
            Text(
              'Realistic goal: stay under {0} units (max {1} a day).'.trf({'0': summary.alternativeLimit, '1': Fmt.oneDp(summary.alternativeBudget ?? 0)}),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          if (summary.lifelineAtRisk || summary.protectionAtRisk) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                summary.protectionAtRisk
                    ? 'Going above {0} units ends your protected rates for the next 6 bills.'.trf({'0': summary.protectedThreshold})
                    : 'Going above 100 units ends lifeline rates for this bill.'.tr,
                style: TextStyle(color: style.color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Your pace vs your budget" as two bars.
class _BudgetBar extends StatelessWidget {
  const _BudgetBar({required this.rate, required this.budget, required this.color});

  final double rate;
  final double budget;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = (rate > budget ? rate : budget) * 1.1;
    Widget bar(String label, double v, Color c) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(width: 78, child: Text(label, style: theme.textTheme.bodySmall)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : (v / max).clamp(0, 1).toDouble(),
                    minHeight: 8,
                    color: c,
                    backgroundColor: c.withValues(alpha: 0.12),
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '{0}/day'.trf({'0': Fmt.oneDp(v)}),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        );
    return Column(
      children: [
        bar('Your pace', rate, color),
        bar('Safe budget', budget, theme.colorScheme.onSurface.withValues(alpha: 0.55)),
      ],
    );
  }
}
