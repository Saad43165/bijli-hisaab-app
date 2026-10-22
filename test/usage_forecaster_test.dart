import 'package:bijli_bachao/core/utils/date_utils.dart';
import 'package:bijli_bachao/data/models/meter.dart';
import 'package:bijli_bachao/data/models/meter_reading.dart';
import 'package:bijli_bachao/data/models/tariff.dart';
import 'package:bijli_bachao/services/tariff_calculator.dart';
import 'package:bijli_bachao/services/usage_forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tariff_calculator_test.dart' show loadTariff;

void main() {
  final meter = Meter(
    id: 1,
    name: 'Home',
    disco: 'LESCO',
    city: 'Lahore',
    province: 'Punjab',
    connectionType: 'home',
    phase: 'single',
    sanctionedLoadKw: 2,
    protectedSetting: ProtectedSetting.unprotected,
    readingDay: 10,
    createdAt: DateTime(2026, 1, 1),
  );
  final now = DateTime(2026, 10, 21);

  MeterReading r(int month, int day, double value) => MeterReading(
        meterId: 1,
        date: DateTime(2026, month, day),
        value: value,
        createdAt: now,
      );

  late UsageForecaster forecaster;
  setUp(() => forecaster = UsageForecaster(TariffCalculator(loadTariff())));

  group('DateX', () {
    test('cycle start and end around the reading day', () {
      expect(DateX.cycleStart(DateTime(2026, 10, 21), 10), DateTime(2026, 10, 10));
      expect(DateX.cycleStart(DateTime(2026, 10, 5), 10), DateTime(2026, 9, 10));
      expect(DateX.nextCycleStart(DateTime(2026, 10, 10), 10), DateTime(2026, 11, 10));
    });

    test('reading day 31 is clamped to short months', () {
      expect(DateX.clampedDay(2026, 2, 31), DateTime(2026, 2, 28));
      expect(DateX.cycleStart(DateTime(2026, 3, 15), 31), DateTime(2026, 2, 28));
      expect(DateX.nextCycleStart(DateTime(2026, 2, 28), 31), DateTime(2026, 3, 31));
    });

    test('month overflow rolls into the next year', () {
      expect(DateX.clampedDay(2026, 13, 5), DateTime(2027, 1, 5));
      expect(DateX.cycleStart(DateTime(2026, 1, 3), 10), DateTime(2025, 12, 10));
    });
  });

  test('projects month-end units and flags crossing the next limit', () {
    final s = forecaster.compute(
      meter: meter,
      readings: [r(10, 10, 1000), r(10, 20, 1080)],
      consumerClass: ConsumerClass.unprotected,
      protectionReason: 'test',
      now: now,
    );
    expect(s.status, UsageStatus.danger);
    expect(s.unitsUsed, closeTo(80, 0.001));
    expect(s.dailyRate, closeTo(8, 0.001));
    expect(s.projectedUnits, closeTo(248, 0.001)); // 80 + 8 × 21 days
    expect(s.targetLimit, 100);
    expect(s.safeDailyBudget, closeTo(1.0, 0.001)); // 20 units / 20 days
    expect(s.alternativeLimit, 300);
    expect(s.alternativeBudget, closeTo(11.0, 0.001));
    expect(s.daysTotal, 31);
  });

  test('protected user projected above 200 is at risk', () {
    final s = forecaster.compute(
      meter: meter,
      readings: [r(10, 10, 1000), r(10, 20, 1120)],
      consumerClass: ConsumerClass.protected,
      protectionReason: 'test',
      now: now,
    );
    expect(s.targetLimit, 200);
    expect(s.status, UsageStatus.danger);
    expect(s.protectionAtRisk, isTrue);
  });

  test('interpolates the baseline when no reading is on the cycle start', () {
    final s = forecaster.compute(
      meter: meter,
      readings: [r(10, 5, 1000), r(10, 15, 1100)],
      consumerClass: ConsumerClass.unprotected,
      protectionReason: 'test',
      now: now,
    );
    expect(s.baselineValue, closeTo(1050, 0.001));
    expect(s.unitsUsed, closeTo(50, 0.001));
    expect(s.dailyRate, closeTo(10, 0.001));
  });

  test('one reading in the cycle is not enough', () {
    final s = forecaster.compute(
      meter: meter,
      readings: [r(10, 12, 1000)],
      consumerClass: ConsumerClass.unprotected,
      protectionReason: 'test',
      now: now,
    );
    expect(s.hasData, isFalse);
  });

  test('low steady use is safe', () {
    final s = forecaster.compute(
      meter: meter,
      readings: [r(10, 10, 1000), r(10, 20, 1020)],
      consumerClass: ConsumerClass.unprotected,
      protectionReason: 'test',
      now: now,
    );
    // 2/day → 20 + 42 = 62 projected, under 100
    expect(s.status, UsageStatus.safe);
    expect(s.projectedUnits, closeTo(62, 0.001));
  });
}
