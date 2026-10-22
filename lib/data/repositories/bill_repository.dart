import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/bill.dart';

class BillRepository {
  BillRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  /// Bills for one meter, newest month first.
  Future<List<Bill>> forMeter(int meterId) async {
    final db = await _db.database;
    final rows = await db.query(
      'bills',
      where: 'meter_id = ?',
      whereArgs: [meterId],
      orderBy: 'bill_month DESC',
    );
    return rows.map(Bill.fromMap).toList();
  }

  Future<List<Bill>> all() async {
    final db = await _db.database;
    final rows = await db.query('bills', orderBy: 'meter_id ASC, bill_month ASC');
    return rows.map(Bill.fromMap).toList();
  }

  /// Insert, or replace the existing bill for the same meter + month.
  Future<void> upsert(Bill bill) async {
    final db = await _db.database;
    await db.insert(
      'bills',
      bill.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertMany(List<Bill> bills) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final b in bills) {
      batch.insert('bills', b.toMap()..remove('id'), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }
}
