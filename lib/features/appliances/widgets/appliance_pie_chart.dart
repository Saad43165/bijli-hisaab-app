import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/appliance.dart';

/// Donut of estimated monthly units by appliance (top 6 + "Other").
class ApplianceDonut extends StatelessWidget {
  const ApplianceDonut({super.key, required this.appliances, required this.totalUnits});

  /// Sorted by monthly units, highest first.
  final List<Appliance> appliances;
  final double totalUnits;

  static Color colorAt(int i) => AppColors.chart[i % AppColors.chart.length];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = appliances.take(6).toList();
    final rest = appliances.skip(6).fold<double>(0, (s, a) => s + a.monthlyUnits);

    final sections = <PieChartSectionData>[
      for (var i = 0; i < top.length; i++)
        PieChartSectionData(
          value: top[i].monthlyUnits <= 0 ? 0.001 : top[i].monthlyUnits,
          color: colorAt(i),
          radius: 26,
          showTitle: false,
        ),
      if (rest > 0)
        PieChartSectionData(value: rest, color: AppColors.chart.last, radius: 26, showTitle: false),
    ];

    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 44,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Fmt.whole(totalUnits), style: theme.textTheme.titleLarge),
                  Text('units/mo', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < top.length; i++)
                _LegendRow(
                  color: colorAt(i),
                  label: top[i].name,
                  percent: totalUnits == 0 ? 0 : top[i].monthlyUnits / totalUnits,
                ),
              if (rest > 0)
                _LegendRow(
                  color: AppColors.chart.last,
                  label: 'Others',
                  percent: totalUnits == 0 ? 0 : rest / totalUnits,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label, required this.percent});

  final Color color;
  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface), overflow: TextOverflow.ellipsis),
          ),
          Text('${(percent * 100).round()}%', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
