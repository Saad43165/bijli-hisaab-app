class Appliance {
  const Appliance({
    this.id,
    required this.meterId,
    required this.name,
    required this.category,
    required this.watts,
    this.quantity = 1,
    required this.hoursPerDay,
    required this.createdAt,
  });

  final int? id;
  final int meterId;
  final String name;
  final String category;

  /// Average power while running, in watts.
  final int watts;
  final int quantity;
  final double hoursPerDay;
  final DateTime createdAt;

  /// kWh per day = W × qty × h / 1000
  double get dailyUnits => watts * quantity * hoursPerDay / 1000;

  /// Estimated units for a 30-day month.
  double get monthlyUnits => dailyUnits * 30;

  Appliance copyWith({
    int? id,
    String? name,
    String? category,
    int? watts,
    int? quantity,
    double? hoursPerDay,
  }) {
    return Appliance(
      id: id ?? this.id,
      meterId: meterId,
      name: name ?? this.name,
      category: category ?? this.category,
      watts: watts ?? this.watts,
      quantity: quantity ?? this.quantity,
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'meter_id': meterId,
        'name': name,
        'category': category,
        'watts': watts,
        'quantity': quantity,
        'hours_per_day': hoursPerDay,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory Appliance.fromMap(Map<String, Object?> m) => Appliance(
        id: m['id'] as int?,
        meterId: m['meter_id'] as int,
        name: m['name'] as String,
        category: (m['category'] as String?) ?? 'other',
        watts: (m['watts'] as num).toInt(),
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        hoursPerDay: (m['hours_per_day'] as num).toDouble(),
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
