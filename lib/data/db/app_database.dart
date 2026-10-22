import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite database. Schema is documented in docs/POWER_BI_DATA_SCHEMA.md.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _fileName = 'bijli_bachao.db';
  /// 2: meter reference number and type (standard / TOU / net-metering),
  ///    and the extra registers those meters have on readings.
  static const int _version = 2;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _fileName),
      version: _version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE meters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        disco TEXT NOT NULL,
        city TEXT NOT NULL DEFAULT '',
        province TEXT NOT NULL,
        connection_type TEXT NOT NULL DEFAULT 'home',
        phase TEXT NOT NULL DEFAULT 'single',
        sanctioned_load_kw REAL NOT NULL DEFAULT 1,
        protected_setting TEXT NOT NULL DEFAULT 'auto',
        reading_day INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        reference_no TEXT NOT NULL DEFAULT '',
        meter_type TEXT NOT NULL DEFAULT 'standard'
      )
    ''');
    batch.execute('''
      CREATE TABLE readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meter_id INTEGER NOT NULL REFERENCES meters(id) ON DELETE CASCADE,
        reading_date TEXT NOT NULL,
        reading_value REAL NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        created_at TEXT NOT NULL,
        peak_value REAL,
        export_value REAL
      )
    ''');
    batch.execute('CREATE INDEX idx_readings_meter_date ON readings(meter_id, reading_date)');
    batch.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meter_id INTEGER NOT NULL REFERENCES meters(id) ON DELETE CASCADE,
        bill_month TEXT NOT NULL,
        units INTEGER NOT NULL,
        amount_rs REAL NOT NULL DEFAULT 0,
        due_date TEXT,
        present_reading REAL,
        source TEXT NOT NULL DEFAULT 'manual',
        created_at TEXT NOT NULL,
        UNIQUE(meter_id, bill_month)
      )
    ''');
    batch.execute('''
      CREATE TABLE appliances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meter_id INTEGER NOT NULL REFERENCES meters(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'other',
        watts INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        hours_per_day REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        meter_id INTEGER,
        value REAL,
        detail TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final batch = db.batch()
        ..execute("ALTER TABLE meters ADD COLUMN reference_no TEXT NOT NULL DEFAULT ''")
        ..execute("ALTER TABLE meters ADD COLUMN meter_type TEXT NOT NULL DEFAULT 'standard'")
        ..execute('ALTER TABLE readings ADD COLUMN peak_value REAL')
        ..execute('ALTER TABLE readings ADD COLUMN export_value REAL');
      await batch.commit(noResult: true);
    }
  }

  /// Deletes every row (used by "Reset app").
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final t in ['events', 'appliances', 'bills', 'readings', 'meters']) {
        await txn.delete(t);
      }
    });
  }
}
