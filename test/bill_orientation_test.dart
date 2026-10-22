import 'package:bijli_bachao/services/bill_ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upright bill text scores high', () {
    final score = BillOcrService.orientationScore(const [
      'ISLAMABAD ELECTRIC SUPPLY COMPANY',
      'ELECTRICITY CONSUMER BILL',
      'REFERENCE NO 06 14562 1211000 R',
      'UNITS CONSUMED 91',
      'PAYABLE WITHIN DUE DATE 4084',
      'PRESENT READING 38200',
    ]);
    expect(score, greaterThanOrEqualTo(6));
  });

  test('upside-down OCR gibberish scores low', () {
    final score = BillOcrService.orientationScore(const [
      'ANVdWOO ATddNS OIdLOAꞀƎ',
      'llIq ɹǝɯnsuoɔ',
      '9ㄥ 0ㄥㄣ8 ɹ 000l l2l',
      'pǝɯnsuoɔ sʇᴉun',
    ]);
    expect(score, lessThan(6));
  });
}
