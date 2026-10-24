import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/bill.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/l10n/l10n.dart';

/// Bars for the last 12 bill months, coloured by slab band, with a dashed
/// line at the protected threshold.
class MonthlyUnitsChart extends StatefulWidget {
  const MonthlyUnitsChart({super.key, required this.bills, this.threshold = 200});

  /// Oldest first.
  final List<Bill> bills;
  final int threshold;

  @override
  State<MonthlyUnitsChart> createState() => _MonthlyUnitsChartState();
}

class _MonthlyUnitsChartState extends State<MonthlyUnitsChart> {
  /// Show rupees instead of units (only when bills have amounts).
  bool _rupees = false;

  @override
  Widget build(BuildContext context) {
    final bills = widget.bills;
    final threshold = widget.threshold;
    final hasAmounts = bills.any((b) => b.amount > 0);
    final rupees = _rupees && hasAmounts;
    double valueOf(Bill b) => rupees ? b.amount : b.units.toDouble();
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final maxValue = bills.map(valueOf).fold<double>(0, math.max);
    final step = rupees ? 1000.0 : 50.0;
    final top = math.max(((math.max(maxValue, rupees ? 0 : threshold.toDouble()) * 1.15) / step).ceil() * step, step);

    Color colorFor(int units) {
      if (units <= 100) return p.safe;
      if (units <= threshold) return AppColors.amber;
      if (units <= 300) return p.warn;
      return p.danger;
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(rupees ? 'RUPEES PER BILL'.tr : 'UNITS PER BILL'.tr, style: theme.textTheme.labelSmall),
                ),
                if (hasAmounts)
                  SegmentedButton<bool>(
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, label: Text('Units'.tr)),
                      ButtonSegment(value: true, label: Text('Rs'.tr)),
                    ],
                    selected: {rupees},
                    onSelectionChanged: (s) => setState(() => _rupees = s.first),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: top,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: top / 4,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: theme.colorScheme.outline, strokeWidth: 1),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (!rupees)
                    HorizontalLine(
                      y: threshold.toDouble(),
                      color: p.danger.withValues(alpha: 0.7),
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        labelResolver: (_) => '$threshold',
                        style: TextStyle(color: p.danger, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: top / 4,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          rupees ? (v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k' : v.toInt().toString()) : v.toInt().toString(),
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= bills.length) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            Fmt.monthShort(bills[i].monthDate),
                            style: TextStyle(color: muted, fontSize: 10.5),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.navy,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final b = bills[group.x];
                      final amount = b.amount > 0 ? '\n${Fmt.rs(b.amount)}' : '';
                      return BarTooltipItem(
                        '${Fmt.month(b.monthDate)}\n${b.units} units$amount',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < bills.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: valueOf(bills[i]),
                          color: colorFor(bills[i].units),
                          width: bills.length > 8 ? 14 : 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legend(color: p.safe, label: '≤100'),
              _Legend(color: AppColors.amber, label: '101–$threshold'),
              _Legend(color: p.warn, label: '${threshold + 1}–300'),
              _Legend(color: p.danger, label: '300+'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
