/// Static reference data used across the app.
class AppConstants {
  AppConstants._();

  static const String appName = 'Bijli Hisaab';
  static const String appNameUrdu = 'بجلی حساب';
  static const String tariffAsset = 'assets/config/tariff_pk.json';

  static const List<String> provinces = [
    'Punjab',
    'Sindh',
    'KP',
    'Balochistan',
    'ICT',
    'AJK',
    'GB',
  ];

  static const List<String> connectionTypes = ['home', 'shop', 'other'];

  static const Map<String, String> connectionTypeLabels = {
    'home': 'Home',
    'shop': 'Shop',
    'other': 'Other',
  };

  /// Upper limit (inclusive) of each slab band, used for chart colours and export.
  static const List<int> slabBandLimits = [100, 200, 300, 400, 500, 600, 700];

  static String slabBand(int units) {
    if (units <= 0) return '0';
    var lower = 1;
    for (final limit in slabBandLimits) {
      if (units <= limit) return '$lower-$limit';
      lower = limit + 1;
    }
    return '700+';
  }
}

/// A ready-made appliance users can pick. [watts] is the realistic *average*
/// draw while running (e.g. an inverter AC rarely runs at full rated power).
class AppliancePreset {
  const AppliancePreset({
    required this.name,
    required this.category,
    required this.watts,
    required this.hoursPerDay,
  });

  final String name;
  final String category;
  final int watts;
  final double hoursPerDay;
}

class ApplianceCatalog {
  ApplianceCatalog._();

  static const List<String> categories = [
    'cooling',
    'heating',
    'kitchen',
    'laundry',
    'lighting',
    'entertainment',
    'pump',
    'other',
  ];

  static const Map<String, String> categoryLabels = {
    'cooling': 'Cooling',
    'heating': 'Heating',
    'kitchen': 'Kitchen',
    'laundry': 'Laundry',
    'lighting': 'Lighting',
    'entertainment': 'TV & devices',
    'pump': 'Water pump',
    'other': 'Other',
  };

  static const List<AppliancePreset> presets = [
    AppliancePreset(name: 'AC 1.5 ton (inverter)', category: 'cooling', watts: 900, hoursPerDay: 8),
    AppliancePreset(name: 'AC 1.5 ton (non-inverter)', category: 'cooling', watts: 1700, hoursPerDay: 8),
    AppliancePreset(name: 'AC 1 ton (inverter)', category: 'cooling', watts: 650, hoursPerDay: 8),
    AppliancePreset(name: 'Ceiling fan', category: 'cooling', watts: 75, hoursPerDay: 14),
    AppliancePreset(name: 'Ceiling fan (DC inverter)', category: 'cooling', watts: 35, hoursPerDay: 14),
    AppliancePreset(name: 'Air cooler', category: 'cooling', watts: 200, hoursPerDay: 10),
    AppliancePreset(name: 'Refrigerator', category: 'kitchen', watts: 120, hoursPerDay: 24),
    AppliancePreset(name: 'Deep freezer', category: 'kitchen', watts: 160, hoursPerDay: 24),
    AppliancePreset(name: 'Microwave oven', category: 'kitchen', watts: 1200, hoursPerDay: 0.3),
    AppliancePreset(name: 'Electric kettle', category: 'kitchen', watts: 1500, hoursPerDay: 0.2),
    AppliancePreset(name: 'Iron', category: 'laundry', watts: 1000, hoursPerDay: 0.5),
    AppliancePreset(name: 'Washing machine', category: 'laundry', watts: 400, hoursPerDay: 0.7),
    AppliancePreset(name: 'LED bulb', category: 'lighting', watts: 12, hoursPerDay: 7),
    AppliancePreset(name: 'Tube light', category: 'lighting', watts: 40, hoursPerDay: 7),
    AppliancePreset(name: 'LED TV', category: 'entertainment', watts: 80, hoursPerDay: 5),
    AppliancePreset(name: 'Desktop PC', category: 'entertainment', watts: 200, hoursPerDay: 5),
    AppliancePreset(name: 'Laptop', category: 'entertainment', watts: 60, hoursPerDay: 6),
    AppliancePreset(name: 'Wi-Fi router', category: 'entertainment', watts: 10, hoursPerDay: 24),
    AppliancePreset(name: 'Water motor (1 HP)', category: 'pump', watts: 750, hoursPerDay: 1),
    AppliancePreset(name: 'Electric geyser', category: 'heating', watts: 2000, hoursPerDay: 1),
    AppliancePreset(name: 'Room heater', category: 'heating', watts: 1500, hoursPerDay: 3),
    AppliancePreset(name: 'UPS charging', category: 'other', watts: 150, hoursPerDay: 4),
    AppliancePreset(name: 'Energy saver bulb', category: 'lighting', watts: 24, hoursPerDay: 7),
    AppliancePreset(name: 'Water dispenser', category: 'kitchen', watts: 100, hoursPerDay: 24),
    AppliancePreset(name: 'Hair dryer', category: 'other', watts: 1200, hoursPerDay: 0.2),
    AppliancePreset(name: 'Phone charger', category: 'entertainment', watts: 15, hoursPerDay: 3),
    AppliancePreset(name: 'Electric oven', category: 'kitchen', watts: 1800, hoursPerDay: 0.5),
  ];

  /// The usual things in a Pakistani home, for quick setup.
  static const List<String> quickSetup = [
    'Ceiling fan',
    'LED bulb',
    'Refrigerator',
    'AC 1.5 ton (inverter)',
    'AC 1.5 ton (non-inverter)',
    'Air cooler',
    'Water motor (1 HP)',
    'LED TV',
    'Iron',
    'Washing machine',
    'Wi-Fi router',
    'UPS charging',
  ];

  static AppliancePreset? preset(String name) {
    for (final p in presets) {
      if (p.name == name) return p;
    }
    return null;
  }
}
