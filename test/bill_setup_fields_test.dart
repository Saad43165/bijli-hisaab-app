import 'package:bijli_bachao/services/bill_scan_analyzer.dart';
import 'package:bijli_bachao/services/bill_values.dart';
import 'package:flutter_test/flutter_test.dart';

OcrLine l(String t, double x1, double y1, double x2, double y2) => OcrLine(t, OcrBox(x1, y1, x2, y2));

/// IESCO-style header block: one row of column labels, values underneath.
List<OcrLine> iescoHeader() => [
      l('ISLAMABAD ELECTRIC SUPPLY COMPANY', 10, 10, 400, 30),
      // Header cells…
      l('CONNECTION DATE', 10, 60, 110, 76),
      l('CONNECTED LOAD', 120, 60, 220, 76),
      l('BILL MONTH', 230, 60, 310, 76),
      l('READING DATE', 320, 60, 410, 76),
      l('ISSUE DATE', 420, 60, 500, 76),
      l('DUE DATE', 510, 60, 590, 76),
      // …and the values under them (OCR joined the dates into one line).
      l('21 MAY 07', 20, 82, 100, 98),
      l('1.20', 150, 82, 190, 98),
      l('OCT 26', 245, 82, 295, 98),
      l('18 OCT 26   19 OCT 26   02 NOV 26', 325, 82, 590, 98),
      l('REFERENCE NO', 10, 120, 110, 136),
      l('TARIFF', 200, 120, 250, 136),
      l('SANCTIONED LOAD', 300, 120, 420, 136),
      l('06 14562 1211000 R', 10, 142, 150, 158),
      l('A-1(01)', 200, 142, 250, 158),
      l('2.00', 330, 142, 370, 158),
    ];

void main() {
  const analyzer = BillScanAnalyzer();
  final now = DateTime(2026, 10, 22);

  test('reads reference, sanctioned load and reading date for meter setup', () {
    final a = analyzer.analyze(iescoHeader(), now: now);
    expect(a.disco, 'IESCO');
    expect(a.reference, '06 14562 1211000 R');
    expect(a.load?.value, 2.0, reason: 'sanctioned load, not connected load');
    expect(a.readingDate?.value, DateTime(2026, 10, 18));
  });

  test('picks the date under its own column in a header row', () {
    final a = analyzer.analyze(iescoHeader(), now: now);
    expect(a.dueDate?.value, DateTime(2026, 11, 2));
  });

  group('findReference', () {
    test('WAPDA reference next to its label', () {
      expect(BillValues.findReference('REF NO: 06 14562 1211000 U  TARIFF A-1'), '06 14562 1211000 U');
      expect(BillValues.findReference('REFERENCE NUMBER 03112450123456'), '03 11245 0123456');
    });

    test('K-Electric account number', () {
      expect(BillValues.findReference('ACCOUNT NO: 0400012345678'), '0400012345678');
    });

    test('ignores digits inside a longer barcode', () {
      expect(BillValues.findReference('12345678901234567890'), isNull);
    });
  });
}
