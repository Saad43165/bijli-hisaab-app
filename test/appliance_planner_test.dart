import 'package:bijli_bachao/core/constants/app_constants.dart';
import 'package:bijli_bachao/data/models/appliance.dart';
import 'package:bijli_bachao/services/appliance_planner.dart';
import 'package:flutter_test/flutter_test.dart';

double unitsOf(List<HomeItem> items) => items.fold(0.0, (s, i) {
      final p = ApplianceCatalog.preset(i.name)!;
      return s + p.watts * i.quantity * i.hours * 30 / 1000;
    });

Appliance a(String name, int watts, double hours, {int qty = 1}) =>
    Appliance(meterId: 1, name: name, category: 'other', watts: watts, quantity: qty, hoursPerDay: hours, createdAt: DateTime(2026));

void main() {
  test('typical home adds up close to the bill', () {
    for (final target in [90, 160, 260, 400, 650]) {
      final home = AppliancePlanner.typicalHome(target);
      final u = unitsOf(home);
      expect(u, closeTo(target, target * 0.2), reason: 'target $target got $u');
      expect(home.every((i) => ApplianceCatalog.preset(i.name) != null), isTrue);
    }
    expect(AppliancePlanner.typicalHome(120).any((i) => i.name.startsWith('AC')), isFalse);
    expect(AppliancePlanner.typicalHome(400).any((i) => i.name.startsWith('AC')), isTrue);
  });

  test('savings rank the biggest rupee wins first', () {
    final ideas = AppliancePlanner.savings([
      a('AC 1.5 ton (non-inverter)', 1700, 8),
      a('Ceiling fan', 75, 14, qty: 4),
      a('LED bulb', 12, 7, qty: 6),
    ], 40);
    expect(ideas.first.title, contains('inverter AC'));
    expect(ideas.any((i) => i.title.contains('DC')), isTrue);
    expect(ideas.every((i) => i.rupees > 0), isTrue);
    for (var i = 1; i < ideas.length; i++) {
      expect(ideas[i - 1].rupees >= ideas[i].rupees, isTrue);
    }
  });
}
