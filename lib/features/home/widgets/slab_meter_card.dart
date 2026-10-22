import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/tariff_calculator.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/app_card.dart';

/// "Slab ladder": the slabs as coloured segments with the per-unit rate of
/// each, a solid marker for units used and a hollow one for the projection.
class SlabMeterCard extends StatelessWidget {
  const SlabMeterCard({super.key, required this.summary, required this.calculator});

  final CycleSummary summary;
  final TariffCalculator calculator;

  static Color colorFor(BuildContext context, int upper, int threshold) {
    final p = AppPalette.of(context);
    if (upper <= 100) return p.safe;
    if (upper <= threshold) return AppColors.amber;
    if (upper <= 300) return p.warn;
    return p.danger;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final limits = calculator.limitsFor(summary.consumerClass);
    final used = summary.unitsUsed;
    final projected = summary.projectedUnits;

    // Scale: the first limit comfortably above what we'll reach, but always
    // show at least two segments so there is something to compare.
    final need = math.max(used, projected) * 1.05;
    var scaleMax = limits.isEmpty ? need.ceil() + 100 : limits.last + 100;
    for (final l in limits) {
      if (l >= need) {
        scaleMax = l;
        break;
      }
    }
    if (limits.length >= 2 && scaleMax < limits[1]) scaleMax = limits[1];
    final bounds = <int>[0, ...limits.where((l) => l < scaleMax), scaleMax];
    final threshold = summary.protectedThreshold;

    double frac(double v) => (v / scaleMax).clamp(0, 1).toDouble();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('SLAB LADDER', style: theme.textTheme.labelSmall),
              const Spacer(),
              Text(
                '${summary.consumerClass.label} rates',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              return SizedBox(
                height: 74,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Rates above each segment.
                    for (var i = 0; i < bounds.length - 1; i++)
                      Positioned(
                        left: w * bounds[i] / scaleMax,
                        width: w * (bounds[i + 1] - bounds[i]) / scaleMax,
                        top: 0,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Rs ${calculator.marginalRate(bounds[i + 1], consumerClass: summary.consumerClass).toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    // Track segments.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 22,
                      height: 14,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            for (var i = 0; i < bounds.length - 1; i++)
                              Expanded(
                                flex: bounds[i + 1] - bounds[i],
                                child: Container(
                                  margin: EdgeInsets.only(right: i < bounds.length - 2 ? 2 : 0),
                                  color: colorFor(context, bounds[i + 1], threshold)
                                      .withValues(alpha: bounds[i] < used ? 0.95 : 0.28),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Projection marker (hollow).
                    if (projected > used)
                      Positioned(
                        left: w * frac(projected) - 9,
                        top: 20,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.surface,
                            border: Border.all(color: p.ink, width: 2.5),
                          ),
                        ),
                      ),
                    // Used marker (solid).
                    Positioned(
                      left: w * frac(used) - 10,
                      top: 19,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.ink,
                          border: Border.all(color: p.surface, width: 3),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                    // Boundary labels.
                    for (final b in bounds)
                      Positioned(
                        left: (w * b / scaleMax - 20).clamp(-4, w - 36).toDouble(),
                        width: 40,
                        top: 44,
                        child: Text(
                          '$b',
                          textAlign: b == 0
                              ? TextAlign.left
                              : b == scaleMax
                                  ? TextAlign.right
                                  : TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: b == threshold && summary.isProtected ? FontWeight.w800 : null,
                            color: b == threshold && summary.isProtected ? p.danger : null,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Key(solid: true, text: 'Now ${Fmt.whole(used)} units'),
              if (projected > used) _Key(solid: false, text: 'Month end ~${Fmt.whole(projected)}'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary.isProtected
                ? 'Rates shown per unit. Above $threshold units you lose protected rates.'
                : 'Rate per unit for the whole month once you enter that slab.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.solid, required this.text});

  final bool solid;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: solid ? p.ink : Colors.transparent,
            border: Border.all(color: p.ink, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
