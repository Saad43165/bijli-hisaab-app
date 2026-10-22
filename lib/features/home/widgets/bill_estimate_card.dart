import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/animated_number.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import 'bill_breakdown_sheet.dart';

class BillEstimateCard extends StatelessWidget {
  const BillEstimateCard({super.key, required this.summary, required this.ratesDate});

  final CycleSummary summary;

  /// "2026-10-21" — when the rates were last updated.
  final String ratesDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projected = summary.estimateProjected;
    final now = summary.estimateNow;

    return AppCard(
      onTap: () => BillBreakdownSheet.show(context, summary),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ArtTile(Art.receipt, size: 50),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(projected.total < 0 ? 'ESTIMATED CREDIT' : 'ESTIMATED BILL',
                        style: theme.textTheme.labelSmall),
                    const SizedBox(height: 2),
                    AnimatedNumber(
                      value: projected.total.abs(),
                      format: Fmt.rs,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Mini(
                  label: 'So far',
                  value: now.total < 0 ? '−${Fmt.rs(-now.total)}' : Fmt.rs(now.total),
                ),
              ),
              Expanded(
                child: _Mini(
                  label: projected.exportCredit > 0 ? 'Solar credit' : 'Per unit',
                  value: projected.exportCredit > 0
                      ? '−${Fmt.rs(projected.exportCredit)}'
                      : Fmt.rate(projected.effectiveRate),
                ),
              ),
              Expanded(child: _Mini(label: projected.isTou ? 'Billing' : 'Slab', value: projected.slabLabel)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'NEPRA rates of ${Fmt.isoLabel(ratesDate)} · includes FCA, QTA and GST',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: theme.textTheme.titleSmall),
        ),
      ],
    );
  }
}
