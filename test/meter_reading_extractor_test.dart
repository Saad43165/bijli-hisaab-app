import 'package:bijli_bachao/services/bill_scan_analyzer.dart';
import 'package:bijli_bachao/services/meter_reading_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

OcrLine l(String t, double x1, double y1, double x2, double y2) => OcrLine(t, OcrBox(x1, y1, x2, y2));

/// A digital meter face, 1000×1400 photo: brand at the top, the big
/// reading in the middle, serial number and ratings below.
List<OcrLine> meterFace({String reading = '12450'}) => [
      l('MICROTECH', 380, 200, 620, 240),
      l('SINGLE PHASE STATIC METER', 300, 260, 700, 290),
      l(reading, 330, 650, 640, 740),
      l('kWh', 660, 690, 720, 730),
      l('METER NO. 2104567', 320, 900, 680, 930),
      l('230V 10-40A 50Hz', 330, 950, 670, 980),
      l('1600 imp/kWh', 400, 1000, 600, 1030),
      l('2021', 460, 1060, 540, 1090),
    ];

void main() {
  const x = MeterReadingExtractor();

  test('picks the big number in the middle, not the serial or ratings', () {
    final r = x.extract(meterFace(), imageWidth: 1000, imageHeight: 1400);
    expect(r.best?.value, 12450);
    expect(r.candidates.map((c) => c.value), isNot(contains(2104567)));
    expect(r.candidates.map((c) => c.value), isNot(contains(1600)));
  });

  test('last reading makes it sure', () {
    final r = x.extract(meterFace(), lastReading: 12236, daysSinceLast: 20, imageWidth: 1000, imageHeight: 1400);
    expect(r.best?.value, 12450);
    expect(r.confidence, FieldConfidence.high);
  });

  test('a number lower than the last reading loses to a plausible one', () {
    final lines = [
      ...meterFace(reading: '11999'),
      l('12301', 420, 1150, 580, 1190), // smaller text lower down
    ];
    final r = x.extract(lines, lastReading: 12236, daysSinceLast: 10, imageWidth: 1000, imageHeight: 1400);
    expect(r.best?.value, 12301);
    expect(r.candidates.map((c) => c.value), contains(11999));
  });

  test('letter/digit swaps are fixed', () {
    final r = x.extract(meterFace(reading: '1245O'), lastReading: 12400, imageWidth: 1000, imageHeight: 1400);
    expect(r.best?.value, 12450);
  });

  test('digits split into separate pieces are joined', () {
    final lines = [
      l('MICROTECH', 380, 200, 620, 240),
      l('124', 330, 650, 520, 740),
      l('50', 540, 650, 640, 740),
    ];
    final r = x.extract(lines, lastReading: 12400, imageWidth: 1000, imageHeight: 1400);
    expect(r.best?.value, 12450);
  });

  test('spaced-out digits on one line are joined', () {
    final r = x.extract(meterFace(reading: '1 2 4 5 0'), imageWidth: 1000, imageHeight: 1400);
    expect(r.best?.value, 12450);
  });

  test('decimal digits are dropped', () {
    final r = x.extract(meterFace(reading: '12450.6'), imageWidth: 1000, imageHeight: 1400);
    expect(r.best?.value, 12450);
  });

  test('nothing usable gives an empty result', () {
    final r = x.extract([l('MICROTECH', 380, 200, 620, 240), l('kWh', 660, 690, 720, 730)]);
    expect(r.isEmpty, isTrue);
    expect(r.confidence, FieldConfidence.low);
  });

  test('at most three distinct suggestions', () {
    final lines = [
      ...meterFace(),
      l('12450', 330, 760, 640, 800),
      l('34567', 100, 100, 200, 130),
      l('45678', 100, 1300, 200, 1330),
      l('56789', 800, 1300, 900, 1330),
    ];
    final r = x.extract(lines, imageWidth: 1000, imageHeight: 1400);
    expect(r.candidates.length, lessThanOrEqualTo(3));
    expect(r.candidates.map((c) => c.value).toSet().length, r.candidates.length);
  });
}
