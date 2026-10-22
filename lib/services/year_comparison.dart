import '../core/utils/formatters.dart';
import '../data/models/bill.dart';
import 'usage_forecaster.dart';

/// One "this vs the same month last year" line.
class YearComparison {
  const YearComparison({
    required this.title,
    required this.month,
    required this.units,
    required this.lastYear,
    this.amount,
    this.projected = false,
  });

  /// "This month" or "Latest bill".
  final String title;

  /// Bill month being compared ("YYYY-MM").
  final String month;
  final int units;
  final double? amount;

  /// True when [units] is a month-end projection, not a final bill.
  final bool projected;

  /// The bill for the same month a year earlier.
  final Bill lastYear;

  int get unitDiff => units - lastYear.units;

  /// Change in units as a fraction (0.12 = 12% more); null if last year was 0.
  double? get unitChange => lastYear.units == 0 ? null : unitDiff / lastYear.units;

  double? get amountDiff => amount == null || amount == 0 || lastYear.amount == 0 ? null : amount! - lastYear.amount;
}

class YearComparisons {
  YearComparisons._();

  static String _lastYearKey(String month) {
    final d = Fmt.parseMonthKey(month);
    return Fmt.monthKey(DateTime(d.year - 1, d.month));
  }

  /// Comparisons that have a bill from a year earlier to compare with:
  /// the month in progress (projected) and the latest bill.
  static List<YearComparison> build({required List<Bill> bills, CycleSummary? summary}) {
    final byMonth = {for (final b in bills) b.month: b};
    final out = <YearComparison>[];

    // A bill for month M has its present reading on the reading day of M,
    // so the cycle in progress becomes the bill for the month it ends in.
    if (summary != null && summary.hasData) {
      final month = Fmt.monthKey(summary.cycleEnd);
      final last = byMonth[_lastYearKey(month)];
      if (last != null && !byMonth.containsKey(month)) {
        out.add(YearComparison(
          title: 'This month',
          month: month,
          units: summary.projectedUnits.round(),
          amount: summary.estimateProjected.total,
          projected: true,
          lastYear: last,
        ));
      }
    }

    final latest = bills.isEmpty ? null : (bills.toList()..sort((a, b) => b.month.compareTo(a.month))).first;
    if (latest != null) {
      final last = byMonth[_lastYearKey(latest.month)];
      if (last != null) {
        out.add(YearComparison(
          title: 'Latest bill',
          month: latest.month,
          units: latest.units,
          amount: latest.amount,
          lastYear: last,
        ));
      }
    }
    return out;
  }
}
