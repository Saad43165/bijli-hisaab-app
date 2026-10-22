import 'backup_data.dart';

enum RestoreMode {
  /// Delete everything on this phone, then load the backup.
  replace,

  /// Keep what's on this phone and add what's missing from the backup.
  merge,
}

/// What a restore will write. Built in pure Dart from the backup and (for
/// merge) the data already on the phone; [BackupService] then applies it in
/// one database transaction.
class RestorePlan {
  RestorePlan._({
    required this.mode,
    required this.newMeters,
    required this.existingMeterFor,
    required this.readings,
    required this.bills,
    required this.appliances,
  });

  final RestoreMode mode;

  /// Meters to insert (rows without `id`), keyed by their id in the backup.
  final Map<int, Map<String, Object?>> newMeters;

  /// Backup meter id → id of a meter already on the phone (merge only).
  final Map<int, int> existingMeterFor;

  /// Rows to insert. `meter_id` still holds the backup's meter id; the
  /// service swaps in the real id once meters are inserted.
  final List<Map<String, Object?>> readings;
  final List<Map<String, Object?>> bills;
  final List<Map<String, Object?>> appliances;

  bool get wipeFirst => mode == RestoreMode.replace;

  int get addedCount => newMeters.length + readings.length + bills.length + appliances.length;

  /// [existing] is what the phone has now (ignored for replace).
  static RestorePlan build(BackupData backup, RestoreMode mode, {BackupData? existing}) {
    final newMeters = <int, Map<String, Object?>>{};
    final existingFor = <int, int>{};

    String meterKey(Map<String, Object?> m) =>
        '${'${m['name']}'.trim().toLowerCase()}|${'${m['disco']}'.trim().toUpperCase()}';

    final current = mode == RestoreMode.merge ? existing : null;
    final currentMeters = <String, int>{
      if (current != null)
        for (final m in current.meters) meterKey(m): m['id'] as int,
    };

    for (final m in backup.meters) {
      final id = m['id'] as int;
      final match = currentMeters[meterKey(m)];
      if (match != null) {
        existingFor[id] = match;
      } else {
        newMeters[id] = Map.of(m)..remove('id');
      }
    }

    // What the phone already has, keyed by (phone meter id, natural key).
    final haveReadings = <String>{
      if (current != null)
        for (final r in current.readings) '${r['meter_id']}|${_day(r['reading_date'])}',
    };
    final haveBills = <String>{
      if (current != null)
        for (final b in current.bills) '${b['meter_id']}|${b['bill_month']}',
    };
    final haveAppliances = <String>{
      if (current != null)
        for (final a in current.appliances) '${a['meter_id']}|${_lower(a['name'])}|${a['watts']}',
    };

    // For an existing meter, compare against its phone id; a new meter has
    // nothing on the phone yet.
    String scope(Object? backupMeterId) {
      final phoneId = existingFor[backupMeterId];
      return phoneId == null ? 'new:$backupMeterId' : '$phoneId';
    }

    final readings = <Map<String, Object?>>[];
    final seenReadings = <String>{};
    for (final r in backup.readings) {
      final key = '${scope(r['meter_id'])}|${_day(r['reading_date'])}';
      // One reading per meter per day, as in the app.
      if (haveReadings.contains(key) || !seenReadings.add(key)) continue;
      readings.add(Map.of(r)..remove('id'));
    }

    final bills = <Map<String, Object?>>[];
    final seenBills = <String>{};
    for (final b in backup.bills) {
      final key = '${scope(b['meter_id'])}|${b['bill_month']}';
      if (haveBills.contains(key) || !seenBills.add(key)) continue;
      bills.add(Map.of(b)..remove('id'));
    }

    final appliances = <Map<String, Object?>>[];
    final seenAppliances = <String>{};
    for (final a in backup.appliances) {
      final key = '${scope(a['meter_id'])}|${_lower(a['name'])}|${a['watts']}';
      if (haveAppliances.contains(key) || !seenAppliances.add(key)) continue;
      appliances.add(Map.of(a)..remove('id'));
    }

    return RestorePlan._(
      mode: mode,
      newMeters: newMeters,
      existingMeterFor: existingFor,
      readings: readings,
      bills: bills,
      appliances: appliances,
    );
  }

  static String _day(Object? v) {
    final d = DateTime.tryParse('$v');
    return d == null ? '$v' : '${d.year}-${d.month}-${d.day}';
  }

  static String _lower(Object? v) => '$v'.trim().toLowerCase();
}

/// What a finished restore did.
class RestoreResult {
  const RestoreResult({
    required this.mode,
    required this.meters,
    required this.readings,
    required this.bills,
    required this.appliances,
    this.activeMeterId,
  });

  final RestoreMode mode;
  final int meters;
  final int readings;
  final int bills;
  final int appliances;

  /// Phone id of the meter that was active in the backup, if any.
  final int? activeMeterId;

  int get total => meters + readings + bills + appliances;
}
