import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/meter.dart';
import '../../../services/tariff_calculator.dart';
import '../../../services/usage_forecaster.dart';
import '../../../state/app_state.dart';
import '../../settings/tariff_screen.dart';
import '../../../core/l10n/l10n.dart';

/// Bottom sheet with the line-by-line bill estimate.
class BillBreakdownSheet extends StatefulWidget {
  const BillBreakdownSheet({super.key, required this.summary});

  final CycleSummary summary;

  static Future<void> show(BuildContext context, CycleSummary summary) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BillBreakdownSheet(summary: summary),
    );
  }

  @override
  State<BillBreakdownSheet> createState() => _BillBreakdownSheetState();
}

class _BillBreakdownSheetState extends State<BillBreakdownSheet> {
  bool _projected = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final s = widget.summary;
    final BillEstimate e = _projected ? s.estimateProjected : s.estimateNow;
    final meter = state.activeMeter;
    final tariff = state.effectiveTariff;
    final load = meter?.sanctionedLoadKw ?? 0;

    Widget line(String label, double value, {String? note, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium),
                    if (note != null) Text(note, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                value < 0 ? '−${Fmt.rs(-value)}' : Fmt.rs(value),
                style: bold
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bill estimate'.tr, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            e.isTou ? 'Time-of-use rates (5 kW and above)'.tr : '{0} rates · {1}'.trf({'0': e.appliedClass.label, '1': s.protectionReason}),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text('Month end · {0}'.trf({'0': Fmt.whole(s.projectedUnits)}))),
              ButtonSegment(value: false, label: Text('So far · {0}'.trf({'0': Fmt.whole(s.unitsUsed)}))),
            ],
            selected: {_projected},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _projected = v.first),
          ),
          const SizedBox(height: 8),
          if (e.isTou) ...[
            line('Peak units'.tr, e.peakUnits! * tariff.tou.peakRate,
                note: '{0} units @ {1}'.trf({'0': Fmt.whole(e.peakUnits!), '1': Fmt.rate(tariff.tou.peakRate)})),
            line('Off-peak units'.tr, e.offPeakUnits * tariff.tou.offPeakRate,
                note: '{0} units @ {1}'.trf({'0': Fmt.whole(e.offPeakUnits), '1': Fmt.rate(tariff.tou.offPeakRate)})),
          ] else
            line('Energy charges'.tr, e.energy,
                note: '{0} units · slab {1} @ {2}'.trf({'0': Fmt.whole(e.units), '1': e.slab.label, '2': Fmt.rate(e.slab.rate)})),
          if (e.fixed > 0)
            line('Fixed charges'.tr, e.fixed,
                note: e.isTou
                    ? '{0} per kW × {1}% of {2} kW sanctioned load'.trf({'0': Fmt.whole(tariff.tou.fixedPerKw), '1': (tariff.tou.fixedLoadShare * 100).round(), '2': Fmt.oneDp(load)})
                    : '{0} per kW × {1} kW sanctioned load'.trf({'0': Fmt.whole(e.slab.fixedPerKw), '1': Fmt.oneDp(load)})),
          if (e.fcSurcharge > 0)
            line('FC surcharge'.tr, e.fcSurcharge, note: '{0} per unit'.trf({'0': Fmt.rate(tariff.categoryOf(e.appliedClass).fcSurchargePerUnit)})),
          if (e.fca != 0) line('Fuel charges adjustment'.tr, e.fca, note: tariff.fcaLabel),
          if (e.qta != 0) line('Quarterly adjustment'.tr, e.qta, note: tariff.qtaLabel),
          if (e.electricityDuty > 0) line('Electricity duty'.tr, e.electricityDuty),
          line('GST', e.gst, note: '${Fmt.oneDp(tariff.gstPercent)}%'),
          if (e.tvFee > 0) line('TV fee'.tr, e.tvFee),
          if (e.exportCredit > 0)
            line('Solar credit'.tr, -e.exportCredit,
                note: '{0} units @ {1}'.trf({'0': Fmt.whole(e.exportUnits), '1': Fmt.rate(meter?.meterType == MeterType.netMetering ? tariff.solar.netMeteringRate : tariff.solar.netBillingRate)})),
          const Divider(height: 24),
          line(e.total < 0 ? 'Credit to you'.tr : 'Total'.tr, e.total.abs(),
              bold: true,
              note: e.units == 0 || e.exportCredit > 0 ? null : 'About {0} per unit, all-in'.trf({'0': Fmt.rate(e.effectiveRate)})),
          const SizedBox(height: 10),
          Text(
            'Estimate using NEPRA rates updated {0}. Arrears, income tax for non-filers and other items on your actual bill may differ.'.trf({'0': Fmt.isoLabel(tariff.updatedAt)}),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute<void>(builder: (_) => const TariffScreen()));
            },
            icon: const Icon(Icons.tune_rounded),
            label: Text('See all rates'.tr),
          ),
        ],
      ),
    );
  }
}
