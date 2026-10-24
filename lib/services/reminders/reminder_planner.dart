import 'dart:math' as math;


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
  noReading,

  /// Sunday evening: units and bill of the week.
  weeklySummary,

  /// TOU meters: 30 minutes before peak hours start.
  peakHours;

  String get settingKey => switch (this) {
        readingDay => 'reminder_reading_day',
        closeToSlab => 'reminder_slab',
        billDue => 'reminder_due_date',
        noReading => 'reminder_no_reading',
        weeklySummary => 'reminder_weekly',
        peakHours => 'reminder_peak',
      };

  String get label => switch (this) {
        readingDay => 'Meter reading day',
        closeToSlab => 'Close to a slab',
        billDue => 'Bill due date',
        noReading => 'No recent reading',
        weeklySummary => 'Weekly summary',
        peakHours => 'Peak hours (TOU meters)',
      }.tr;

  String get description => switch (this) {
        readingDay => '3 days and 1 day before your meter is read',
        closeToSlab => 'Evenings in the last 10 days, only when you\'re near a limit',
        billDue => '2 days before and on the due date',
        noReading => 'After 6 days without a reading',
        weeklySummary => 'Sunday evening: your units and bill this week',
        peakHours => '30 minutes before expensive peak hours start',
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
    this.isTou = false,
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

  /// Time-of-use meter: warn before peak hours.
  final bool isTou;
}

/// Decides which reminders to schedule. Pure Dart, unit-tested; see
/// docs/FEATURE_PLANS.md (3). Re-run whenever data changes or the app opens,
/// so every message uses the latest numbers.
class ReminderPlanner {
  const ReminderPlanner();

  static const int idBase = 3000;
  /// Ids 50–79 were power-cut alerts (removed); still cancelled on re-plan
  /// so phones that had them scheduled get them cleared.
  static const int idCount = 80;

  /// Peak-hour alerts for this many days ahead (ids 40–46).
  static const int peakDaysAhead = 7;


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

    void add(int slot, ReminderType type, DateTime day, int hour, String title, String body,
        {int minute = 0, bool quiet = true}) {
      final at = DateTime(day.year, day.month, day.day, hour, minute);
      final when = quiet ? _quiet(at) : at;
      // At least a minute ahead, or it fires instantly / is dropped by Android.
      if (!when.isAfter(now.add(const Duration(minutes: 1)))) return;
      out.add(PlannedReminder(id: idBase + slot, type: type, when: when, title: title, body: '$body$suffix'));
    }

    // ------------------------------------------------- 1. reading day
    if (i.enabled.contains(ReminderType.readingDay) && s != null) {
      final readingDay = _day(s.cycleEnd);
      final dayText = L10n.isUrdu ? Fmt.dayShort(readingDay) : _ordinal(readingDay.day);
      final hasProjection = s.status != UsageStatus.noData && s.projectedUnits > 0;
      final track =
          hasProjection ? ' You\'re on track for {0} units.'.trf({'0': Fmt.whole(s.projectedUnits)}) : '';
      add(
        0,
        ReminderType.readingDay,
        readingDay.subtract(const Duration(days: 3)),
        _eveningHour,
        'Meter reading in 3 days'.tr,
        'Your meter is read on the {0}.{1} Add a reading now to check.'.trf({'0': dayText, '1': track}),
      );
      add(
        1,
        ReminderType.readingDay,
        readingDay.subtract(const Duration(days: 1)),
        _eveningHour,
        'Meter reading tomorrow'.tr,
        'Last chance to save units this month.{0}'.trf({'0': track}),
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
          title = 'You may have crossed {0} units'.trf({'0': limit});
          body = 'Add a reading to check where you are.'.tr;
        } else {
          final budget = left / daysLeft;
          title = '{0} {1} left in this bill'.trf({'0': daysLeft, '1': daysLeft == 1 ? 'day'.tr : 'days'.tr});
          body = 'Use max {0} units a day to stay under {1}.'.trf({'0': Fmt.oneDp(budget), '1': limit});
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
      final amount = (i.billAmount ?? 0) > 0 ? ' of {0}'.trf({'0': Fmt.rs(i.billAmount!)}) : '';
      final weekday = Fmt.weekday().format(due);
      add(
        20,
        ReminderType.billDue,
        due.subtract(const Duration(days: 2)),
        _billHour,
        'Bill due on {0}'.trf({'0': weekday}),
        'Your {0}bill{1} is due on {2}, {3}.'.trf({'0': company, '1': amount, '2': weekday, '3': Fmt.dayShort(due)}),
      );
      add(
        21,
        ReminderType.billDue,
        due,
        _billHour,
        'Bill due today'.tr,
        'Pay your {0}bill{1} today to avoid the late payment surcharge.'.trf({'0': company, '1': amount}),
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
          'Check your meter'.tr,
          'No reading for {0} days. Add one to keep your bill estimate accurate.'.trf({'0': days}),
        );
      }
    }

    // ------------------------------------------------- 5. weekly summary
    if (i.enabled.contains(ReminderType.weeklySummary) && s != null && s.hasData) {
      final sunday = today.add(Duration(days: (DateTime.sunday - today.weekday) % 7));
      final week = s.dailyRate * 7;
      add(
        31,
        ReminderType.weeklySummary,
        sunday,
        _slabHour,
        'Your week: about {0} units'.trf({'0': Fmt.whole(week)}),
        '{0} units a day. This bill so far {1} units, heading for {2} ({3}).'.trf({
          '0': Fmt.oneDp(s.dailyRate),
          '1': Fmt.whole(s.unitsUsed),
          '2': Fmt.whole(s.projectedUnits),
          '3': Fmt.rs(s.estimateProjected.total),
        }),
      );
    }

    // ------------------------------------------------- 6. peak hours (TOU)
    if (i.enabled.contains(ReminderType.peakHours) && i.isTou) {
      for (var k = 0; k < peakDaysAhead; k++) {
        final day = today.add(Duration(days: k));
        final start = peakStartHour(day);
        add(
          40 + k,
          ReminderType.peakHours,
          day,
          start - 1,
          'Peak hours in 30 minutes'.tr,
          'From {0} to {1} every unit costs more. Run the motor, iron or washing machine now.'.trf({
            '0': _clock(start * 60),
            '1': _clock((start + 4) * 60),
          }),
          minute: 30,
        );
      }
    }

    out.sort((a, b) => a.when.compareTo(b.when));
    return out;
  }

  /// "4:00 pm" / Urdu "4:00 شام".
  static String _clock(int minutes) => Fmt.clock(minutes ~/ 60 % 24, minutes % 60);

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

/// NEPRA peak hours for time-of-use meters: 4 evening hours that move with
/// the season. Returns the start hour (peak runs start..start+4).
int peakStartHour(DateTime d) => switch (d.month) {
      12 || 1 || 2 => 17,
      3 || 4 || 5 => 18,
      6 || 7 || 8 => 19,
      _ => 18,
    };
