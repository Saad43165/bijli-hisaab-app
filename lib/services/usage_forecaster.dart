import '../core/utils/date_utils.dart';
import '../data/models/meter.dart';
import '../data/models/meter_reading.dart';
import '../data/models/tariff.dart';
import 'tariff_calculator.dart';

enum UsageStatus { noData, safe, warn, danger, overLimits }

class DailyUsagePoint {
  const DailyUsagePoint(this.date, this.unitsPerDay);

  final DateTime date;
  final double unitsPerDay;
}

/// Everything the dashboard needs for the current billing cycle.
class CycleSummary {
  const CycleSummary({
    required this.cycleStart,
    required this.cycleEnd,
    required this.today,
    required this.consumerClass,
    required this.protectionReason,
    required this.status,
    this.unitsUsed = 0,
    this.dailyRate = 0,
    this.projectedUnits = 0,
    this.latestReadingDate,
    this.latestReadingValue,
    this.baselineValue,
    this.baselineDate,
    this.targetLimit,
    this.safeDailyBudget,
    this.extraCostIfCrossed = 0,
    this.alternativeLimit,
    this.alternativeBudget,
    this.estimateNow = BillEstimate.zero,
    this.estimateProjected = BillEstimate.zero,
    this.points = const [],
    this.readingsInCycle = 0,
    this.protectedThreshold = 200,
    this.meterType = MeterType.standard,
    this.peakShare,
    this.exportSoFar = 0,
    this.exportProjected = 0,
  });

  final DateTime cycleStart;

  /// Exclusive: the next reading day.
  final DateTime cycleEnd;
  final DateTime today;
  final ConsumerClass consumerClass;
  final String protectionReason;
  final UsageStatus status;

  final double unitsUsed;
  final double dailyRate;
  final double projectedUnits;
  final DateTime? latestReadingDate;
  final double? latestReadingValue;
  final double? baselineValue;
  final DateTime? baselineDate;

  /// Nearest slab limit the user is still under.
  final int? targetLimit;

  /// Max units per day for the rest of the cycle to stay under [targetLimit].
  final double? safeDailyBudget;

  /// How much more the projected bill costs vs staying at [targetLimit].
  final double extraCostIfCrossed;

  /// A realistic next limit when [targetLimit] can't be saved.
  final int? alternativeLimit;
  final double? alternativeBudget;

  final BillEstimate estimateNow;
  final BillEstimate estimateProjected;
  final List<DailyUsagePoint> points;
  final int readingsInCycle;
  final int protectedThreshold;

  final MeterType meterType;

  /// TOU meters: share of units used in peak hours (0..1), from readings.
  final double? peakShare;

  /// Solar meters: units sent to the grid this cycle so far / by month end.
  final double exportSoFar;
  final double exportProjected;

  bool get isTou => meterType == MeterType.tou;
  bool get isSolar => meterType.isSolar;

  bool get hasData => status != UsageStatus.noData;

  int get daysTotal => DateX.daysBetween(cycleStart, cycleEnd);
  int get dayOfCycle => (DateX.daysBetween(cycleStart, today) + 1).clamp(1, daysTotal);
  int get daysLeft => DateX.daysBetween(today, cycleEnd).clamp(0, daysTotal);

  bool get isProtected => consumerClass.hasProtection;

  /// Protected/lifeline consumer projected to go over the threshold this month.
  bool get protectionAtRisk => isProtected && projectedUnits > protectedThreshold;

  /// Lifeline consumer projected to go over 100 units.
  bool get lifelineAtRisk => consumerClass == ConsumerClass.lifeline && projectedUnits > 100;

  /// Progress towards the target limit, 0..1.
  double get progress {
    final t = targetLimit;
    if (t == null || t == 0) return 1;
    return (unitsUsed / t).clamp(0, 1).toDouble();
  }
}

/// Pure logic: turns readings into a [CycleSummary].
class UsageForecaster {
  const UsageForecaster(this.calculator);

  final TariffCalculator calculator;

