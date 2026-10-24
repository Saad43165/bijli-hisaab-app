import 'package:bijli_bachao/data/models/bill.dart';
import 'package:bijli_bachao/services/advice.dart';
import 'package:flutter_test/flutter_test.dart';

Bill bill(String month, int units, {double amount = 0, DateTime? due}) =>
    Bill(meterId: 1, month: month, units: units, amount: amount, dueDate: due, createdAt: DateTime(2026));

// Simple fake tariff: protected Rs 20/unit, unprotected Rs 40/unit.
double est(int u, bool p) => u * (p ? 20.0 : 40.0);

void main() {
  const engine = AdviceEngine(estimate: est);
  final today = DateTime(2026, 10, 30);

  test('due in 3 days comes first', () {
    final a = engine.build(
      newestFirst: [bill('2026-10', 91, amount: 3937, due: DateTime(2026, 11, 2))],
      today: today,
      isProtected: false,
      predictedNext: 93,
      tracking: true,
    );
    expect(a.first.title, contains('3,937'));
    expect(a.first.screen, 'bill_online');
  });

  test('unprotected with only a couple of months over 200 shows the path back', () {
    final bills = [
      bill('2026-10', 91), bill('2026-09', 261), bill('2026-08', 150),
      bill('2026-07', 120), bill('2026-06', 110), bill('2026-05', 100),
    ];
    final a = engine.build(newestFirst: bills, today: today, isProtected: false, predictedNext: 93, tracking: true);
    expect(a.any((x) => x.title.contains('Protected rates')), isTrue);
  });

  test('protected but next bill over 200 warns', () {
    final a = engine.build(
      newestFirst: [bill('2026-10', 190)],
      today: today,
      isProtected: true,
      predictedNext: 230,
      tracking: true,
    );
    expect(a.any((x) => x.title.contains('could cross 200')), isTrue);
  });

  test('just over a slab suggests cutting a few units', () {
    final a = engine.build(
      newestFirst: [bill('2026-10', 300)],
      today: today,
      isProtected: false,
      predictedNext: 308,
      tracking: true,
    );
    expect(a.any((x) => x.title.contains('Cut 8 units')), isTrue);
  });

  test('at most 3 items, and tracking tip when not tracking', () {
    final a = engine.build(newestFirst: [bill('2026-10', 91)], today: today, isProtected: true, predictedNext: 93, tracking: false);
    expect(a.length, lessThanOrEqualTo(3));
    expect(a.last.screen, 'add_reading');
  });
}
