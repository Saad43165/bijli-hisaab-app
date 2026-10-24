import 'package:bijli_bachao/data/models/tariff.dart';
import 'package:bijli_bachao/features/home/bill_calculator_screen.dart';
import 'package:bijli_bachao/features/home/solar_calculator_screen.dart';
import 'package:bijli_bachao/services/tariff_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tariff_calculator_test.dart' show loadTariff;

void main() {
  late Tariff t;
  late TariffCalculator calc;

  setUp(() {
    t = loadTariff();
    calc = TariffCalculator(t);
  });

  BillEstimate bill(int u, ConsumerClass c, {double load = 1}) =>
      calc.estimate(u, consumerClass: c, sanctionedLoadKw: load, province: 'Punjab');

  group('slab edges', () {
    test('protected: 100 is all first slab, 101 gets the previous-slab benefit', () {
      expect(bill(100, ConsumerClass.protected).energy, closeTo(100 * 10.54, 0.001));
      expect(bill(101, ConsumerClass.protected).energy, closeTo(100 * 10.54 + 1 * 13.01, 0.001));
    });

    test('protected stays protected at exactly 200 and loses it at 201', () {
      final at = bill(200, ConsumerClass.protected);
      final over = bill(201, ConsumerClass.protected);
      expect(at.appliedClass, ConsumerClass.protected);
      expect(at.energy, closeTo(100 * 10.54 + 100 * 13.01, 0.001));
      expect(over.appliedClass, ConsumerClass.unprotected);
      expect(over.energy, closeTo(201 * 33.10, 0.001));
      // Crossing 200 costs far more than one unit's worth.
      expect(over.total - at.total, greaterThan(2000));
    });

    test('unprotected 100 / 200 / 300 stay in their slab, one more unit moves up', () {
      expect(bill(100, ConsumerClass.unprotected).slab.rate, 22.44);
      expect(bill(101, ConsumerClass.unprotected).slab.rate, 28.91);
      expect(bill(200, ConsumerClass.unprotected).slab.rate, 28.91);
      expect(bill(300, ConsumerClass.unprotected).slab.rate, 33.10);
      expect(bill(301, ConsumerClass.unprotected).slab.rate, 36.46);
    });

    test('lifeline up to 100, protected above', () {
      expect(bill(100, ConsumerClass.lifeline).appliedClass, ConsumerClass.lifeline);
      expect(bill(101, ConsumerClass.lifeline).appliedClass, ConsumerClass.protected);
      expect(bill(201, ConsumerClass.lifeline).appliedClass, ConsumerClass.unprotected);
    });

    test('zero and negative units cost nothing', () {
      expect(bill(0, ConsumerClass.unprotected).total, 0);
      expect(bill(-5, ConsumerClass.unprotected).total, 0);
    });

    test('FCA and QTA apply to protected and unprotected, not lifeline', () {
      expect(bill(150, ConsumerClass.protected).fca, closeTo(150 * t.fcaPerUnit, 0.001));
      expect(bill(150, ConsumerClass.unprotected).qta, closeTo(150 * t.qtaPerUnit, 0.001));
      expect(bill(80, ConsumerClass.lifeline).fca, 0);
    });

    test('GST is on energy, fixed, surcharge, FCA and QTA', () {
      final e = bill(250, ConsumerClass.unprotected, load: 2);
      expect(e.gst, closeTo((e.energy + e.fixed + e.fcSurcharge + e.fca + e.qta) * t.gstPercent / 100, 0.001));
    });
  });

  group('calculator screen helpers', () {
    test('breakdown adds up to the total', () {
      for (final u in [50, 100, 150, 200, 201, 300, 450, 750]) {
        for (final c in ConsumerClass.values) {
          final e = bill(u, c, load: 3);
          final sum = BillCalculatorScreen.breakdown(e, t).fold<double>(0, (s, l) => s + l.amount);
          expect(sum, closeTo(e.total, 1), reason: '$u units, $c');
        }
      }
    });

    test('warns just over a limit with what it costs', () {
      double total(int u) => bill(u, ConsumerClass.unprotected).total;
      final limits = calc.limitsFor(ConsumerClass.unprotected);
      final w = BillCalculatorScreen.overLimit(205, limits, total)!;
      expect(w.$1, 200);
      expect(w.$2, closeTo(total(205) - total(200), 0.001));
      expect(BillCalculatorScreen.overLimit(260, limits, total), isNull);
      expect(BillCalculatorScreen.overLimit(80, limits, total), isNull);
    });

    test('protected user just over 200 is warned about losing protection', () {
      double total(int u) => bill(u, ConsumerClass.protected).total;
      final w = BillCalculatorScreen.overLimit(210, calc.limitsFor(ConsumerClass.protected), total)!;
      expect(w.$1, 200);
      expect(w.$2, greaterThan(2000));
    });
  });

  test('solar size rounds up to half a kW', () {
    final (kw, panels, made) = SolarCalculatorScreen.size(300);
    expect(kw, 2.5); // 300 / 120 = 2.5
    expect(panels, 5); // 2,500 W / 585 W
    expect(made, 300);
    expect(SolarCalculatorScreen.size(301).$1, 3.0);
    expect(SolarCalculatorScreen.size(3000).$1, 25.0);
  });
}
