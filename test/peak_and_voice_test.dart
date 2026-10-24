import 'package:bijli_bachao/services/reminders/reminder_planner.dart';
import 'package:bijli_bachao/services/voice_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('peak alerts only for TOU meters, 30 minutes before peak', () {
    const planner = ReminderPlanner();
    final base = DateTime(2026, 11, 2, 9);
    expect(
      planner.plan(ReminderInputs(now: base, enabled: {ReminderType.peakHours})),
      isEmpty,
    );
    final r = planner.plan(ReminderInputs(now: base, enabled: {ReminderType.peakHours}, isTou: true));
    expect(r.length, ReminderPlanner.peakDaysAhead);
    expect(r.first.when, DateTime(2026, 11, 2, 17, 30)); // Nov: peak 6–10 pm
  });

  test('voice digits: numerals, Urdu digits and digit words', () {
    expect(VoiceNumber.digits('12,450'), '12450');
    expect(VoiceNumber.digits('one two four five zero'), '12450');
    expect(VoiceNumber.digits('۱۲۴۵۰'), '12450');
    expect(VoiceNumber.digits('ایک دو چار پانچ صفر'), '12450');
    expect(VoiceNumber.digits('hello'), '');
  });
}