  CycleSummary compute({
    required Meter meter,
    required List<MeterReading> readings,
    required ConsumerClass consumerClass,
    required String protectionReason,
    DateTime? now,
  }) {
    final today = DateX.dateOnly(now ?? DateTime.now());
    final start = DateX.cycleStart(today, meter.readingDay);
    final end = DateX.nextCycleStart(start, meter.readingDay);
    final threshold = calculator.tariff.protectedThresholdUnits;

    CycleSummary empty({int inCycle = 0, MeterReading? latest}) => CycleSummary(
          cycleStart: start,
          cycleEnd: end,
          today: today,
          consumerClass: consumerClass,
          protectionReason: protectionReason,
          status: UsageStatus.noData,
          readingsInCycle: inCycle,
          latestReadingDate: latest?.date,
          latestReadingValue: latest?.value,
          protectedThreshold: threshold,
          meterType: meter.meterType,
        );

    // Net metering is billed on import − export; everything else on the
    // import (total) register. Slabs, projections and charts all use this.
    final netMetering = meter.meterType == MeterType.netMetering;
    final series = [
      for (final r in readings)
        netMetering
            ? MeterReading(
                id: r.id,
                meterId: r.meterId,
                date: r.date,
                value: r.value - (r.exportValue ?? 0),
                source: r.source,
                createdAt: r.createdAt,
                peakValue: r.peakValue,
                exportValue: r.exportValue,
              )
            : r,
    ];
    final sorted = [...series]..sort((a, b) => a.date.compareTo(b.date));
    final valid = sorted.where((r) => !DateX.dateOnly(r.date).isAfter(today)).toList();
    if (valid.isEmpty) return empty();

    final latest = valid.last;
    final latestDate = DateX.dateOnly(latest.date);
    final inCycle = valid.where((r) => !DateX.dateOnly(r.date).isBefore(start)).toList();
    final before = valid.where((r) => !DateX.dateOnly(r.date).isAfter(start)).toList();

    if (latestDate.isBefore(start)) return empty(latest: latest);

    // Baseline: meter value at the start of the cycle.
    double baselineValue;
    DateTime baselineDate;
    if (before.isNotEmpty) {
      final b = before.last;
      final bDate = DateX.dateOnly(b.date);
      if (bDate == start) {
        baselineValue = b.value;
      } else {
        final firstAfter = inCycle.firstWhere(
          (r) => DateX.dateOnly(r.date).isAfter(start),
          orElse: () => latest,
        );
        final span = DateX.daysBetween(bDate, DateX.dateOnly(firstAfter.date));
        final toStart = DateX.daysBetween(bDate, start);
        final delta = firstAfter.value - b.value;
        baselineValue = span <= 0 ? b.value : b.value + delta * toStart / span;
      }
      baselineDate = start;
    } else {
      final first = inCycle.first;
      baselineValue = first.value;
      baselineDate = DateX.dateOnly(first.date);
    }

    final elapsed = DateX.daysBetween(baselineDate, latestDate);
    if (elapsed <= 0) return empty(inCycle: inCycle.length, latest: latest);

    // Net metering can go below zero when solar sends more than you use.
    final rawUsed = latest.value - baselineValue;
    final used = rawUsed.clamp(0, double.infinity).toDouble();
    final rate = used / elapsed;
    final remainingDays = DateX.daysBetween(latestDate, end).clamp(0, 400);
    final projected = used + rate * remainingDays;
    final projectedRaw = rawUsed + rawUsed / elapsed * remainingDays;
    final daysLeftFromToday = DateX.daysBetween(today, end).clamp(0, 400);

    // Extra registers, measured from the reading the baseline came from.
    final anchor = before.isNotEmpty ? before.last : inCycle.first;
    final anchorDays = DateX.daysBetween(DateX.dateOnly(anchor.date), latestDate);
    double? peakShare;
    final peakA = anchor.peakValue, peakB = latest.peakValue;
    if (meter.meterType == MeterType.tou && peakA != null && peakB != null) {
      final importDelta = latest.value - anchor.value;
      if (importDelta > 0) peakShare = ((peakB - peakA) / importDelta).clamp(0.0, 1.0).toDouble();
    }
    var exportPerDay = 0.0;
    final expA = anchor.exportValue, expB = latest.exportValue;
    if (meter.meterType.isSolar && expA != null && expB != null && anchorDays > 0) {
      exportPerDay = ((expB - expA) / anchorDays).clamp(0, double.infinity).toDouble();
    }
    final exportSoFar = exportPerDay * elapsed;
    final exportProjected = exportPerDay * (elapsed + remainingDays);

    BillEstimate bill(int units, {bool projectedBill = false}) => _bill(
          meter,
          units,
          consumerClass,
          peakShare: peakShare,
          exportUnits: (projectedBill ? exportProjected : exportSoFar).round(),
          netSurplus: netMetering ? (-(projectedBill ? projectedRaw : rawUsed)).round() : 0,
        );

    // Limits and target.
    // TOU meters have no slabs, so there's no limit to warn about.
    final tou = meter.meterType == MeterType.tou;
    final limits = tou ? const <int>[] : calculator.limitsFor(consumerClass);
    final usedInt = used.floor();
    int? target;
    for (final l in limits) {
      if (usedInt <= l) {
        target = l;
        break;
      }
    }

    UsageStatus status;
    double? budget;
    var extraCost = 0.0;
    int? altLimit;
    double? altBudget;

    final projInt = projected.round();
    final estNow = bill(usedInt);
    final estProj = bill(projInt, projectedBill: true);

    if (target == null) {
      status = tou ? UsageStatus.safe : UsageStatus.overLimits;
    } else {
      final margin = (target * 0.08).clamp(8, 40);
      if (projected > target) {
        status = UsageStatus.danger;
        extraCost = estProj.total - bill(target, projectedBill: true).total;
      } else if (projected >= target - margin) {
        status = UsageStatus.warn;
      } else {
        status = UsageStatus.safe;
      }
      final days = daysLeftFromToday == 0 ? 1 : daysLeftFromToday;
      budget = ((target - used) / days).clamp(0, double.infinity).toDouble();

      // If staying under the target would need cutting usage by >60%,
      // also show the next realistic limit.
      if (status == UsageStatus.danger && budget < rate * 0.4) {
        final idx = limits.indexOf(target);
        for (var i = idx + 1; i < limits.length; i++) {
          if (projected <= limits[i]) {
            altLimit = limits[i];
            altBudget = ((limits[i] - used) / days).clamp(0, double.infinity).toDouble();
            break;
          }
        }
      }
    }

    return CycleSummary(
      cycleStart: start,
      cycleEnd: end,
      today: today,
      consumerClass: consumerClass,
      protectionReason: protectionReason,
      status: status,
      unitsUsed: used,
      dailyRate: rate,
      projectedUnits: projected,
      latestReadingDate: latestDate,
      latestReadingValue: latest.value,
      baselineValue: baselineValue,
      baselineDate: baselineDate,
      targetLimit: target,
      safeDailyBudget: budget,
      extraCostIfCrossed: extraCost < 0 ? 0 : extraCost,
      alternativeLimit: altLimit,
      alternativeBudget: altBudget,
      estimateNow: estNow,
      estimateProjected: estProj,
      points: _points(valid, start.subtract(const Duration(days: 35))),
      readingsInCycle: inCycle.length,
      protectedThreshold: threshold,
      meterType: meter.meterType,
      peakShare: peakShare,
      exportSoFar: exportSoFar,
      exportProjected: exportProjected,
    );
  }

