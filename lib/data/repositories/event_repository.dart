import '../db/app_database.dart';
import '../models/app_event.dart';

class EventRepository {
  EventRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<void> log(String type, {int? meterId, double? value, String? detail}) async {
    final db = await _db.database;
    await db.insert(
      'events',
      AppEvent(
        type: type,
        meterId: meterId,
        value: value,
        detail: detail,
        createdAt: DateTime.now(),
      ).toMap()
        ..remove('id'),
    );
  }

  Future<List<AppEvent>> all() async {
    final db = await _db.database;
    final rows = await db.query('events', orderBy: 'created_at ASC');
    return rows.map(AppEvent.fromMap).toList();
  }
}
