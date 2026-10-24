import 'package:bijli_bachao/features/assistant/cloud_brain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Roman Urdu becomes useful English search words', () {
    final q = CloudBrain.searchQuery('punjab m bill zyadfa aty ya kpk m');
    expect(q, contains('higher'));
    expect(q, contains('Khyber Pakhtunkhwa'));
    expect(q, contains('electricity bill'));
    expect(q, isNot(contains(' aty')));
    expect(q, endsWith('Pakistan'));
  });

  test('English stays readable and gets context', () {
    expect(CloudBrain.searchQuery('FCA for November'), 'FCA for November Pakistan');
  });
}
