import '../../core/utils/formatters.dart';

class Bill {
  const Bill({
    this.id,
    required this.meterId,
    required this.month,
    required this.units,
    this.amount = 0,
    this.dueDate,
    this.presentReading,
    this.source = 'manual',
    required this.createdAt,
  });

  final int? id;
  final int meterId;

  /// Bill month as "YYYY-MM".
  final String month;
  final int units;

  /// Amount payable within due date, in rupees. 0 when unknown.
  final double amount;
  final DateTime? dueDate;

  /// Present reading printed on the bill, if known.
  final double? presentReading;

  /// scan | manual | history
  final String source;
  final DateTime createdAt;

  DateTime get monthDate => Fmt.parseMonthKey(month);

  Bill copyWith({
    int? id,
    String? month,
    int? units,
    double? amount,
    DateTime? dueDate,
    double? presentReading,
    String? source,
  }) {
    return Bill(
      id: id ?? this.id,
      meterId: meterId,
      month: month ?? this.month,
      units: units ?? this.units,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      presentReading: presentReading ?? this.presentReading,
      source: source ?? this.source,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'meter_id': meterId,
        'bill_month': month,
        'units': units,
        'amount_rs': amount,
        'due_date': dueDate == null ? null : Fmt.isoDate(dueDate!),
        'present_reading': presentReading,
        'source': source,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory Bill.fromMap(Map<String, Object?> m) => Bill(
        id: m['id'] as int?,
        meterId: m['meter_id'] as int,
        month: m['bill_month'] as String,
        units: (m['units'] as num).toInt(),
        amount: (m['amount_rs'] as num?)?.toDouble() ?? 0,
        dueDate: m['due_date'] == null ? null : DateTime.parse(m['due_date'] as String),
        presentReading: (m['present_reading'] as num?)?.toDouble(),
        source: (m['source'] as String?) ?? 'manual',
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
