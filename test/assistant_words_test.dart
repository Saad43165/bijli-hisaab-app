import 'package:bijli_bachao/features/assistant/assistant_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('everyday appliance words map to the catalogue', () {
    expect(AssistantTools.applianceNamed(' 2 ac'), 'AC 1.5 ton (inverter)');
    expect(AssistantTools.applianceNamed('one non inverter ac'), 'AC 1.5 ton (non-inverter)');
    expect(AssistantTools.applianceNamed('5 fans'), 'Ceiling fan');
    expect(AssistantTools.applianceNamed('ek motor'), 'Water motor (1 HP)');
    expect(AssistantTools.applianceNamed('Refrigerator'), 'Refrigerator');
    expect(AssistantTools.applianceNamed('3 پنکھے'), 'Ceiling fan');
    expect(AssistantTools.applianceNamed('my car'), isNull);
  });
}
