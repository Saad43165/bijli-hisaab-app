import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/tariff.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import '../../../state/app_state.dart';

/// "What would N units cost?" — slide to any number of units and see the
/// bill with this meter's company, load and rates. Warns when a few more
/// units would push the whole bill into a costlier slab.
class BillCalculatorCard extends StatefulWidget {
  const BillCalculatorCard({super.key});

  @override
  State<BillCalculatorCard> createState() => _BillCalculatorCardState();
}

class _BillCalculatorCardState extends State<BillCalculatorCard> {
  double? _units;

  static const double _max = 800;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final state = context.watch<AppState>();
    final typical = state.typicalMonthlyUnits;
    final units = (_units ?? (typical > 0 ? typical.toDouble() : 200)).clamp(0, _max).toDouble();
    final u = units.round();
    final e = state.estimateFor(u);
    if (e == null) return const SizedBox.shrink();

    // The slab limit just below: what one unit over it costs the whole bill.
    String? jump;
    final cls = state.protection?.consumerClass ?? ConsumerClass.unprotected;
    if (!e.isTou) {
      final limits = state.calculator.limitsFor(cls);
      final below = limits.where((l) => l < u).toList();
      if (below.isNotEmpty) {
        final l = below.last;
        final atLimit = state.estimateFor(l);
        if (atLimit != null && u - l <= 40) {
          final extra = e.total - atLimit.total;
          if (extra > 0) {
            jump = '${Fmt.whole(u - l)} units over $l add ${Fmt.rs(extra)} — '
                'staying at $l would save that much.';
          }
        }
      }
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ArtTile(Art.moneyBag, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BILL CALCULATOR', style: theme.textTheme.labelSmall),
                    Text('What would your units cost?', style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.whole(u), style: theme.textTheme.headlineMedium),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('units', style: theme.textTheme.bodyMedium),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Fmt.rs(e.total), style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.amberDeep)),
                  Text(
                    '${e.isTou ? 'TOU' : 'Slab ${e.slabLabel}'} · ${Fmt.rate(e.effectiveRate)}/unit',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          Slider(
            value: units,
            min: 0,
            max: _max,
            divisions: (_max / 5).round(),
            label: '$u units',
            onChanged: (v) => setState(() => _units = v),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final preset in const [100, 200, 300, 400])
                ActionChip(
                  label: Text('$preset'),
                  onPressed: () => setState(() => _units = preset.toDouble()),
                ),
            ],
          ),
          if (jump != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: p.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(jump, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'For ${state.company.shortCode}, ${Fmt.oneDp(state.activeMeter?.sanctionedLoadKw ?? 0)} kW, '
            'with taxes and this month\'s adjustments.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
