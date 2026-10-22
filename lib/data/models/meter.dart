import '../../core/l10n/l10n.dart';

/// How we decide whether a meter is billed at protected rates.
enum ProtectedSetting {
  /// User says their bill shows "Protected".
  protected,

  /// User says their bill is not protected.
  unprotected,

  /// Work it out from the last 6 bills (≤ 200 units each).
  auto,

  /// Lifeline: single-phase, sanctioned load up to 1 kW, ≤ 100 units.
  lifeline;

  static ProtectedSetting fromName(String? name) => ProtectedSetting.values
      .firstWhere((e) => e.name == name, orElse: () => ProtectedSetting.auto);

  String get label => switch (this) {
        ProtectedSetting.protected => 'Protected',
        ProtectedSetting.unprotected => 'Not protected',
        ProtectedSetting.auto => 'Not sure (auto)',
        ProtectedSetting.lifeline => 'Lifeline',
      }.tr;
}

/// What the meter measures.
enum MeterType {
  /// One kWh register.
  standard,

  /// Time of use: separate peak and off-peak registers.
  tou,

  /// Solar, agreement signed before Feb 2026: exports are netted against
  /// imports and only the net units are billed.
  netMetering,

  /// Solar, newer agreement (net billing): imports billed at normal rates,
  /// exports bought back at a lower rate.
  netBilling;

  bool get isSolar => this == netMetering || this == netBilling;

  static MeterType fromName(String? name) =>
      MeterType.values.firstWhere((e) => e.name == name, orElse: () => MeterType.standard);

  String get label => switch (this) {
        MeterType.standard => 'Normal',
        MeterType.tou => 'Peak / off-peak',
        MeterType.netMetering => 'Solar · net metering',
        MeterType.netBilling => 'Solar · net billing',
      }.tr;
}

class Meter {
  const Meter({
    this.id,
    required this.name,
    required this.disco,
    required this.city,
    required this.province,
    required this.connectionType,
    required this.phase,
    required this.sanctionedLoadKw,
    required this.protectedSetting,
    required this.readingDay,
    required this.createdAt,
    this.referenceNo = '',
    this.meterType = MeterType.standard,
  });

  final int? id;
  final String name;
  final String disco;
  final String city;
  final String province;

  /// home | shop | other
  final String connectionType;

  /// single | three
  final String phase;
  final double sanctionedLoadKw;
  final ProtectedSetting protectedSetting;

  /// Day of the month the meter reader comes (1–31).
  final int readingDay;
  final DateTime createdAt;

  /// Reference / account number printed on the bill ('' when unknown).
  final String referenceNo;
  final MeterType meterType;

  Meter copyWith({
    int? id,
    String? name,
    String? disco,
    String? city,
    String? province,
    String? connectionType,
    String? phase,
    double? sanctionedLoadKw,
    ProtectedSetting? protectedSetting,
    int? readingDay,
    DateTime? createdAt,
    String? referenceNo,
    MeterType? meterType,
  }) {
    return Meter(
      id: id ?? this.id,
      name: name ?? this.name,
      disco: disco ?? this.disco,
      city: city ?? this.city,
      province: province ?? this.province,
      connectionType: connectionType ?? this.connectionType,
      phase: phase ?? this.phase,
      sanctionedLoadKw: sanctionedLoadKw ?? this.sanctionedLoadKw,
      protectedSetting: protectedSetting ?? this.protectedSetting,
      readingDay: readingDay ?? this.readingDay,
      createdAt: createdAt ?? this.createdAt,
      referenceNo: referenceNo ?? this.referenceNo,
      meterType: meterType ?? this.meterType,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'disco': disco,
        'city': city,
        'province': province,
        'connection_type': connectionType,
        'phase': phase,
        'sanctioned_load_kw': sanctionedLoadKw,
        'protected_setting': protectedSetting.name,
        'reading_day': readingDay,
        'created_at': createdAt.toUtc().toIso8601String(),
        'reference_no': referenceNo,
        'meter_type': meterType.name,
      };

  factory Meter.fromMap(Map<String, Object?> m) => Meter(
        id: m['id'] as int?,
        name: m['name'] as String,
        disco: m['disco'] as String,
        city: (m['city'] as String?) ?? '',
        province: (m['province'] as String?) ?? 'Punjab',
        connectionType: (m['connection_type'] as String?) ?? 'home',
        phase: (m['phase'] as String?) ?? 'single',
        sanctionedLoadKw: (m['sanctioned_load_kw'] as num?)?.toDouble() ?? 1,
        protectedSetting: ProtectedSetting.fromName(m['protected_setting'] as String?),
        readingDay: (m['reading_day'] as int?) ?? 1,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        referenceNo: (m['reference_no'] as String?) ?? '',
        meterType: MeterType.fromName(m['meter_type'] as String?),
      );
}
