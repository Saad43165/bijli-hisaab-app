import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/meter.dart';
import '../../../services/tariff_calculator.dart';
import '../../../services/usage_forecaster.dart';
import '../../../state/app_state.dart';
import '../../settings/tariff_screen.dart';

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
          Text('Bill estimate', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            e.isTou ? 'Time-of-use rates (5 kW and above)' : '${e.appliedClass.label} rates · ${s.protectionReason}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text('Month end · ${Fmt.whole(s.projectedUnits)}')),
              ButtonSegment(value: false, label: Text('So far · ${Fmt.whole(s.unitsUsed)}')),
            ],
            selected: {_projected},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _projected = v.first),
          ),
          const SizedBox(height: 8),
          if (e.isTou) ...[
            line('Peak units', e.peakUnits! * tariff.tou.peakRate,
                note: '${Fmt.whole(e.peakUnits!)} units @ ${Fmt.rate(tariff.tou.peakRate)}'),
            line('Off-peak units', e.offPeakUnits * tariff.tou.offPeakRate,
                note: '${Fmt.whole(e.offPeakUnits)} units @ ${Fmt.rate(tariff.tou.offPeakRate)}'),
          ] else
            line('Energy charges', e.energy,
                note: '${Fmt.whole(e.units)} units · slab ${e.slab.label} @ ${Fmt.rate(e.slab.rate)}'),
          if (e.fixed > 0)
            line('Fixed charges', e.fixed,
                note: e.isTou
                    ? '${Fmt.whole(tariff.tou.fixedPerKw)} per kW × ${(tariff.tou.fixedLoadShare * 100).round()}% '
                        'of ${Fmt.oneDp(load)} kW sanctioned load'
                    : '${Fmt.whole(e.slab.fixedPerKw)} per kW × ${Fmt.oneDp(load)} kW sanctioned load'),
          if (e.fcSurcharge > 0)
            line('FC surcharge', e.fcSurcharge, note: '${Fmt.rate(tariff.categoryOf(e.appliedClass).fcSurchargePerUnit)} per unit'),
          if (e.fca != 0) line('Fuel charges adjustment', e.fca, note: tariff.fcaLabel),
          if (e.qta != 0) line('Quarterly adjustment', e.qta, note: tariff.qtaLabel),
          if (e.electricityDuty > 0) line('Electricity duty', e.electricityDuty),
          line('GST', e.gst, note: '${Fmt.oneDp(tariff.gstPercent)}%'),
          if (e.tvFee > 0) line('TV fee', e.tvFee),
          if (e.exportCredit > 0)
            line('Solar credit', -e.exportCredit,
                note: '${Fmt.whole(e.exportUnits)} units @ '
                    '${Fmt.rate(meter?.meterType == MeterType.netMetering ? tariff.solar.netMeteringRate : tariff.solar.netBillingRate)}'),
          const Divider(height: 24),
          line(e.total < 0 ? 'Credit to you' : 'Total', e.total.abs(),
              bold: true,
              note: e.units == 0 || e.exportCredit > 0 ? null : 'About ${Fmt.rate(e.effectiveRate)} per unit, all-in'),
          const SizedBox(height: 10),
          Text(
            'Estimate using NEPRA rates updated ${Fmt.isoLabel(tariff.updatedAt)}. Arrears, income tax for '
            'non-filers and other items on your actual bill may differ.',
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
            label: const Text('See all rates'),
          ),
        ],
      ),
    );
  }
}
