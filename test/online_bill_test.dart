import 'dart:io';

import 'package:bijli_bachao/services/online_bill_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Text of a real IESCO bill page, with personal details replaced.
  final text = File('test/fixtures/pitc_bill_page.txt').readAsStringSync();

  test('reads the current bill', () {
    final b = OnlineBillParser.parse(text)!;
    expect(b.reference, '01234567890123');
    expect(b.month, DateTime(2026, 10));
    expect(b.units, 91);
    expect(b.amount, 3937);
    expect(b.amountAfterDue, 4084);
    expect(b.dueDate, DateTime(2026, 11, 2));
    expect(b.readingDate, DateTime(2026, 10, 18));
    expect(b.presentReading, 38209);
    expect(b.previousReading, 38118);
    expect(b.sanctionedLoadKw, 2);
    expect(b.protectedCategory, isFalse);
  });

  test('reads 12 months of history, oldest first', () {
    final h = OnlineBillParser.parse(text)!.history;
    expect(h.length, 12);
    expect(h.first.month, DateTime(2025, 10));
    expect(h.first.units, 284);
    expect(h.first.bill, 11736);
    expect(h.last.month, DateTime(2026, 9));
    expect(h.last.units, 261);
    expect(h.firstWhere((m) => m.month == DateTime(2026, 2)).paid, 6841);
  });

  test('page without a bill gives null', () {
    expect(OnlineBillParser.parse('IESCO Web Bill\nGiven Ref/App No is invalid'), isNull);
  });

  test('HTML to text keeps one item per line', () {
    expect(
      OnlineBillService.htmlToText('<div>UNITS</div><script>x()</script><p> 91 </p>&#9888; DUE'),
      'UNITS\n91\n⚠ DUE',
    );
  });
}
