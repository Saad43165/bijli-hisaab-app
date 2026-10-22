import 'package:bijli_bachao/data/models/bill.dart';
import 'package:bijli_bachao/services/year_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

Bill _bill(String month, int units, [double amount = 0]) =>
    Bill(meterId: 1, month: month, units: units, amount: amount, createdAt: DateTime(2026));

void main() {
  test('latest bill is compared with the same month a year earlier', () {
    final items = YearComparisons.build(bills: [
      _bill('2026-09', 330, 14000),
      _bill('2026-08', 300),
      _bill('2025-09', 300, 11000),
    ]);
    expect(items, hasLength(1));
    final c = items.single;
    expect(c.month, '2026-09');
    expect(c.lastYear.month, '2025-09');
    expect(c.unitDiff, 30);
    expect(c.unitChange, closeTo(0.10, 1e-9));
    expect(c.amountDiff, 3000);
  });

  test('nothing to compare without last year\'s bill', () {
    expect(YearComparisons.build(bills: [_bill('2026-09', 330), _bill('2026-08', 300)]), isEmpty);
    expect(YearComparisons.build(bills: const []), isEmpty);
  });

  test('unknown amounts give no money difference', () {
    final c = YearComparisons.build(bills: [_bill('2026-01', 150), _bill('2025-01', 200, 9000)]).single;
    expect(c.unitChange, closeTo(-0.25, 1e-9));
    expect(c.amountDiff, isNull);
  });
}
