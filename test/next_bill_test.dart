import 'package:bijli_bachao/data/models/bill.dart';
import 'package:bijli_bachao/features/home/widgets/bill_overview_card.dart';
import 'package:flutter_test/flutter_test.dart';

Bill bill(String month, int units) => Bill(meterId: 1, month: month, units: units, createdAt: DateTime(2026));

void main() {
  test('next bill uses the same month last year', () {
    final bills = [bill('2026-10', 91), bill('2026-09', 261), bill('2025-11', 93), bill('2025-10', 284)];
    expect(BillOverviewCard.nextUnits(bills), 93);
  });

  test('without last year, the average of the last 3 bills', () {
    final bills = [bill('2026-10', 90), bill('2026-09', 120), bill('2026-08', 150), bill('2026-07', 400)];
    expect(BillOverviewCard.nextUnits(bills), 120);
  });

  test('no bills, no prediction', () => expect(BillOverviewCard.nextUnits(const []), isNull));
}
