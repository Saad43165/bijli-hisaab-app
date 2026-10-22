import 'package:bijli_bachao/data/models/meter.dart';
import 'package:bijli_bachao/data/models/meter_reading.dart';
import 'package:bijli_bachao/data/models/tariff.dart';
import 'package:bijli_bachao/services/tariff_calculator.dart';
import 'package:bijli_bachao/services/usage_forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tariff_calculator_test.dart' show loadTariff;

void main() {
  final now = DateTime(2026, 10, 21);
  final tariff = loadTariff();
  final forecaster = UsageForecaster(TariffCalculator(tariff));

  Meter meter(MeterType type, {double load = 2}) => Meter(
        id: 1,
        name: 'Home',
        disco: 'LESCO',
        city: 'Lahore',
        province: 'Punjab',
        connectionType: 'home',
        phase: 'three',
        sanctionedLoadKw: load,
        protectedSetting: ProtectedSetting.unprotected,
        readingDay: 10,
        createdAt: DateTime(2026, 1, 1),
        meterType: type,
      );

  MeterReading r(int day, double value, {double? peak, double? export}) => MeterReading(
        meterId: 1,
        date: DateTime(2026, 10, day),
        value: value,
        createdAt: now,
        peakValue: peak,
        exportValue: export,
      );

  CycleSummary compute(Meter m, List<MeterReading> rs) => forecaster.compute(
        meter: m,
        readings: rs,
        consumerClass: ConsumerClass.unprotected,
        protectionReason: '',
        now: now,
      );

  test('TOU: peak share from the registers, no slabs, peak/off-peak rates', () {
    final s = compute(
      meter(MeterType.tou, load: 6),
      [r(10, 5000, peak: 1000), r(20, 5400, peak: 1100)],
    );
    expect(s.peakShare, closeTo(0.25, 1e-9));
    expect(s.targetLimit, isNull, reason: 'TOU bills have no slabs');
    expect(s.status, UsageStatus.safe);

    final e = s.estimateNow;
    expect(e.isTou, isTrue);
    expect(e.slabLabel, 'TOU');
    expect(e.peakUnits, 100);
    expect(e.energy, closeTo(100 * tariff.tou.peakRate + 300 * tariff.tou.offPeakRate, 1e-6));
    expect(e.fixed, closeTo(tariff.tou.fixedPerKw * 6 * tariff.tou.fixedLoadShare, 1e-6));
  });

  test('net billing: imports at slab rates, exports credited at the buyback rate', () {
    final s = compute(
      meter(MeterType.netBilling),
      [r(10, 1000, export: 500), r(20, 1200, export: 800)],
    );
    expect(s.unitsUsed, 200, reason: 'slabs follow imported units');
    expect(s.exportSoFar, closeTo(300, 1e-9));
    final e = s.estimateNow;
    expect(e.exportUnits, 300);
    expect(e.exportCredit, closeTo(300 * tariff.solar.netBillingRate, 1e-6));
    expect(e.total, closeTo(e.charges - e.exportCredit, 1e-6));
  });

  test('net metering: billed on import − export; a surplus is credited', () {
    final s = compute(
      meter(MeterType.netMetering),
      [r(10, 1000, export: 500), r(20, 1200, export: 800)],
    );
    // Net register went from 500 to 400: 100 units more sent than used.
    expect(s.unitsUsed, 0);
    final e = s.estimateNow;
    expect(e.exportUnits, 100);
    expect(e.exportCredit, closeTo(100 * tariff.solar.netMeteringRate, 1e-6));
    expect(e.total, lessThan(0), reason: 'the company owes the consumer');
  });

  test('net metering with more use than export bills only the net units', () {
    final s = compute(
      meter(MeterType.netMetering),
      [r(10, 1000, export: 500), r(20, 1300, export: 600)],
    );
    expect(s.unitsUsed, 200);
    expect(s.estimateNow.exportCredit, 0);
  });

  test('TOU and solar rates survive a JSON round trip and are validated', () {
    final t = Tariff.fromJson(tariff.toJson());
    expect(t.tou.peakRate, tariff.tou.peakRate);
    expect(t.solar.netBillingRate, tariff.solar.netBillingRate);
    expect(TariffValidator.validate(t), isNull);
    expect(TariffValidator.validate(t.copyWith(tou: t.tou.copyWith(peakRate: -1))), isNotNull);
  });

  test('older rate files without TOU or solar get the defaults', () {
    final j = tariff.toJson()
      ..remove('tou')
      ..remove('solar');
    final t = Tariff.fromJson(j);
    expect(t.tou.peakRate, TouRates.defaults.peakRate);
    expect(t.solar.netMeteringRate, SolarRates.defaults.netMeteringRate);
  });
}
