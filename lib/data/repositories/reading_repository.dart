import '../db/app_database.dart';
import '../models/meter_reading.dart';

class ReadingRepository {
  ReadingRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  /// Readings for one meter, oldest first.
  Future<List<MeterReading>> forMeter(int meterId) async {
    final db = await _db.database;
    final rows = await db.query(
      'readings',
      where: 'meter_id = ?',
      whereArgs: [meterId],
      orderBy: 'reading_date ASC, id ASC',
    );
    return rows.map(MeterReading.fromMap).toList();
  }

  Future<List<MeterReading>> all() async {
    final db = await _db.database;
    final rows = await db.query('readings', orderBy: 'meter_id ASC, reading_date ASC');
    return rows.map(MeterReading.fromMap).toList();
  }

  /// One reading per meter per day: a second reading on the same date replaces it.
  Future<void> upsert(MeterReading reading) async {
    final db = await _db.database;
    final map = reading.toMap()..remove('id');
    await db.transaction((txn) async {
      await txn.delete(
        'readings',
        where: 'meter_id = ? AND reading_date = ?',
        whereArgs: [reading.meterId, map['reading_date']],
      );
      await txn.insert('readings', map);
    });
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('readings', where: 'id = ?', whereArgs: [id]);
  }
}
