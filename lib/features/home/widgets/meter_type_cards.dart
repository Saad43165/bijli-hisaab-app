import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/tariff.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import '../../../core/l10n/l10n.dart';

/// TOU meters: peak vs off-peak split and what moving use out of peak saves.
/// Shown instead of the slab cards (TOU bills have no slabs).
class TouSplitCard extends StatelessWidget {
  const TouSplitCard({super.key, required this.summary, required this.rates});

  final CycleSummary summary;
  final TouRates rates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final e = summary.estimateProjected;
    final known = summary.peakShare != null;
    final share = summary.peakShare ?? UsageForecaster.defaultPeakShare;
    final saving = rates.peakRate - rates.offPeakRate;
    final peakUnits = e.peakUnits ?? 0;
    // Moving a fifth of peak use to off-peak hours (e.g. running the motor,
    // iron and washing machine earlier) — before taxes.
    final shift = (peakUnits * 0.2).round();

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ArtTile(Art.hourglass, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PEAK / OFF-PEAK'.tr, style: theme.textTheme.labelSmall),
                    Text(
                      known ? '${(share * 100).round()}% of your use is in peak hours' : 'Peak share not known yet'.tr,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(flex: (share * 1000).round().clamp(1, 999), child: Container(color: p.danger)),
                  Expanded(flex: ((1 - share) * 1000).round().clamp(1, 999), child: Container(color: p.safe)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Part(
                  color: p.danger,
                  label: 'Peak · ${Fmt.rate(rates.peakRate)}',
                  value: '~${Fmt.whole(peakUnits)} units',
                ),
              ),
              Expanded(
                child: _Part(
                  color: p.safe,
                  label: 'Off-peak · ${Fmt.rate(rates.offPeakRate)}',
                  value: '~${Fmt.whole(e.offPeakUnits)} units',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            known
                ? (shift > 0
                    ? 'Move $shift units out of peak hours this month (motor, iron, washing machine) '
                        'and save about ${Fmt.rs(shift * saving)} before taxes.'
                    : 'Almost all your use is off-peak — well done.'.tr)
                : 'Add the peak and off-peak readings to see your real split. Until then we assume '
                    '${(UsageForecaster.defaultPeakShare * 100).round()}%.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Peak hours are 4 evening hours set by your company for the season (e.g. 6–10 pm). '
            'Each peak unit costs ${Fmt.rate(saving)} more.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Solar meters: what came from the grid, what went to it, and the credit.
class SolarCard extends StatelessWidget {
  const SolarCard({super.key, required this.summary, required this.rates});

  final CycleSummary summary;
  final SolarRates rates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final e = summary.estimateProjected;
    final netMetering = summary.meterType == MeterType.netMetering;
    final rate = netMetering ? rates.netMeteringRate : rates.netBillingRate;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ArtTile(Art.sun, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(netMetering ? 'SOLAR · NET METERING'.tr : 'SOLAR · NET BILLING'.tr,
                        style: theme.textTheme.labelSmall),
                    Text(
                      '${Fmt.whole(summary.exportSoFar)} units sent to the grid so far',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Part(
                  color: AppColors.amberDeep,
                  label: 'Sent by month end'.tr,
                  value: '~${Fmt.whole(summary.exportProjected)} units',
                ),
              ),
              Expanded(
                child: _Part(
                  color: p.safe,
                  label: 'Credit on the bill'.tr,
                  value: e.exportCredit > 0 ? '−${Fmt.rs(e.exportCredit)}' : 'Rs 0',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            netMetering
                ? 'Exported units cancel out imported units; you pay for the difference. A surplus is '
                    'paid at ${Fmt.rate(rate)} per unit. Slab warnings use your net units.'
                : 'Imported units are billed at normal slab rates; every exported unit is bought back at '
                    '${Fmt.rate(rate)}. Using solar power yourself saves more than exporting it.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4, right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              Text(value, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ],
    );
  }
}
