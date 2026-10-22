import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/l10n/l10n.dart';

/// Average units/day between consecutive readings.
class DailyUsageChart extends StatelessWidget {
  const DailyUsageChart({super.key, required this.points});

  final List<DailyUsagePoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final grid = theme.colorScheme.outline;
    final shown = points.length > 12 ? points.sublist(points.length - 12) : points;
    final maxY = shown.map((p) => p.unitsPerDay).fold<double>(0, math.max);
    final top = maxY <= 0 ? 5.0 : (maxY * 1.25).ceilToDouble();
    final step = shown.length <= 6 ? 1 : (shown.length / 6).ceil();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('UNITS PER DAY'.tr, style: theme.textTheme.labelSmall),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: top,
                minX: 0,
                maxX: (shown.length - 1).toDouble(),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: top / 4,
                  getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: top / 4,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          value.toStringAsFixed(value < 10 ? 1 : 0),
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= shown.length || i % step != 0 || value != i.toDouble()) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            Fmt.dayShort(shown[i].date),
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.navy,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${Fmt.oneDp(s.y)} units/day\n${Fmt.dayShort(shown[s.x.round()].date)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < shown.length; i++)
                        FlSpot(i.toDouble(), shown[i].unitsPerDay),
                    ],
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: AppColors.amber,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.amber.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
