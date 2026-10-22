import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../core/utils/formatters.dart';
import '../usage_forecaster.dart';
import '../../core/l10n/l10n.dart';

enum ReminderType {
  /// 3 days and 1 day before the meter reading day.
  readingDay,

  /// Evenings near the end of the cycle while close to / over a slab limit.
  closeToSlab,

  /// 2 days before and on the bill's due date.
  billDue,

  /// When no reading has been added for 6 days.
  noReading;

  String get settingKey => switch (this) {
        readingDay => 'reminder_reading_day',
        closeToSlab => 'reminder_slab',
        billDue => 'reminder_due_date',
        noReading => 'reminder_no_reading',
      };

  String get label => switch (this) {
        readingDay => 'Meter reading day',
        closeToSlab => 'Close to a slab',
        billDue => 'Bill due date',
        noReading => 'No recent reading',
      }.tr;

  String get description => switch (this) {
        readingDay => '3 days and 1 day before your meter is read',
        closeToSlab => 'Evenings in the last 10 days, only when you\'re near a limit',
        billDue => '2 days before and on the due date',
        noReading => 'After 6 days without a reading',
      }.tr;
}

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.type,
    required this.when,
    required this.title,
    required this.body,
  });

  /// Notification id; stable per slot so re-planning replaces, never stacks.
  final int id;
  final ReminderType type;

  /// Local Pakistan time.
  final DateTime when;
  final String title;
  final String body;

  @override
  String toString() => '$id ${type.name} $when "$title" — $body';
}

/// What the planner needs to know. Built by AppState from the active meter.
class ReminderInputs {
  const ReminderInputs({
    required this.now,
    required this.enabled,
    this.meterName,
    this.companyCode = '',
    this.summary,
    this.lastReadingDate,
    this.billAmount,
    this.billDueDate,
    this.billMonth,
  });

  final DateTime now;
  final Set<ReminderType> enabled;

  /// Shown when the user has more than one meter.
  final String? meterName;
  final String companyCode;
  final CycleSummary? summary;
  final DateTime? lastReadingDate;
  final double? billAmount;
  final DateTime? billDueDate;
  final String? billMonth;
}

/// Decides which reminders to schedule. Pure Dart, unit-tested; see
/// docs/FEATURE_PLANS.md (3). Re-run whenever data changes or the app opens,
/// so every message uses the latest numbers.
class ReminderPlanner {
  const ReminderPlanner();

  static const int idBase = 3000;
  static const int idCount = 40;

  /// All ids the planner may use (for cancelling).
  static Iterable<int> get allIds => Iterable.generate(idCount, (i) => idBase + i);

  // Quiet hours: nothing before 9:00 or after 21:30.
  static const _earliest = (h: 9, m: 0);
  static const _latest = (h: 21, m: 30);

  static const _eveningHour = 19;
  static const _slabHour = 20;
  static const _billHour = 10;

  /// How many evenings of slab alerts to keep queued.
  static const int slabDaysAhead = 3;

