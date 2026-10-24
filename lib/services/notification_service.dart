import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/l10n/l10n.dart';
import 'reminders/reminder_planner.dart';

/// What stops notifications from arriving on time (Reminders screen banner).
class NotificationHealth {
  const NotificationHealth({
    this.allowed = true,
    this.exactAlarms = true,
    this.batteryUnrestricted = true,
  });

  /// Android 13+ "Allow notifications".
  final bool allowed;

  /// Android 12+ "Alarms & reminders": without it alerts can be minutes late.
  final bool exactAlarms;

  /// Battery optimisation off: some phones delay or drop alarms otherwise.
  final bool batteryUnrestricted;

  bool get allGood => allowed && exactAlarms && batteryUnrestricted;
}

/// Local notifications: instant slab alerts and scheduled smart reminders.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const _system = MethodChannel('bijli/system');
  bool _ready = false;

  static const int _slabAlertId = 1001;
  static const int _testId = 1002;
  /// Old fixed weekly reminder (v1.0); cancelled on upgrade.
  static const int _legacyWeeklyId = 2001;

  /// Payloads that aren't a [ReminderType] name.
  static const String slabPayload = 'slab';
  static const String testPayload = 'test';

  /// The payload of a notification the user tapped (also the one that
  /// launched the app). The home screen listens and opens the right screen.
  final ValueNotifier<String?> tapped = ValueNotifier(null);

  tz.Location? _pk;

  static const _icon = 'ic_stat_bolt';
  static const _color = Color(0xFFF5B700);

  /// One Android channel per kind, so each can be muted on its own.
  static AndroidNotificationDetails _channel(String kind, {String? bigText}) {
    final (name, description, importance) = switch (kind) {
      'slab_alerts' => ('Slab alerts', 'Warnings when you are about to cross a slab limit', Importance.high),
      'bill_reminders' => ('Bill due dates', 'Reminders before your electricity bill is due', Importance.high),
      'peak_hours' => ('Peak hours', 'Before expensive peak hours start (TOU meters)', Importance.high),
      'power_cuts' => ('Power cuts', 'Before your load-shedding time', Importance.high),
      'weekly_summary' => ('Weekly summary', 'Your units and bill each Sunday', Importance.low),
      _ => ('Reading reminders', 'Reminders before your meter reading day and when no reading was added',
          Importance.defaultImportance),
    };
    return AndroidNotificationDetails(
      kind,
      name.tr,
      channelDescription: description.tr,
      importance: importance,
      priority: importance == Importance.high
          ? Priority.high
          : importance == Importance.low
              ? Priority.low
              : Priority.defaultPriority,
      icon: _icon,
      color: _color,
      category: kind == 'power_cuts' || kind == 'peak_hours'
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      styleInformation: bigText == null ? null : BigTextStyleInformation(bigText),
    );
  }

  static String _channelFor(ReminderType t) => switch (t) {
        ReminderType.closeToSlab => 'slab_alerts',
        ReminderType.peakHours => 'peak_hours',
        ReminderType.powerCut => 'power_cuts',
        ReminderType.billDue => 'bill_reminders',
        ReminderType.weeklySummary => 'weekly_summary',
        ReminderType.readingDay || ReminderType.noReading => 'reading_reminders',
      };

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
          android: AndroidInitializationSettings(_icon),
        ),
        onDidReceiveNotificationResponse: (r) => tapped.value = r.payload,
      );
      _ready = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        tapped.value = launch!.notificationResponse?.payload;
      }
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

  Future<bool> get notificationsAllowed async {
    if (!_ready) return false;
    try {
      return await _android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> get _canScheduleExact async {
    try {
      return await _android?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<NotificationHealth> health() async {
    if (!_ready) return const NotificationHealth(allowed: false);
    var battery = true;
    try {
      battery = await _system.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
    } catch (_) {}
    return NotificationHealth(
      allowed: await notificationsAllowed,
      exactAlarms: await _canScheduleExact,
      batteryUnrestricted: battery,
    );
  }

  /// Opens Android's "Alarms & reminders" page for this app.
  Future<void> openExactAlarmSettings() async {
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Exact alarm settings failed: $e');
    }
  }

  /// Opens this app's notification settings (when the permission was denied
  /// for good, Android no longer shows the dialog).
  Future<void> openNotificationSettings() => _invoke('openNotificationSettings');

  /// Asks Android to stop battery optimisation for the app.
  Future<void> openBatterySettings() => _invoke('requestIgnoreBatteryOptimizations');

  Future<void> _invoke(String method) async {
    try {
      await _system.invokeMethod<void>(method);
    } catch (e) {
      debugPrint('$method failed: $e');
    }
  }

  Future<void> showSlabAlert({required String title, required String body}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _slabAlertId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: _channel('slab_alerts', bigText: body)),
        payload: slabPayload,
      );
    } catch (e) {
      debugPrint('Slab alert failed: $e');
    }
  }

  /// "Send test notification" on the Reminders screen. With [after], it is
  /// scheduled instead (to check alarms fire while the app is closed).
  Future<bool> sendTest({Duration? after}) async {
    if (!_ready) return false;
    final title = 'Bijli Hisaab notifications work'.tr;
    final body = after == null
        ? 'You\'ll get slab warnings, bill due dates and reminders like this one.'.tr
        : 'This scheduled test arrived on time — reminders will work while the app is closed.'.tr;
    final details = NotificationDetails(android: _channel('reading_reminders', bigText: body));
    try {
      if (after == null) {
        await _plugin.show(id: _testId, title: title, body: body, notificationDetails: details, payload: testPayload);
      } else {
        final pk = _pk;
        if (pk == null) return false;
        await _plugin.zonedSchedule(
          id: _testId,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.now(pk).add(after),
          notificationDetails: details,
          androidScheduleMode: await _scheduleMode,
          payload: testPayload,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Test notification failed: $e');
      return false;
    }
  }

  /// Exact when Android allows it, so power-cut and peak alerts are on time;
  /// otherwise inexact (can be a few minutes late).
  Future<AndroidScheduleMode> get _scheduleMode async =>
      await _canScheduleExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

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
      final mode = await _scheduleMode;
      for (final r in reminders) {
        final w = r.when;
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime(pk, w.year, w.month, w.day, w.hour, w.minute),
          notificationDetails: NotificationDetails(android: _channel(_channelFor(r.type), bigText: r.body)),
          androidScheduleMode: mode,
          matchDateTimeComponents: r.repeatDaily ? DateTimeComponents.time : null,
          payload: r.type.name,
        );
      }
    } catch (e) {
      debugPrint('Scheduling reminders failed: $e');
    }
  }

  /// Ids actually queued with Android (for checking on a device).
  Future<List<int>> pendingIds() async {
    if (!_ready) return const [];
    final p = await _plugin.pendingNotificationRequests();
    return [for (final r in p) r.id];
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}
