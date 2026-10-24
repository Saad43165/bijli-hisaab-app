import 'dart:math' as math;

import '../core/constants/app_constants.dart';
import '../core/l10n/l10n.dart';
import '../core/utils/formatters.dart';
import '../data/models/appliance.dart';

/// One appliance line for a typical home: preset name, how many, hours a day.
typedef HomeItem = ({String name, int quantity, double hours});

/// A change that saves money, with the saving worked out.
class SavingIdea {
  const SavingIdea({required this.title, required this.body, required this.units, required this.rupees, this.applianceName});

  final String title;
  final String body;

  /// Units saved a month.
  final double units;

  /// Rupees saved a month (at the user's marginal rate).
  final double rupees;
  final String? applianceName;
}

/// Builds a realistic appliance list from the bill and finds the biggest
/// savings. Pure, so it's unit-tested.
class AppliancePlanner {
  AppliancePlanner._();

  /// A typical Pakistani home whose appliances add up to about
  /// [monthlyUnits]. Big users (AC) are added for larger bills, then hours
  /// of the flexible items are scaled so the total matches.
  static List<HomeItem> typicalHome(int monthlyUnits) {
    final u = monthlyUnits.clamp(60, 1500);
    final items = <HomeItem>[
      (name: 'Ceiling fan', quantity: u < 120 ? 2 : (u < 300 ? 3 : 4), hours: 10),
      (name: 'LED bulb', quantity: u < 120 ? 4 : 6, hours: 6),
      (name: 'Refrigerator', quantity: 1, hours: 24),
      (name: 'LED TV', quantity: 1, hours: 4),
      (name: 'Iron', quantity: 1, hours: 0.4),
      (name: 'Washing machine', quantity: 1, hours: 0.4),
      (name: 'Water motor (1 HP)', quantity: 1, hours: 0.7),
      (name: 'Wi-Fi router', quantity: 1, hours: 24),
      (name: 'Phone charger', quantity: 3, hours: 3),
      if (u >= 180) (name: 'UPS charging', quantity: 1, hours: 3),
      if (u >= 250) (name: 'AC 1.5 ton (inverter)', quantity: u >= 500 ? 2 : 1, hours: 5),
    ];
    // Fixed (always-on) vs flexible (scaled to match the bill).
    const flexible = {'Ceiling fan', 'LED bulb', 'LED TV', 'AC 1.5 ton (inverter)'};
    double units(Iterable<HomeItem> list) => list.fold(0.0, (s, i) {
          final p = ApplianceCatalog.preset(i.name);
          return p == null ? s : s + p.watts * i.quantity * i.hours * 30 / 1000;
        });
    var fixed = units(items.where((i) => !flexible.contains(i.name)));
    final flex = units(items.where((i) => flexible.contains(i.name)));
    // Small bills: the always-on things get less time too (an older, smaller
    // fridge, fewer motor runs), leaving room for fans and lights.
    final fixedFactor = fixed > u * 0.65 ? u * 0.65 / fixed : 1.0;
    fixed *= fixedFactor;
    final factor = flex <= 0 ? 1.0 : ((u - fixed) / flex).clamp(0.3, 2.4);
    return [
      for (final i in items)
        flexible.contains(i.name)
            ? (name: i.name, quantity: i.quantity, hours: _round(math.min(i.hours * factor, i.name == 'LED bulb' ? 12 : 20)))
            : (name: i.name, quantity: i.quantity, hours: _round1(i.hours * fixedFactor)),
    ];
  }

  static double _round(double h) => math.max(0.5, (h * 2).round() / 2);
  static double _round1(double h) => math.max(0.1, (h * 10).round() / 10);

  /// The biggest money-savers for these appliances, best first.
  static List<SavingIdea> savings(List<Appliance> list, double rate, {int max = 4}) {
    final ideas = <SavingIdea>[];
    double rs(double units) => units * rate;

    for (final a in list) {
      final n = a.name.toLowerCase();
      final perHour = a.watts * a.quantity * 30 / 1000; // units a month per daily hour

      if (n.contains('ac') && n.contains('non-inverter')) {
        final save = a.monthlyUnits * 0.45;
        ideas.add(SavingIdea(
          applianceName: a.name,
          title: 'Switch to an inverter AC'.tr,
          body: 'An inverter AC uses about half: roughly {0} less, {1} a month.'.trf({'0': Fmt.units(save), '1': Fmt.rs(rs(save))}),
          units: save,
          rupees: rs(save),
        ));
      }
      if (n.startsWith('ac') && a.hoursPerDay >= 2) {
        final save = a.monthlyUnits * 0.10 + perHour;
        ideas.add(SavingIdea(
          applianceName: a.name,
          title: 'AC at 26°C, 1 hour less a day'.tr,
          body: 'With a fan on, 26°C feels the same. Together with 1 hour less a day: about {0}, {1} a month.'
              .trf({'0': Fmt.units(save), '1': Fmt.rs(rs(save))}),
          units: save,
          rupees: rs(save),
        ));
      }
      if (n == 'ceiling fan' && a.hoursPerDay >= 4) {
        final save = (a.watts - 35) * a.quantity * a.hoursPerDay * 30 / 1000;
        if (save > 5) {
          ideas.add(SavingIdea(
            applianceName: a.name,
            title: 'DC inverter fans'.tr,
            body: '{0} DC fans use less than half the power: about {1}, {2} a month.'
                .trf({'0': a.quantity, '1': Fmt.units(save), '2': Fmt.rs(rs(save))}),
            units: save,
            rupees: rs(save),
          ));
        }
      }
      if ((n == 'tube light' || n == 'energy saver bulb') && a.hoursPerDay >= 2) {
        final led = n == 'tube light' ? 18 : 12;
        final save = (a.watts - led) * a.quantity * a.hoursPerDay * 30 / 1000;
        ideas.add(SavingIdea(
          applianceName: a.name,
          title: 'Change to LED'.tr,
          body: 'LEDs give the same light for about half the power: {0}, {1} a month.'
              .trf({'0': Fmt.units(save), '1': Fmt.rs(rs(save))}),
          units: save,
          rupees: rs(save),
        ));
      }
      if (n.contains('geyser') && a.hoursPerDay >= 0.5) {
        final save = a.monthlyUnits * 0.5;
        ideas.add(SavingIdea(
          applianceName: a.name,
          title: 'Use the geyser half as long'.tr,
          body: 'Heat water once, just before use, and switch it off: about {0}, {1} a month.'
              .trf({'0': Fmt.units(save), '1': Fmt.rs(rs(save))}),
          units: save,
          rupees: rs(save),
        ));
      }
      if ((n.contains('motor') || n.contains('heater')) && a.hoursPerDay >= 1) {
        final save = a.monthlyUnits * 0.3;
        ideas.add(SavingIdea(
          applianceName: a.name,
          title: '{0}: run it less'.trf({'0': a.name.tr}),
          body: 'A third less time saves about {0}, {1} a month.'.trf({'0': Fmt.units(save), '1': Fmt.rs(rs(save))}),
          units: save,
          rupees: rs(save),
        ));
      }
    }
    ideas.sort((a, b) => b.rupees.compareTo(a.rupees));
    return ideas.where((i) => i.units >= 3).take(max).toList();
  }
}
