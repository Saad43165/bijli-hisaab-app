import 'package:bijli_bachao/services/bill_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = BillTextParser();
  final now = DateTime(2026, 10, 21);

  test('reads a typical WAPDA DISCO bill', () {
    const text = '''
LAHORE ELECTRIC SUPPLY COMPANY
LESCO
REFERENCE NO 12 11234 1234567
BILL MONTH  SEP 26
READING DATE 10-SEP-26
DUE DATE 22-SEP-26
PRESENT READING  PREVIOUS READING
12450  12236
UNITS CONSUMED 214
PAYABLE WITHIN DUE DATE 8,420
''';
    final p = parser.parse(text, now: now);
    expect(p.disco, 'LESCO');
    expect(p.month, '2026-09');
    expect(p.units, 214);
    expect(p.amount, 8420);
    expect(p.dueDate, DateTime(2026, 9, 22));
    expect(p.presentReading, 12450);
  });

  test('label and value on separate lines', () {
    const text = '''
IESCO
UNITS CONSUMED
187
AMOUNT PAYABLE WITHIN DUE DATE
5,912
DUE DATE
15/10/2026
''';
    final p = parser.parse(text, now: now);
    expect(p.disco, 'IESCO');
    expect(p.units, 187);
    expect(p.amount, 5912);
    expect(p.dueDate, DateTime(2026, 10, 15));
    // No bill month printed: derived from due date (month before).
    expect(p.month, '2026-09');
  });

  test('reads a K-Electric bill', () {
    const text = '''
K-ELECTRIC
ACCOUNT NO 0400012345678
BILL MONTH OCT 2026
UNITS BILLED 312
AMOUNT PAYABLE 14,630
DUE DATE 24-OCT-2026
''';
    final p = parser.parse(text, now: now);
    expect(p.disco, 'K-Electric');
    expect(p.units, 312);
    expect(p.amount, 14630);
    expect(p.month, '2026-10');
    expect(p.dueDate, DateTime(2026, 10, 24));
  });

  test('detects company from its full name', () {
    final p = parser.parse('MULTAN ELECTRIC POWER COMPANY\nUNITS CONSUMED 98', now: now);
    expect(p.disco, 'MEPCO');
    expect(p.units, 98);
  });

  test('units from present - previous when not printed', () {
    const text = '''
PRESENT READING 5320
PREVIOUS READING 5110
''';
    final p = parser.parse(text, now: now);
    expect(p.units, 210);
  });

  test('empty text detects nothing', () {
    final p = parser.parse('', now: now);
    expect(p.isEmpty, isTrue);
  });
}
