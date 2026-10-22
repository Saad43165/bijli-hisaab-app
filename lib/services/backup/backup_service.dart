import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/db/app_database.dart';
import '../settings_service.dart';
import 'backup_data.dart';
import 'restore_plan.dart';
import '../../core/l10n/l10n.dart';

/// A backup file kept on this phone (weekly auto copy or pre-restore copy).
class LocalBackup {
  const LocalBackup({required this.file, required this.summary});

  final File file;
  final BackupSummary summary;
}

/// Saves, shares and restores backups. See docs/FEATURE_PLANS.md (2).
class BackupService {
  BackupService(this._settings, {AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final SettingsService _settings;
  final AppDatabase _db;

  static const String appVersion = '1.0.0+1';
  static const Duration autoInterval = Duration(days: 7);
  static const int keepAuto = 4;
  static const int keepBeforeRestore = 2;

  // ------------------------------------------------------------- snapshot

  /// Everything a backup holds, read straight from the database.
  Future<BackupData> snapshot({BackupKind kind = BackupKind.manual}) async {
    final db = await _db.database;
    Future<List<Map<String, Object?>>> rows(String table) async {
      final keep = BackupData.columns[table]!;
      final result = await db.query(table, orderBy: 'id ASC');
      return [
        for (final r in result) {for (final e in r.entries) if (keep.contains(e.key)) e.key: e.value},
      ];
    }

    return BackupData(
      createdAt: DateTime.now(),
      kind: kind,
      appVersion: appVersion,
      meters: await rows('meters'),
      readings: await rows('readings'),
      bills: await rows('bills'),
      appliances: await rows('appliances'),
      settings: _settings.exportValues(BackupData.settingKeys),
    );
  }

  // ---------------------------------------------------------------- save

  /// Writes a backup to a temporary file and opens the share sheet
  /// (Google Drive, WhatsApp, Files…).
  Future<ShareResult> shareBackup() async {
    final data = await snapshot();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName(data.createdAt)));
    await file.writeAsString(data.encode(), flush: true);
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json', name: p.basename(file.path))],
        subject: 'Bijli Hisaab backup'.tr,
        text: 'Bijli Hisaab backup — {0} meters, {1} readings, {2} bills. Open Bijli Hisaab → Tools → Backup to restore it.'.trf({'0': data.meters.length, '1': data.readings.length, '2': data.bills.length}),
      ),
    );
  }

  static String fileName(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'bijli-hisaab-backup-${t.year}-${two(t.month)}-${two(t.day)}.json';
  }

  // ------------------------------------------------------------- restore

  /// Reads and checks a picked file before anything is changed.
  Future<BackupData> readFile(String text) async => BackupData.parse(text);

  /// Restores [backup]. A copy of the current data is saved first, and all
  /// changes happen in one transaction: either everything is restored or
  /// nothing changes.
  Future<RestoreResult> restore(BackupData backup, RestoreMode mode) async {
    final current = await snapshot(kind: BackupKind.beforeRestore);
    if (!current.isEmpty) {
      await _writeLocal(current);
      await _prune(BackupKind.beforeRestore, keepBeforeRestore);
    }

    final plan = RestorePlan.build(backup, mode, existing: current);
    final db = await _db.database;
    final idFor = <int, int>{...plan.existingMeterFor};

    await db.transaction((txn) async {
      if (plan.wipeFirst) {
        for (final t in ['appliances', 'bills', 'readings', 'meters']) {
          await txn.delete(t);
        }
      }
      for (final e in plan.newMeters.entries) {
        idFor[e.key] = await txn.insert('meters', e.value);
      }
      Future<void> insertAll(String table, List<Map<String, Object?>> rows) async {
        final batch = txn.batch();
        for (final r in rows) {
          final phoneId = idFor[r['meter_id']];
          if (phoneId == null) continue;
          batch.insert(table, {...r, 'meter_id': phoneId}, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await batch.commit(noResult: true);
      }

      await insertAll('readings', plan.readings);
      await insertAll('bills', plan.bills);
      await insertAll('appliances', plan.appliances);
    });

    // Settings only on replace: a merge keeps this phone's choices.
    int? active;
    final backupActive = backup.settings['active_meter_id'];
    if (backupActive is int) active = idFor[backupActive];
    if (mode == RestoreMode.replace) {
      final values = Map.of(backup.settings)..remove('active_meter_id');
      await _settings.importValues(values);
    }
    if (active != null && (mode == RestoreMode.replace || current.isEmpty)) {
      await _settings.setActiveMeterId(active);
    }

    return RestoreResult(
      mode: mode,
      meters: plan.newMeters.length,
      readings: plan.readings.length,
      bills: plan.bills.length,
      appliances: plan.appliances.length,
      activeMeterId: active,
    );
  }

  // ---------------------------------------------------------- local copies

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'backups'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _writeLocal(BackupData data) async {
    final dir = await _dir();
    final stamp = data.createdAt.toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File(p.join(dir.path, '${data.kind.name}_$stamp.json'));
    // Write then rename so a crash never leaves half a file.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(data.encode(), flush: true);
    return tmp.rename(file.path);
  }

  /// Copy taken before "Reset app" wipes everything.
  Future<void> copyBeforeReset() async {
    try {
      final data = await snapshot(kind: BackupKind.beforeReset);
      if (data.isEmpty) return;
      await _writeLocal(data);
      await _prune(BackupKind.beforeReset, keepBeforeRestore);
    } catch (e) {
      debugPrint('Copy before reset failed: $e');
    }
  }

  /// Weekly copy on the phone, so a bad restore or reset can be undone.
  /// Cheap to call on every app start.
  Future<void> autoBackupIfDue() async {
    try {
      final last = _settings.lastAutoBackup;
      if (last != null && DateTime.now().difference(last) < autoInterval) return;
      final data = await snapshot(kind: BackupKind.auto);
      if (data.isEmpty) return;
      await _writeLocal(data);
      await _prune(BackupKind.auto, keepAuto);
      await _settings.setLastAutoBackup(data.createdAt);
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
  }

  /// Copies on this phone, newest first. Damaged files are skipped.
  Future<List<LocalBackup>> localBackups() async {
    final dir = await _dir();
    final out = <LocalBackup>[];
    for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      try {
        final data = BackupData.parse(await f.readAsString());
        out.add(LocalBackup(file: f, summary: data.summary));
      } catch (_) {
        // Ignore anything unreadable.
      }
    }
    out.sort((a, b) => b.summary.createdAt.compareTo(a.summary.createdAt));
    return out;
  }

  Future<BackupData> readLocal(LocalBackup b) async => BackupData.parse(await b.file.readAsString());

  Future<void> _prune(BackupKind kind, int keep) async {
    final dir = await _dir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('${kind.name}_') && f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    for (final f in files.skip(keep)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
}
