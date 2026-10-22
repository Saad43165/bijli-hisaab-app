import 'package:bijli_bachao/services/bill_scan_analyzer.dart';
import 'package:bijli_bachao/services/bill_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectCompany', () {
    test('full name wins over a misread short code', () {
      // OCR read "IESCO" as "LESCO", but the full name says Islamabad.
      expect(
        BillValues.detectCompany('LESCO\nISLAMABAD ELECTRIC SUPPLY COMPANY\nELECTRICITY CONSUMER BILL'),
        'IESCO',
      );
    });

    test('city names settle IESCO vs LESCO when the name is unreadable', () {
      expect(BillValues.detectCompany('LESCO  CONSUMER BILL\nDISTT CHAKWAL  SUB DIV RAWALPINDI ROAD'), 'IESCO');
      expect(BillValues.detectCompany('IESCO BILL\nLAHORE CANTT  KASUR ROAD'), 'LESCO');
    });

    test('website and OCR variants count', () {
      expect(BillValues.detectCompany('WWW.IESCO.COM.PK'), 'IESCO');
      expect(BillValues.detectCompany('1ESC0 CONSUMER BILL'), 'IESCO');
    });

    test('plain codes and names still work', () {
      expect(BillValues.detectCompany('LAHORE ELECTRIC SUPPLY COMPANY'), 'LESCO');
      expect(BillValues.detectCompany('PESCO WAPDA BILL'), 'PESCO');
      expect(BillValues.detectCompany('K-ELECTRIC'), 'K-Electric');
      expect(BillValues.detectCompany('SOME RANDOM TEXT'), isNull);
    });
  });

  test('bill month is taken from under its own heading', () {
    OcrLine l(String t, double x1, double y1, double x2, double y2) => OcrLine(t, OcrBox(x1, y1, x2, y2));
    final a = const BillScanAnalyzer().analyze([
      l('CONNECTION DATE', 10, 60, 110, 76),
      l('BILL MONTH', 230, 60, 310, 76),
      l('READING DATE', 320, 60, 410, 76),
      // OCR joined the row: the connection date "MAY 07" comes first.
      l('21 MAY 07          OCT 26      18 OCT 26', 20, 82, 410, 98),
    ], now: DateTime(2026, 10, 22));
    expect(a.month?.value, '2026-10');
  });
}
