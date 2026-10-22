/// Date-only helpers. All billing maths works on calendar days, not times.
class DateX {
  DateX._();

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime today() => dateOnly(DateTime.now());

  /// Whole calendar days from [a] to [b] (b - a). Safe across DST changes.
  static int daysBetween(DateTime a, DateTime b) {
    final ua = DateTime.utc(a.year, a.month, a.day);
    final ub = DateTime.utc(b.year, b.month, b.day);
    return ub.difference(ua).inDays;
  }

  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// The given [day] in [year]/[month], clamped to the month length
  /// (reading day 31 becomes 30 Apr, 28/29 Feb, ...).
  static DateTime clampedDay(int year, int month, int day) {
    // Normalise month overflow first (e.g. month 13 -> Jan next year).
    final first = DateTime(year, month);
    final max = daysInMonth(first.year, first.month);
    return DateTime(first.year, first.month, day > max ? max : day);
  }

  /// Start of the billing cycle that contains [date], given the meter's
  /// monthly [readingDay].
  static DateTime cycleStart(DateTime date, int readingDay) {
    final d = dateOnly(date);
    final thisMonth = clampedDay(d.year, d.month, readingDay);
    if (!d.isBefore(thisMonth)) return thisMonth;
    return clampedDay(d.year, d.month - 1, readingDay);
  }

  /// Start of the next billing cycle (exclusive end of the current one).
  static DateTime nextCycleStart(DateTime cycleStart, int readingDay) =>
      clampedDay(cycleStart.year, cycleStart.month + 1, readingDay);
}
