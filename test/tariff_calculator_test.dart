import 'dart:convert';
import 'dart:io';

import 'package:bijli_bachao/data/models/tariff.dart';
import 'package:bijli_bachao/services/tariff_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

Tariff loadTariff() => Tariff.fromJson(
      jsonDecode(File('assets/config/tariff_pk.json').readAsStringSync()) as Map<String, dynamic>,
    );

void main() {
  late Tariff tariff;
  late TariffCalculator calc;

  setUp(() {
    tariff = loadTariff();
    calc = TariffCalculator(tariff);
  });

  test('bundled tariff is valid and matches the NEPRA decision', () {
    expect(TariffValidator.validate(tariff), isNull);
    expect(tariff.protectedThresholdUnits, 200);
    expect(tariff.lifelineCategory!.slabs.length, 2);
    expect(tariff.protectedCategory.slabs.length, 2);
    expect(tariff.unprotectedCategory.slabs.length, 8);
    expect(tariff.unprotectedCategory.slabs.last.to, isNull);
    expect(tariff.unprotectedCategory.slabs[2].rate, 33.10);
    expect(tariff.unprotectedCategory.limits, [100, 200, 300, 400, 500, 600, 700]);
    expect(tariff.tvFee, 0);
    expect(tariff.dutyFor('Punjab'), 0);
  });

  test('protected 150 units uses one-previous-slab benefit', () {
    final energy = TariffCalculator.energyCharge(150, tariff.protectedCategory);
    expect(energy, closeTo(100 * 10.54 + 50 * 13.01, 0.001));
  });

  test('unprotected 250 units bills all units at the 201-300 rate', () {
    final energy = TariffCalculator.energyCharge(250, tariff.unprotectedCategory);
    expect(energy, closeTo(250 * 33.10, 0.001));
  });

  test('200 vs 201 units: crossing the slab reprices the whole month', () {
    expect(TariffCalculator.energyCharge(200, tariff.unprotectedCategory), closeTo(5782, 0.001));
    expect(TariffCalculator.energyCharge(201, tariff.unprotectedCategory), closeTo(6653.1, 0.001));
  });

  test('incremental mode sums each slab', () {
    final cat = tariff.unprotectedCategory.copyWith(billingMode: BillingMode.incremental);
    final energy = TariffCalculator.energyCharge(250, cat);
    expect(energy, closeTo(100 * 22.44 + 100 * 28.91 + 50 * 33.10, 0.001));
  });

  test('protected consumer above 200 units is billed at unprotected rates', () {
    final e = calc.estimate(201,
        consumerClass: ConsumerClass.protected, sanctionedLoadKw: 1, province: 'Punjab');
    expect(e.appliedClass, ConsumerClass.unprotected);
    expect(e.energy, closeTo(201 * 33.10, 0.001));
  });

  test('lifeline: no fixed charge, no FCA/QTA; above 100 moves to protected', () {
    final e = calc.estimate(80,
        consumerClass: ConsumerClass.lifeline, sanctionedLoadKw: 1, province: 'Punjab');
    expect(e.appliedClass, ConsumerClass.lifeline);
    expect(e.energy, closeTo(80 * 7.74, 0.001));
    expect(e.fixed, 0);
    expect(e.fca, 0);
    expect(e.qta, 0);
    final over = calc.estimate(120,
        consumerClass: ConsumerClass.lifeline, sanctionedLoadKw: 1, province: 'Punjab');
    expect(over.appliedClass, ConsumerClass.protected);
  });

  test('full estimate: energy + fixed + surcharge + FCA + QTA, GST on all', () {
    final e = calc.estimate(250,
        consumerClass: ConsumerClass.unprotected, sanctionedLoadKw: 2, province: 'Punjab');
    const energy = 250 * 33.10;
    const fixed = 350.0 * 2;
    const fc = 3.23 * 250;
    const fca = 1.1086 * 250;
    const qta = 0.5194 * 250;
    const gst = (energy + fixed + fc + fca + qta) * 0.18;
    expect(e.fixed, closeTo(fixed, 0.001));
    expect(e.fcSurcharge, closeTo(fc, 0.001));
    expect(e.fca, closeTo(fca, 0.001));
    expect(e.qta, closeTo(qta, 0.001));
    expect(e.electricityDuty, 0);
    expect(e.gst, closeTo(gst, 0.001));
    expect(e.total, closeTo(energy + fixed + fc + fca + qta + gst, 0.01));
  });

  test('protected consumers pay no FC surcharge', () {
    final e = calc.estimate(150,
        consumerClass: ConsumerClass.protected, sanctionedLoadKw: 1, province: 'Punjab');
    expect(e.fcSurcharge, 0);
  });

  test('zero units costs nothing', () {
    final e = calc.estimate(0,
        consumerClass: ConsumerClass.unprotected, sanctionedLoadKw: 2, province: 'Punjab');
    expect(e.total, 0);
  });

  test('warning limits per consumer class', () {
    expect(calc.limitsFor(ConsumerClass.unprotected), [100, 200, 300, 400, 500, 600, 700]);
    expect(calc.limitsFor(ConsumerClass.protected), [100, 200, 300, 400, 500, 600, 700]);
    expect(calc.limitsFor(ConsumerClass.lifeline), [50, 100, 200, 300, 400, 500, 600, 700]);
  });

  test('validator rejects broken published rates', () {
    final json = jsonDecode(File('assets/config/tariff_pk.json').readAsStringSync()) as Map<String, dynamic>;
    (json['unprotected'] as Map)['slabs'] = [
      {'from': 1, 'to': 100, 'rate': 22.44},
      {'from': 150, 'to': null, 'rate': 28.91},
    ];
    expect(TariffValidator.validate(Tariff.fromJson(json)), isNotNull);

    final future = jsonDecode(File('assets/config/tariff_pk.json').readAsStringSync()) as Map<String, dynamic>;
    future['schema_version'] = 99;
    expect(TariffValidator.validate(Tariff.fromJson(future)), isNotNull);
  });
}
