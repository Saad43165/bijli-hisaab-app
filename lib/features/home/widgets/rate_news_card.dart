import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/tariff.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';

/// This month's NEPRA adjustments (FCA, QTA) and what they add to your bill,
/// plus any news published in the online rates file.
class RateNewsCard extends StatelessWidget {
  const RateNewsCard({super.key, required this.tariff, this.summary});

  final Tariff tariff;
  final CycleSummary? summary;

  static bool hasContent(Tariff t) =>
      t.fcaPerUnit != 0 || t.qtaPerUnit != 0 || t.newsFor(L10n.language) != null;

  static String _perUnit(double v) => '${v >= 0 ? '+' : '−'}Rs ${Fmt.twoDp(v.abs())}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final news = tariff.newsFor(L10n.language);
    final perUnit = tariff.fcaPerUnit + tariff.qtaPerUnit;
    final units = summary?.hasData == true ? summary!.projectedUnits : null;

    Widget line(String label, String detail, double v) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleSmall),
                    Text(detail, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('{0}/unit'.trf({'0': _perUnit(v)}),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: v > 0 ? theme.colorScheme.error : const Color(0xFF2E9E6B),
                  )),
            ],
          ),
        );

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ArtTile(Art.globe, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RATE NEWS'.tr, style: theme.textTheme.labelSmall),
                    Text('This month\'s NEPRA adjustments'.tr, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          if (news != null) ...[
            const SizedBox(height: 10),
            Text(news, style: theme.textTheme.bodyMedium),
          ],
          if (tariff.fcaPerUnit != 0) line('Fuel charges adjustment'.tr, tariff.fcaLabel, tariff.fcaPerUnit),
          if (tariff.qtaPerUnit != 0) line('Quarterly adjustment'.tr, tariff.qtaLabel, tariff.qtaPerUnit),
          if (units != null && perUnit != 0) ...[
            const SizedBox(height: 10),
            Text(
              (perUnit > 0
                      ? 'Adds about {0} to your bill this month ({1} units).'
                      : 'Saves about {0} on your bill this month ({1} units).')
                  .trf({'0': Fmt.rs((perUnit * units).abs()), '1': Fmt.whole(units)}),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 6),
          Text('Rates updated {0}'.trf({'0': Fmt.isoLabel(tariff.updatedAt)}),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
