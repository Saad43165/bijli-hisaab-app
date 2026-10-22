import 'package:bijli_bachao/core/constants/cities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cities belong to the company that serves them', () {
    expect(Cities.companyOf('chakwal'), 'IESCO');
    expect(Cities.companyOf(' Lahore '), 'LESCO');
    expect(Cities.companyOf('Peshawar'), 'PESCO');
    expect(Cities.companyOf('Karachi'), 'K-Electric');
    expect(Cities.companyOf('Some village'), isNull);
  });

  test('suggestions only show the chosen company\'s cities', () {
    final pesco = Cities.suggest('', company: 'PESCO', limit: 100);
    expect(pesco, contains('Peshawar'));
    expect(pesco, isNot(contains('Lahore')));
    expect(Cities.suggest('la', company: 'PESCO'), isNot(contains('Lahore')));
    expect(Cities.suggest('la', company: 'LESCO'), contains('Lahore'));
  });

  test('province always fits the company', () {
    expect(Cities.provincesFor('PESCO'), ['KP']);
    expect(Cities.provincesFor('IESCO'), containsAll(['Punjab', 'ICT']));
    expect(Cities.provinceFor('IESCO', 'Chakwal'), 'Punjab');
    expect(Cities.provinceFor('IESCO', 'Islamabad'), 'ICT');
    // A Punjab city typed under PESCO doesn't make the province Punjab.
    expect(Cities.provinceFor('PESCO', 'Lahore'), 'KP');
    expect(Cities.provinceFor('K-Electric', 'Hub'), 'Balochistan');
  });
}
