import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/widgets/art.dart';

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
        title = 'On track to stay under $target';
        body = 'You can use up to ${Fmt.oneDp(budget)} units a day for the next $days days.';
      case UsageStatus.warn:
        title = 'Close to $target units';
        body = 'Keep it under ${Fmt.oneDp(budget)} units a day for $days days to stay in this slab.';
      case UsageStatus.danger:
        title = 'Heading for ${Fmt.whole(summary.projectedUnits)} units';
        final extra = summary.extraCostIfCrossed > 0
            ? ' Crossing $target adds about ${Fmt.rs(summary.extraCostIfCrossed)}.'
            : '';
        body = 'Use at most ${Fmt.oneDp(budget)} units a day for $days days to stay under $target '
            '(now ${Fmt.oneDp(summary.dailyRate)} a day).$extra';
      case UsageStatus.overLimits:
        title = 'You\'re in the highest slab';
        body = 'Every extra unit costs ${Fmt.rate(summary.estimateProjected.slab.rate)} before taxes. '
            'Check Appliances to see what uses the most.';
      case UsageStatus.noData:
        title = 'Add readings to see your slab';
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
              'Realistic goal: stay under ${summary.alternativeLimit} units '
              '(max ${Fmt.oneDp(summary.alternativeBudget ?? 0)} a day).',
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
                    ? 'Going above ${summary.protectedThreshold} units ends your protected rates for the next 6 bills.'
                    : 'Going above 100 units ends lifeline rates for this bill.',
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
                  '${Fmt.oneDp(v)}/day',
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
