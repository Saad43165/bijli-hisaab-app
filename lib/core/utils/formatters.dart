import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

/// Number, money and date formatting helpers (Pakistani conventions).
class Fmt {
  Fmt._();

  static final NumberFormat _whole = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _oneDp = NumberFormat('#,##0.0', 'en_US');
  static final NumberFormat _twoDp = NumberFormat('#,##0.00', 'en_US');

  // Display formats follow the app language (Urdu month names in Urdu).
  static String? get _loc => L10n.isUrdu ? 'ur' : null;
  static DateFormat get _day => DateFormat(L10n.isUrdu ? 'd MMMM yyyy' : 'd MMM yyyy', _loc);
  static DateFormat get _dayShort => DateFormat(L10n.isUrdu ? 'd MMMM' : 'd MMM', _loc);
  static DateFormat get _month => DateFormat(L10n.isUrdu ? 'MMMM yyyy' : 'MMM yyyy', _loc);
  static DateFormat get _monthShort => DateFormat(L10n.isUrdu ? 'MMMM' : 'MMM', _loc);
  static DateFormat weekday() => DateFormat('EEEE', _loc);
  static final DateFormat _monthKey = DateFormat('yyyy-MM');
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

  /// "Rs 8,420"
  static String rs(num value) => 'Rs ${_whole.format(value.round())}';

  /// "Rs 33.10"
  static String rate(num value) => 'Rs ${_twoDp.format(value)}';

  static String whole(num value) => _whole.format(value.round());
  static String oneDp(num value) => _oneDp.format(value);
  static String twoDp(num value) => _twoDp.format(value);

  /// "214 units"
  static String units(num value) => '${_whole.format(value.round())} ${'units'.tr}';

  static String day(DateTime d) => _day.format(d);
  static String dayShort(DateTime d) => _dayShort.format(d);
  static String month(DateTime d) => _month.format(d);
  static String monthShort(DateTime d) => _monthShort.format(d);

  /// "2026-09" — storage key for bill months.
  static String monthKey(DateTime d) => _monthKey.format(d);

  /// "2026-09-18" — storage format for dates.
  static String isoDate(DateTime d) => _isoDate.format(d);

  static DateTime parseMonthKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  static String monthKeyLabel(String key) => month(parseMonthKey(key));

  /// "2026-10-21" → "21 Oct 2026"; anything unparseable is returned as is.
  static String isoLabel(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : day(d);
  }

  /// Parse user input like "12,450" or " 12450.5 ".
  static double? parseNumber(String? input) {
    if (input == null) return null;
    final cleaned = input.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
