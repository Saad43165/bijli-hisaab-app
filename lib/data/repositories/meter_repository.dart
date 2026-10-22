import '../db/app_database.dart';
import '../models/meter.dart';

class MeterRepository {
  MeterRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<List<Meter>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('meters', orderBy: 'id ASC');
    return rows.map(Meter.fromMap).toList();
  }

  Future<Meter> insert(Meter meter) async {
    final db = await _db.database;
    final id = await db.insert('meters', meter.toMap()..remove('id'));
    return meter.copyWith(id: id);
  }

  Future<void> update(Meter meter) async {
    final db = await _db.database;
    await db.update('meters', meter.toMap(), where: 'id = ?', whereArgs: [meter.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('meters', where: 'id = ?', whereArgs: [id]);
  }
}