  /// Typical peak share for a TOU meter until readings show the real one
  /// (4 peak hours of 24, used more heavily in the evening).
  static const double defaultPeakShare = 0.25;

  /// The bill for [units] on this kind of meter.
  BillEstimate _bill(
    Meter meter,
    int units,
    ConsumerClass c, {
    double? peakShare,
    int exportUnits = 0,
    int netSurplus = 0,
  }) {
    final solar = calculator.tariff.solar;
    switch (meter.meterType) {
      case MeterType.standard:
        return _estimate(meter, units, c);
      case MeterType.tou:
        return calculator.estimateTou(
          units,
          peakUnits: (units * (peakShare ?? defaultPeakShare)).round(),
          sanctionedLoadKw: meter.sanctionedLoadKw,
          province: meter.province,
        );
      case MeterType.netBilling:
        final e = _estimate(meter, units, c);
        return exportUnits <= 0 ? e : e.withExport(exportUnits, exportUnits * solar.netBillingRate);
      case MeterType.netMetering:
        final e = _estimate(meter, units, c);
        return netSurplus <= 0 ? e : e.withExport(netSurplus, netSurplus * solar.netMeteringRate);
    }
  }

  BillEstimate _estimate(Meter meter, int units, ConsumerClass c) => calculator.estimate(
        units,
        consumerClass: c,
        sanctionedLoadKw: meter.sanctionedLoadKw,
        province: meter.province,
      );

  /// Average units/day between consecutive readings since [from].
  static List<DailyUsagePoint> _points(List<MeterReading> sorted, DateTime from) {
    final out = <DailyUsagePoint>[];
    for (var i = 1; i < sorted.length; i++) {
      final a = sorted[i - 1];
      final b = sorted[i];
      final bDate = DateX.dateOnly(b.date);
      if (bDate.isBefore(from)) continue;
      final days = DateX.daysBetween(DateX.dateOnly(a.date), bDate);
      if (days <= 0) continue;
      final perDay = (b.value - a.value) / days;
      if (perDay < 0) continue; // meter replaced / typo
      out.add(DailyUsagePoint(bDate, perDay));
    }
    return out;
  }
}
