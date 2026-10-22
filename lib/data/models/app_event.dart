/// Usage events logged on the device for the Power BI export (events.csv).
class AppEvent {
  const AppEvent({
    this.id,
    required this.type,
    this.meterId,
    this.value,
    this.detail,
    required this.createdAt,
  });

  static const String appOpen = 'app_open';
  static const String onboardingDone = 'onboarding_done';
  static const String meterAdded = 'meter_added';
  static const String readingAdded = 'reading_added';
  static const String billAdded = 'bill_added';
  static const String billScanned = 'bill_scanned';
  static const String slabWarning = 'slab_warning';
  static const String applianceAdded = 'appliance_added';
  static const String exportDone = 'export_done';
  static const String backupSaved = 'backup_saved';
  static const String backupRestored = 'backup_restored';

  final int? id;
  final String type;
  final int? meterId;
  final double? value;
  final String? detail;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'event_type': type,
        'meter_id': meterId,
        'value': value,
        'detail': detail,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory AppEvent.fromMap(Map<String, Object?> m) => AppEvent(
        id: m['id'] as int?,
        type: m['event_type'] as String,
        meterId: m['meter_id'] as int?,
        value: (m['value'] as num?)?.toDouble(),
        detail: m['detail'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
