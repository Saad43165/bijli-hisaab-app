import 'dart:convert';

/// A backup file's contents. Pure Dart: no database or files here, so the
/// format, validation and restore planning are unit-tested.
///
/// File format (JSON):
/// ```
/// {
///   "app": "bijli_bachao",
///   "format": 1,
///   "created_at": "2026-10-22T10:00:00.000",
///   "app_version": "1.0.0+1",
///   "kind": "manual" | "auto" | "before_restore",
///   "tables": { "meters": [...], "readings": [...], "bills": [...], "appliances": [...] },
///   "settings": { "active_meter_id": 1, "reminders_enabled": true, ... }
/// }
/// ```
/// Rows are the raw database rows. Meter ids are only used to link rows
/// inside the file; restore gives meters new ids.
class BackupData {
  const BackupData({
    required this.createdAt,
    required this.meters,
    required this.readings,
    required this.bills,
    required this.appliances,
    this.settings = const {},
    this.kind = BackupKind.manual,
    this.appVersion = '',
  });

  static const String appId = 'bijli_bachao';
  static const int formatVersion = 1;

  final DateTime createdAt;
  final BackupKind kind;
  final String appVersion;
  final List<Map<String, Object?>> meters;
  final List<Map<String, Object?>> readings;
  final List<Map<String, Object?>> bills;
  final List<Map<String, Object?>> appliances;
  final Map<String, Object?> settings;

  bool get isEmpty => meters.isEmpty;

  /// Columns kept for each table. Anything else in a file (e.g. from a newer
  /// app version) is ignored instead of breaking the insert.
  static const Map<String, Set<String>> columns = {
    'meters': {
      'id', 'name', 'disco', 'city', 'province', 'connection_type', 'phase',
      'sanctioned_load_kw', 'protected_setting', 'reading_day', 'created_at',
      'reference_no', 'meter_type',
    },
    'readings': {
      'id', 'meter_id', 'reading_date', 'reading_value', 'source', 'created_at',
      'peak_value', 'export_value',
    },
    'bills': {
      'id', 'meter_id', 'bill_month', 'units', 'amount_rs', 'due_date',
      'present_reading', 'source', 'created_at',
    },
    'appliances': {
      'id', 'meter_id', 'name', 'category', 'watts', 'quantity', 'hours_per_day', 'created_at',
    },
  };

  /// Settings that travel with a backup. Not included: install ID,
  /// analytics consent, cached rates, onboarding flags.
  static const Set<String> settingKeys = {
    'active_meter_id',
    'reminders_enabled',
    'slab_alerts_enabled',
    'auto_update_rates',
    'smart_scanner',
    'theme_mode',
    'simple_home',
    'language',
    'tariff_override_json',
    'reminder_reading_day',
    'reminder_slab',
    'reminder_due_date',
    'reminder_no_reading',
  };

  BackupSummary get summary => BackupSummary(
        createdAt: createdAt,
        kind: kind,
        meterNames: [for (final m in meters) '${m['name']}'],
        meters: meters.length,
        readings: readings.length,
        bills: bills.length,
        appliances: appliances.length,
      );

  Map<String, Object?> toJson() => {
        'app': appId,
        'format': formatVersion,
        'created_at': createdAt.toIso8601String(),
        'app_version': appVersion,
        'kind': kind.name,
        'tables': {
          'meters': meters,
          'readings': readings,
          'bills': bills,
          'appliances': appliances,
        },
        'settings': settings,
      };

  String encode() => const JsonEncoder.withIndent(' ').convert(toJson());

  /// Reads and checks a backup file. Throws [BackupFormatException] with a
  /// message the user can understand.
  static BackupData parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text.trim().replaceFirst('﻿', ''));
    } on FormatException {
      throw const BackupFormatException('This file isn\'t a Bijli Hisaab backup.');
    }
    if (json is! Map<String, Object?> || json['app'] != appId) {
      throw const BackupFormatException('This file isn\'t a Bijli Hisaab backup.');
    }
    final format = json['format'];
    if (format is! int || format < 1) {
      throw const BackupFormatException('This backup file is damaged.');
    }
    if (format > formatVersion) {
      throw const BackupFormatException('This backup was made by a newer version. Update the app and try again.');
    }
    final tables = json['tables'];
    if (tables is! Map<String, Object?>) {
      throw const BackupFormatException('This backup file is damaged.');
    }

    List<Map<String, Object?>> table(String name, bool Function(Map<String, Object?>) valid) {
      final raw = tables[name];
      if (raw == null) return [];
      if (raw is! List) throw const BackupFormatException('This backup file is damaged.');
      final keep = columns[name]!;
      final out = <Map<String, Object?>>[];
      for (final row in raw) {
        if (row is! Map<String, Object?>) continue;
        final clean = {for (final e in row.entries) if (keep.contains(e.key)) e.key: e.value};
        if (valid(clean)) out.add(clean);
      }
      return out;
    }

    bool str(Object? v) => v is String && v.trim().isNotEmpty;
    bool numb(Object? v) => v is num && v.isFinite;

    final meters = table('meters', (r) => r['id'] is int && str(r['name']) && str(r['disco']) && str(r['province']));
    final ids = {for (final m in meters) m['id'] as int};
    if (ids.length != meters.length) {
      throw const BackupFormatException('This backup file is damaged.');
    }
    final readings = table(
      'readings',
      (r) => ids.contains(r['meter_id']) && _isDate(r['reading_date']) && numb(r['reading_value']),
    );
    final bills = table(
      'bills',
      (r) => ids.contains(r['meter_id']) && _isMonth(r['bill_month']) && r['units'] is num,
    );
    final appliances = table(
      'appliances',
      (r) => ids.contains(r['meter_id']) && str(r['name']) && r['watts'] is num && numb(r['hours_per_day']),
    );

    final rawSettings = json['settings'];
    final rawKind = json['kind'];
    final settings = <String, Object?>{
      if (rawSettings is Map<String, Object?>)
        for (final e in rawSettings.entries)
          if (settingKeys.contains(e.key) && (e.value is bool || e.value is int || e.value is String)) e.key: e.value,
    };

    return BackupData(
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      kind: BackupKind.values.where((k) => k.name == rawKind).firstOrNull ?? BackupKind.manual,
      appVersion: '${json['app_version'] ?? ''}',
      meters: meters,
      readings: readings,
      bills: bills,
      appliances: appliances,
      settings: settings,
    );
  }

  static bool _isDate(Object? v) => v is String && DateTime.tryParse(v) != null;
  static bool _isMonth(Object? v) => v is String && RegExp(r'^\d{4}-\d{2}$').hasMatch(v);
}

enum BackupKind {
  /// Saved by the user.
  manual,

  /// Weekly automatic copy on the phone.
  auto,

  /// Taken just before a restore, so it can be undone.
  beforeRestore,

  /// Taken just before "Reset app", so it can be undone.
  beforeReset,
}

class BackupSummary {
  const BackupSummary({
    required this.createdAt,
    required this.kind,
    required this.meterNames,
    required this.meters,
    required this.readings,
    required this.bills,
    required this.appliances,
  });

  final DateTime createdAt;
  final BackupKind kind;
  final List<String> meterNames;
  final int meters;
  final int readings;
  final int bills;
  final int appliances;
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}
