import '../db/app_database.dart';
import '../models/appliance.dart';

class ApplianceRepository {
  ApplianceRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<List<Appliance>> forMeter(int meterId) async {
    final db = await _db.database;
    final rows = await db.query(
      'appliances',
      where: 'meter_id = ?',
      whereArgs: [meterId],
      orderBy: 'id ASC',
    );
    return rows.map(Appliance.fromMap).toList();
  }

  Future<List<Appliance>> all() async {
    final db = await _db.database;
    final rows = await db.query('appliances', orderBy: 'meter_id ASC, id ASC');
    return rows.map(Appliance.fromMap).toList();
  }

  Future<void> save(Appliance a) async {
    final db = await _db.database;
    if (a.id == null) {
      await db.insert('appliances', a.toMap()..remove('id'));
    } else {
      await db.update('appliances', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
    }
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('appliances', where: 'id = ?', whereArgs: [id]);
  }
}
