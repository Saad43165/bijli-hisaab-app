import 'package:bijli_bachao/services/bill_scan_analyzer.dart';
import 'package:bijli_bachao/services/bill_values.dart';
import 'package:flutter_test/flutter_test.dart';

OcrLine l(String t, double x1, double y1, double x2, double y2, {int page = 0}) =>
    OcrLine(t, OcrBox(x1, y1, x2, y2), page: page);

/// A WAPDA-style bill: labels with values to the right, and a readings table
/// where values sit under their column headers.
List<OcrLine> wapdaBill({String units = '214', String amount = '8,420'}) => [
      l('LAHORE ELECTRIC SUPPLY COMPANY', 10, 10, 300, 30),
      l('LESCO', 320, 10, 380, 30),
      l('BILL MONTH', 10, 60, 100, 80),
      l('SEP 26', 200, 60, 260, 80),
      l('UNITS CONSUMED', 10, 100, 150, 120),
      l(units, 300, 100, 340, 120),
      l('PREVIOUS', 10, 200, 90, 220),
      l('PRESENT', 110, 200, 190, 220),
      l('MF', 210, 200, 240, 220),
      l('12236', 10, 230, 80, 250),
      l('12450', 110, 230, 180, 250),
      l('1', 215, 230, 225, 250),
      l('DUE DATE', 10, 300, 90, 320),
      l('22-SEP-26', 200, 300, 290, 320),
      l('PAYABLE WITHIN DUE DATE', 10, 350, 200, 370),
      l(amount, 300, 350, 360, 370),
      l('PAYABLE AFTER DUE DATE', 10, 380, 200, 400),
      l('8,900', 300, 380, 360, 400),
    ];

void main() {
  const analyzer = BillScanAnalyzer();
  final now = DateTime(2026, 10, 21);

  test('reads labels, right-hand cells and table columns', () {
    final a = analyzer.analyze(wapdaBill(), now: now);
    expect(a.disco, 'LESCO');
    expect(a.month?.value, '2026-09');
    expect(a.units?.value, 214);
    expect(a.amount?.value, 8420, reason: 'must not pick the after-due-date amount');
    expect(a.dueDate?.value, DateTime(2026, 9, 22));
    expect(a.presentReading?.value, 12450);
    expect(a.previousReading?.value, 12236);
    expect(a.multiplier?.value, 1);
    expect(a.warnings, isEmpty);
  });

  test('units that match the readings are marked sure', () {
    final a = analyzer.analyze(wapdaBill(), now: now);
    expect(a.units?.confidence, FieldConfidence.high);
    expect(a.presentReading?.confidence, FieldConfidence.high);
    expect(a.units?.source?.text, '214');
  });

  test('units that disagree with the readings are flagged', () {
    final a = analyzer.analyze(wapdaBill(units: '250'), now: now);
    expect(a.units?.confidence, FieldConfidence.low);
    expect(a.warnings, isNotEmpty);
  });

  test('OCR letter/digit swaps are fixed', () {
    final a = analyzer.analyze(wapdaBill(units: '2l4', amount: '8,42O'), now: now);
    expect(a.units?.value, 214);
    expect(a.amount?.value, 8420);
  });

  test('amount far from the expected bill is flagged', () {
    final a = analyzer.analyze(wapdaBill(), now: now, estimateAmount: (u) => u * 10.0);
    expect(a.amount?.confidence, FieldConfidence.low);
    expect(a.warnings.any((w) => w.contains('amount')), isTrue);

    final ok = analyzer.analyze(wapdaBill(), now: now, estimateAmount: (u) => u * 35.0);
    expect(ok.amount?.confidence, isNot(FieldConfidence.low));
  });

  test('units are worked out from readings when not printed', () {
    final lines = wapdaBill()..removeWhere((x) => x.text == 'UNITS CONSUMED' || x.text == '214');
    final a = analyzer.analyze(lines, now: now);
    expect(a.units?.value, 214);
    expect(a.units?.confidence, isNot(FieldConfidence.low));
  });

  test('second scan fills gaps and keeps the more confident value', () {
    final front = analyzer.analyze(
      [l('UNITS CONSUMED', 10, 100, 150, 120), l('214', 300, 100, 340, 120)],
      now: now,
    );
    final back = analyzer.analyze(
      [l('PAYABLE WITHIN DUE DATE', 10, 350, 200, 370), l('8,420', 300, 350, 360, 370)],
      now: now,
    );
    final merged = front.mergeWith(back);
    expect(merged.units?.value, 214);
    expect(merged.amount?.value, 8420);
    expect(merged.pageCount, 2);
  });

  test('digit fixer leaves words alone', () {
    expect(BillValues.fixDigits('UNITS CONSUMED 2l4'), 'UNITS CONSUMED 214');
    expect(BillValues.fixDigits('OCT 2O26'), 'OCT 2026');
    expect(BillValues.fixDigits('IESCO'), 'IESCO');
  });
}
