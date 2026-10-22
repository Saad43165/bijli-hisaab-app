import '../../core/utils/formatters.dart';

class MeterReading {
  const MeterReading({
    this.id,
    required this.meterId,
    required this.date,
    required this.value,
    this.source = 'manual',
    required this.createdAt,
    this.peakValue,
    this.exportValue,
  });

  final int? id;
  final int meterId;

  /// Calendar date of the reading (time is ignored).
  final DateTime date;

  /// Units drawn from the grid, in kWh: the meter display for a normal
  /// meter, off-peak + peak for a TOU meter, the import register for a
  /// net-metering meter. Everything (units, forecast, slabs) works on this.
  final double value;

  /// manual | bill | photo
  final String source;
  final DateTime createdAt;

  /// TOU meters: the peak-hours register (off-peak = [value] − this).
  final double? peakValue;

  /// Net-metering meters: units sent to the grid (export register).
  final double? exportValue;

  /// TOU meters: the off-peak register.
  double? get offPeakValue => peakValue == null ? null : value - peakValue!;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'meter_id': meterId,
        'reading_date': Fmt.isoDate(date),
        'reading_value': value,
        'source': source,
        'created_at': createdAt.toUtc().toIso8601String(),
        'peak_value': peakValue,
        'export_value': exportValue,
      };

  factory MeterReading.fromMap(Map<String, Object?> m) => MeterReading(
        id: m['id'] as int?,
        meterId: m['meter_id'] as int,
        date: DateTime.parse(m['reading_date'] as String),
        value: (m['reading_value'] as num).toDouble(),
        source: (m['source'] as String?) ?? 'manual',
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        peakValue: (m['peak_value'] as num?)?.toDouble(),
        exportValue: (m['export_value'] as num?)?.toDouble(),
      );
}