  List<PlannedReminder> plan(ReminderInputs i) {
    final out = <PlannedReminder>[];
    final now = i.now;
    final today = DateTime(now.year, now.month, now.day);
    final s = i.summary;
    final suffix = i.meterName == null ? '' : ' (${i.meterName})';

    void add(int slot, ReminderType type, DateTime day, int hour, String title, String body, {int minute = 0}) {
      final when = _quiet(DateTime(day.year, day.month, day.day, hour, minute));
      // At least a minute ahead, or it fires instantly / is dropped by Android.
      if (!when.isAfter(now.add(const Duration(minutes: 1)))) return;
      out.add(PlannedReminder(id: idBase + slot, type: type, when: when, title: title, body: '$body$suffix'));
    }

    // ------------------------------------------------- 1. reading day
    if (i.enabled.contains(ReminderType.readingDay) && s != null) {
      final readingDay = _day(s.cycleEnd);
      final dayText = _ordinal(readingDay.day);
      final hasProjection = s.status != UsageStatus.noData && s.projectedUnits > 0;
      final track = hasProjection ? ' You\'re on track for ${Fmt.whole(s.projectedUnits)} units.' : '';
      add(
        0,
        ReminderType.readingDay,
        readingDay.subtract(const Duration(days: 3)),
        _eveningHour,
        'Meter reading in 3 days',
        'Your meter is read on the $dayText.$track Add a reading now to check.',
      );
      add(
        1,
        ReminderType.readingDay,
        readingDay.subtract(const Duration(days: 1)),
        _eveningHour,
        'Meter reading tomorrow',
        'Last chance to save units this month.$track',
      );
    }

    // ------------------------------------------------- 2. close to a slab
    if (i.enabled.contains(ReminderType.closeToSlab) &&
        s != null &&
        s.targetLimit != null &&
        (s.status == UsageStatus.warn || s.status == UsageStatus.danger)) {
      // When the nearest limit can't realistically be saved, aim for the next one.
      final limit = s.alternativeLimit ?? s.targetLimit!;
      final end = _day(s.cycleEnd);
      final lastDate = _day(s.latestReadingDate ?? today);
      var slot = 10;
      for (var k = 0; k < slabDaysAhead + 1 && slot < 10 + slabDaysAhead; k++) {
        final day = today.add(Duration(days: k));
        final daysLeft = end.difference(day).inDays;
        // Only the last 10 days of the cycle, and not on reading day itself.
        if (daysLeft < 1 || daysLeft > 10) continue;
        // Units used by that evening if the current pace holds.
        final usedBy = s.unitsUsed + s.dailyRate * math.max(0, day.difference(lastDate).inDays);
        final left = limit - usedBy;
        final String title;
        final String body;
        if (left <= 0) {
          title = 'You may have crossed $limit units';
          body = 'Add a reading to check where you are.';
        } else {
          final budget = left / daysLeft;
          title = '$daysLeft ${daysLeft == 1 ? 'day'.tr : 'days'.tr} left in this bill';
          body = 'Use max ${Fmt.oneDp(budget)} units a day to stay under $limit.';
        }
        final before = out.length;
        add(slot, ReminderType.closeToSlab, day, _slabHour, title, body);
        if (out.length > before) slot++;
      }
    }

    // ------------------------------------------------- 3. bill due
    final due = i.billDueDate == null ? null : _day(i.billDueDate!);
    if (i.enabled.contains(ReminderType.billDue) && due != null && !due.isBefore(today)) {
      final company = i.companyCode.isEmpty ? '' : '${i.companyCode} ';
      final amount = (i.billAmount ?? 0) > 0 ? ' of ${Fmt.rs(i.billAmount!)}' : '';
      final weekday = DateFormat('EEEE').format(due);
      add(
        20,
        ReminderType.billDue,
        due.subtract(const Duration(days: 2)),
        _billHour,
        'Bill due on $weekday',
        'Your ${company}bill$amount is due on $weekday, ${Fmt.dayShort(due)}.',
      );
      add(
        21,
        ReminderType.billDue,
        due,
        _billHour,
        'Bill due today',
        'Pay your ${company}bill$amount today to avoid the late payment surcharge.',
      );
    }

    // ------------------------------------------------- 4. no recent reading
    if (i.enabled.contains(ReminderType.noReading) && i.lastReadingDate != null) {
      var day = _day(i.lastReadingDate!).add(const Duration(days: 6));
      final todayEvening = DateTime(today.year, today.month, today.day, _eveningHour);
      if (day.isBefore(today) || (day == today && !now.isBefore(todayEvening))) {
        // Already overdue: one reminder tomorrow (re-planned on each open).
        day = today.add(const Duration(days: 1));
      }
      // Skip if a reading-day reminder lands within a day of it.
      final clash = out.any(
        (r) => r.type == ReminderType.readingDay && _day(r.when).difference(day).inDays.abs() <= 1,
      );
      if (!clash) {
        final days = day.difference(_day(i.lastReadingDate!)).inDays;
        add(
          30,
          ReminderType.noReading,
          day,
          _eveningHour,
          'Check your meter',
          'No reading for $days days. Add one to keep your bill estimate accurate.',
        );
      }
    }

    out.sort((a, b) => a.when.compareTo(b.when));
    return out;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _quiet(DateTime t) {
    final early = DateTime(t.year, t.month, t.day, _earliest.h, _earliest.m);
    final late = DateTime(t.year, t.month, t.day, _latest.h, _latest.m);
    if (t.isBefore(early)) return early;
    if (t.isAfter(late)) return late;
    return t;
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}
