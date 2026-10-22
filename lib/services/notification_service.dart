import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminders/reminder_planner.dart';

/// Local notifications: instant slab alerts and scheduled smart reminders.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const int _slabAlertId = 1001;
  /// Old fixed weekly reminder (v1.0); cancelled on upgrade.
  static const int _legacyWeeklyId = 2001;

  tz.Location? _pk;

  static const AndroidNotificationDetails _alertChannel = AndroidNotificationDetails(
    'slab_alerts',
    'Slab alerts',
    channelDescription: 'Warnings when you are about to cross a slab limit',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_bolt',
  );

  static const AndroidNotificationDetails _reminderChannel = AndroidNotificationDetails(
    'reading_reminders',
    'Reading reminders',
    channelDescription: 'Reminders before your meter reading day and when no reading was added',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: 'ic_stat_bolt',
  );

  static const AndroidNotificationDetails _billChannel = AndroidNotificationDetails(
    'bill_reminders',
    'Bill due dates',
    channelDescription: 'Reminders before your electricity bill is due',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: 'ic_stat_bolt',
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      // Pakistan has one time zone and no daylight saving.
      _pk = tz.getLocation('Asia/Karachi');
    } catch (e) {
      debugPrint('Time zones unavailable: $e');
    }
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_bolt'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Android 13+ runtime permission. Returns true if granted (or not needed).
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('Permission request failed: $e');
      return false;
    }
  }

  Future<void> showSlabAlert({required String title, required String body}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _slabAlertId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: _alertChannel),
      );
    } catch (e) {
      debugPrint('Slab alert failed: $e');
    }
  }

  /// Replaces all scheduled reminders with [reminders].
  Future<void> scheduleReminders(List<PlannedReminder> reminders) async {
    if (!_ready) return;
    final pk = _pk;
    try {
      await _plugin.cancel(id: _legacyWeeklyId);
      for (final id in ReminderPlanner.allIds) {
        await _plugin.cancel(id: id);
      }
      if (pk == null) return;
      for (final r in reminders) {
        final w = r.when;
        final details = switch (r.type) {
          ReminderType.closeToSlab => _alertChannel,
          ReminderType.billDue => _billChannel,
          ReminderType.readingDay || ReminderType.noReading => _reminderChannel,
        };
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime(pk, w.year, w.month, w.day, w.hour, w.minute),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              details.channelId,
              details.channelName,
              channelDescription: details.channelDescription,
              importance: details.importance,
              priority: details.priority,
              icon: details.icon,
              styleInformation: BigTextStyleInformation(r.body),
            ),
          ),
          // Inexact: no special alarm permission, and a few minutes late is fine.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: r.type.name,
        );
      }
    } catch (e) {
      debugPrint('Scheduling reminders failed: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}
