import 'package:bijli_bachao/data/models/tariff.dart';
import 'package:bijli_bachao/services/reminders/reminder_planner.dart';
import 'package:bijli_bachao/services/usage_forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cycle 10 Oct → 10 Nov. Today 2 Nov, 9 am.
final now = DateTime(2026, 11, 2, 9);

CycleSummary summary({
  UsageStatus status = UsageStatus.safe,
  double used = 150,
  double rate = 5,
  double projected = 190,
  int? limit = 200,
  DateTime? latest,
}) =>
    CycleSummary(
      cycleStart: DateTime(2026, 10, 10),
      cycleEnd: DateTime(2026, 11, 10),
      today: DateTime(2026, 11, 2),
      consumerClass: ConsumerClass.protected,
      protectionReason: '',
      status: status,
      unitsUsed: used,
      dailyRate: rate,
      projectedUnits: projected,
      targetLimit: limit,
      latestReadingDate: latest ?? DateTime(2026, 11, 1),
      latestReadingValue: 12450,
    );

ReminderInputs inputs({
  Set<ReminderType>? enabled,
  CycleSummary? s,
  DateTime? lastReading,
  DateTime? due,
  double amount = 8420,
  DateTime? at,
}) =>
    ReminderInputs(
      now: at ?? now,
      enabled: enabled ?? ReminderType.values.toSet(),
      companyCode: 'LESCO',
      summary: s ?? summary(),
      lastReadingDate: lastReading ?? DateTime(2026, 11, 1),
      billAmount: amount,
      billDueDate: due,
    );

void main() {
  const planner = ReminderPlanner();

  List<PlannedReminder> of(List<PlannedReminder> all, ReminderType t) => all.where((r) => r.type == t).toList();

  test('reading-day reminders 3 days and 1 day before, at 7 pm', () {
    final r = of(planner.plan(inputs()), ReminderType.readingDay);
    expect(r.map((x) => x.when), [DateTime(2026, 11, 7, 19), DateTime(2026, 11, 9, 19)]);
    expect(r.first.body, contains('10th'));
    expect(r.first.body, contains('190 units'));
  });

  test('no slab reminders while safe', () {
    expect(of(planner.plan(inputs()), ReminderType.closeToSlab), isEmpty);
  });

  test('slab reminders in the last 10 days with a daily budget', () {
    final s = summary(status: UsageStatus.warn, used: 172, rate: 4, projected: 196);
    final r = of(planner.plan(inputs(s: s)), ReminderType.closeToSlab);
    expect(r.length, ReminderPlanner.slabDaysAhead);
    expect(r.first.when, DateTime(2026, 11, 2, 20));
    // 2 Nov: used 172 + 4×1 = 176, 24 left over 8 days → 3.0/day
    expect(r.first.title, '8 days left in this bill');
    expect(r.first.body, contains('3.0 units a day'));
    // 3 Nov: 180 used, 20 left over 7 days → 2.9/day
    expect(r[1].body, contains('2.9 units a day'));
    expect(r.first.body, contains('under 200'));
    expect(r.map((x) => x.id).toSet().length, r.length, reason: 'each evening has its own id');
  });

  test('slab reminder says when the limit is probably crossed', () {
    final s = summary(status: UsageStatus.danger, used: 199, rate: 6, projected: 250);
    final r = of(planner.plan(inputs(s: s)), ReminderType.closeToSlab);
    expect(r.last.title, contains('crossed 200'));
  });

  test('no slab reminders early in the cycle', () {
    final s = summary(status: UsageStatus.warn);
    final early = DateTime(2026, 10, 15, 9);
    expect(of(planner.plan(inputs(s: s, at: early)), ReminderType.closeToSlab), isEmpty);
  });

  test('bill due: 2 days before and on the day at 10 am', () {
    final r = of(planner.plan(inputs(due: DateTime(2026, 11, 6))), ReminderType.billDue);
    expect(r.map((x) => x.when), [DateTime(2026, 11, 4, 10), DateTime(2026, 11, 6, 10)]);
    expect(r.first.body, contains('LESCO bill of Rs 8,420'));
    expect(r.first.title, 'Bill due on Friday');
  });

  test('past due dates are ignored', () {
    expect(of(planner.plan(inputs(due: DateTime(2026, 10, 25))), ReminderType.billDue), isEmpty);
  });

  test('no-reading reminder 6 days after the last reading', () {
    final r = of(planner.plan(inputs(lastReading: DateTime(2026, 10, 30))), ReminderType.noReading);
    expect(r.single.when, DateTime(2026, 11, 5, 19));
    expect(r.single.body, contains('6 days'));
  });

  test('overdue no-reading reminder comes tomorrow, once', () {
    final r = of(planner.plan(inputs(lastReading: DateTime(2026, 10, 20))), ReminderType.noReading);
    expect(r.single.when, DateTime(2026, 11, 3, 19));
  });

  test('no-reading reminder is skipped next to a reading-day reminder', () {
    // 1 Nov + 6 = 7 Nov, the same evening as "reading in 3 days".
    final r = planner.plan(inputs(lastReading: DateTime(2026, 11, 1)));
    expect(of(r, ReminderType.noReading), isEmpty);
  });

  test('switched-off types and past times are never scheduled', () {
    final r = planner.plan(inputs(enabled: {ReminderType.billDue}, due: DateTime(2026, 11, 2)));
    expect(r.every((x) => x.type == ReminderType.billDue), isTrue);
    // 10 am today is still ahead of 9 am now.
    expect(r.single.when, DateTime(2026, 11, 2, 10));
    final late = planner.plan(inputs(enabled: {ReminderType.billDue}, due: DateTime(2026, 11, 2), at: DateTime(2026, 11, 2, 11)));
    expect(late, isEmpty);
  });

  test('all reminders are inside quiet hours and ids stay in range', () {
    final s = summary(status: UsageStatus.warn, used: 170, rate: 4, projected: 196);
    final r = planner.plan(inputs(s: s, due: DateTime(2026, 11, 6), lastReading: DateTime(2026, 10, 20)));
    for (final x in r) {
      final minutes = x.when.hour * 60 + x.when.minute;
      expect(minutes, inInclusiveRange(9 * 60, 21 * 60 + 30));
      expect(ReminderPlanner.allIds, contains(x.id));
    }
    expect(r.map((x) => x.id).toSet().length, r.length);
  });
}
