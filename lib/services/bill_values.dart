/// Shared, pure-Dart helpers for reading values out of OCR'd bill text.
/// Used by both the plain-text parser and the layout-aware analyzer.
library;

import '../core/constants/cities.dart';

enum BillField { month, units, amount, dueDate, presentReading, previousReading, multiplier, load, readingDate }

enum ValueKind { integer, money, reading, date, month, factor }

/// How to find one field on a bill: label patterns in priority order, plus
/// words that mean "this is a different number" (e.g. amount *after* due date).
class FieldSpec {
  const FieldSpec({
    required this.field,
    required this.labels,
    required this.kind,
    this.exclude,
    this.minDigits = 1,
    this.maxDigits = 7,
  });

  final BillField field;
  final List<RegExp> labels;
  final ValueKind kind;
  final RegExp? exclude;
  final int minDigits;
  final int maxDigits;
}

class BillValues {
  BillValues._();

  static const Map<String, int> months = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
  };

  /// Company code -> words printed on that company's bills.
  static const Map<String, List<String>> companies = {
    'K-Electric': ['K-ELECTRIC', 'KELECTRIC', 'K ELECTRIC', 'KARACHI ELECTRIC', 'KE LIVE'],
    'LESCO': ['LESCO', 'LAHORE ELECTRIC'],
    'IESCO': ['IESCO', 'ISLAMABAD ELECTRIC'],
    'FESCO': ['FESCO', 'FAISALABAD ELECTRIC'],
    'GEPCO': ['GEPCO', 'GUJRANWALA ELECTRIC'],
    'MEPCO': ['MEPCO', 'MULTAN ELECTRIC'],
    'PESCO': ['PESCO', 'PESHAWAR ELECTRIC'],
    'HAZECO': ['HAZECO', 'HAZARA ELECTRIC'],
    'TESCO': ['TESCO', 'TRIBAL ELECTRIC'],
    'HESCO': ['HESCO', 'HYDERABAD ELECTRIC'],
    'SEPCO': ['SEPCO', 'SUKKUR ELECTRIC'],
    'QESCO': ['QESCO', 'QUETTA ELECTRIC'],
    'AJK-ED': ['AZAD JAMMU', 'AJK ELECTRICITY', 'ELECTRICITY DEPARTMENT AJK'],
    'GB-WPD': ['GILGIT', 'WATER & POWER DEPARTMENT', 'WATER AND POWER DEPARTMENT'],
  };

  static final List<FieldSpec> specs = [
    FieldSpec(
      field: BillField.units,
      kind: ValueKind.integer,
      minDigits: 1,
      maxDigits: 5,
      labels: [
        RegExp(r'UNITS?\s*CONSUMED|CONSUMED\s*UNITS?'),
        RegExp(r'UNITS?\s*BILLED|BILLED\s*UNITS?|NET\s*UNITS?|KWH\s*CONSUMED|CONSUMPTION\s*\(?\s*KWH\s*\)?'),
        RegExp(r'TOTAL\s*UNITS?'),
      ],
      exclude: RegExp(r'HISTORY|AVERAGE|AVG|PEAK|PREVIOUS\s*MONTH|LAST\s*YEAR'),
    ),
    FieldSpec(
      field: BillField.amount,
      kind: ValueKind.money,
      minDigits: 2,
      maxDigits: 7,
      labels: [
        RegExp(r'PAYABLE\s*WITHIN\s*DUE\s*DATE|AMOUNT\s*PAYABLE\s*WITHIN|PAYABLE\s*BY\s*DUE\s*DATE|WITHIN\s*DUE\s*DATE'),
        RegExp(r'TOTAL\s*(AMOUNT\s*)?PAYABLE|NET\s*PAYABLE|AMOUNT\s*PAYABLE|AMOUNT\s*DUE|CURRENT\s*BILL|TOTAL\s*BILL'),
      ],
      exclude: RegExp(r'AFTER|LATE|L\.?P\.?\s*SURCHARGE|ARREAR'),
    ),
    FieldSpec(
      field: BillField.dueDate,
      kind: ValueKind.date,
      labels: [RegExp(r'DUE\s*DATE|LAST\s*DATE')],
      exclude: RegExp(r'PAYABLE|AFTER|WITHIN|AMOUNT'),
    ),
    FieldSpec(
      field: BillField.month,
      kind: ValueKind.month,
      labels: [RegExp(r'BILL(ING)?\s*MONTH|MONTH\s*OF\s*BILL|BILL\s*FOR')],
    ),
    FieldSpec(
      field: BillField.presentReading,
      kind: ValueKind.reading,
      minDigits: 3,
      maxDigits: 8,
      labels: [RegExp(r'PRESENT(\s*READING)?|CURRENT\s*READING|PRES\.?\s*READ')],
    ),
    FieldSpec(
      field: BillField.previousReading,
      kind: ValueKind.reading,
      minDigits: 3,
      maxDigits: 8,
      labels: [RegExp(r'PREVIOUS(\s*READING)?|PREV\.?\s*READ')],
      exclude: RegExp(r'PREVIOUS\s*(MONTH|BALANCE|ARREAR)'),
    ),
    FieldSpec(
      field: BillField.multiplier,
      kind: ValueKind.factor,
      minDigits: 1,
      maxDigits: 4,
      labels: [RegExp(r'\bM\.?\s?F\.?(?![A-Z])|MULTIPLY(ING)?\s*FACTOR')],
    ),
    FieldSpec(
      field: BillField.load,
      kind: ValueKind.factor,
      minDigits: 1,
      maxDigits: 3,
      labels: [
        RegExp(r'SANCTION(ED)?\s*LOAD|\bS\.?\s?LOAD'),
        RegExp(r'CONNECTED\s*LOAD|\bLOAD\b'),
      ],
      exclude: RegExp(r'SHEDDING|PEAK|FACTOR'),
    ),
    FieldSpec(
      field: BillField.readingDate,
      kind: ValueKind.date,
      labels: [RegExp(r'READING\s*DATE|DATE\s*OF\s*READING|READ(ING)?\s*DT')],
      exclude: RegExp(r'NEXT|PREVIOUS'),
    ),
  ];

  static FieldSpec spec(BillField f) => specs.firstWhere((s) => s.field == f);

  /// Normalises OCR text: upper case, single spaces.
  static String clean(String s) => s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Fixes common OCR letter/digit swaps inside number-like tokens
  /// ("1O,45O" → "10,450", "2l4" → "214"). Words are left alone.
  static String fixDigits(String s) {
    return s.replaceAllMapped(RegExp(r'[0-9OIlLSB|][0-9OIlLSB|,.]*'), (m) {
      final t = m.group(0)!;
      final digits = RegExp(r'\d').allMatches(t).length;
      if (digits == 0 || digits * 2 < t.replaceAll(RegExp(r'[,.]'), '').length) return t;
      return t
          .replaceAll('O', '0')
          .replaceAll(RegExp(r'[IlL|]'), '1')
          .replaceAll('S', '5')
          .replaceAll('B', '8');
    });
  }

  /// A number found in [text], with its relative position (0..1) along the
  /// text — used to line up table columns.
  static List<({double value, double position})> numbers(String text, FieldSpec spec) {
    final s = fixDigits(text)
        // Drop dates so "15-OCT-26" isn't read as 15.
        .replaceAll(RegExp(r'\d{1,2}[-/.]\s?[A-Z]{3}[A-Z]*[-/.]\s?\d{2,4}'), ' ')
        .replaceAll(RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\b'), ' ');
    final pattern = spec.kind == ValueKind.money
        ? RegExp(r'(?<![\d.])(\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?(?![\d])')
        : RegExp(r'(?<![\d.,])(\d+)(?:\.\d{1,2})?(?![\d,])');
    final out = <({double value, double position})>[];
    final len = s.isEmpty ? 1 : s.length;
    for (final m in pattern.allMatches(s)) {
      final digits = m.group(1)!.replaceAll(',', '');
      if (digits.length < spec.minDigits || digits.length > spec.maxDigits) continue;
      final v = double.tryParse(m.group(0)!.replaceAll(',', ''));
      if (v == null || !isPlausible(spec.field, v)) continue;
      out.add((value: v, position: (m.start + m.end) / 2 / len));
    }
    return out;
  }

  static bool isPlausible(BillField f, double v) => switch (f) {
        BillField.units => v > 0 && v < 20000,
        BillField.amount => v >= 10 && v < 5000000,
        BillField.presentReading || BillField.previousReading => v >= 0 && v < 100000000,
        BillField.multiplier => v >= 1 && v <= 1000,
        BillField.load => v >= 0.1 && v <= 500,
        _ => true,
      };

  static DateTime? parseDate(String s, DateTime today) {
    final t = fixDigits(s);
    final named = RegExp(
      r'\b(\d{1,2})[\s\-/.]*(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[\s\-/.,]*(\d{2,4})\b',
    ).firstMatch(t);
    if (named != null) {
      final day = int.parse(named.group(1)!);
      final month = months[named.group(2)!]!;
      final year = _year(named.group(3)!, today);
      if (year != null && day >= 1 && day <= 31) return DateTime(year, month, day);
    }
    // 15/10/2026 or 15-10-26 (day first, Pakistani format)
    final numeric = RegExp(r'\b(\d{1,2})[\-/.](\d{1,2})[\-/.](\d{2,4})\b').firstMatch(t);
    if (numeric != null) {
      final day = int.parse(numeric.group(1)!);
      final month = int.parse(numeric.group(2)!);
      final year = _year(numeric.group(3)!, today);
      if (year != null && day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  /// Every date in [s] with its relative position (0..1) along the text.
  static List<({DateTime date, double position})> datesIn(String s, DateTime today) {
    final t = fixDigits(s);
    final len = t.isEmpty ? 1 : t.length;
    final out = <({DateTime date, double position})>[];
    for (final m in RegExp(
      r'\b(\d{1,2})[\s\-/.]*(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[\s\-/.,]*(\d{2,4})\b',
    ).allMatches(t)) {
      final day = int.parse(m.group(1)!);
      final year = _year(m.group(3)!, today);
      if (year == null || day < 1 || day > 31) continue;
      out.add((date: DateTime(year, months[m.group(2)!]!, day), position: (m.start + m.end) / 2 / len));
    }
    for (final m in RegExp(r'\b(\d{1,2})[\-/.](\d{1,2})[\-/.](\d{2,4})\b').allMatches(t)) {
      final day = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final year = _year(m.group(3)!, today);
      if (year == null || day < 1 || day > 31 || month < 1 || month > 12) continue;
      out.add((date: DateTime(year, month, day), position: (m.start + m.end) / 2 / len));
    }
    return out;
  }

  /// "SEP 26", "SEPTEMBER 2026", "SEP-26" → "2026-09".
  static String? parseMonth(String s, DateTime today) {
    final m = RegExp(r"\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[\s\-/,.']*(\d{2,4})\b")
        .firstMatch(fixDigits(s));
    if (m == null) return null;
    final year = _year(m.group(2)!, today);
    if (year == null) return null;
    return monthKey(year, months[m.group(1)!]!);
  }

  /// Every "OCT 26"-style month in [s] with its relative position (0..1).
  static List<({String month, double position})> monthsIn(String s, DateTime today) {
    final t = fixDigits(s);
    final len = t.isEmpty ? 1 : t.length;
    return [
      for (final m in RegExp(r"\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[\s\-/,.']*(\d{2,4})\b")
          .allMatches(t))
        if (_year(m.group(2)!, today) case final year?)
          (month: monthKey(year, months[m.group(1)!]!), position: (m.start + m.end) / 2 / len),
    ];
  }

  static String monthKey(int year, int month) {
    final d = DateTime(year, month);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  static final RegExp _wapdaRef = RegExp(r'(?<!\d)(\d{2})\s?(\d{5})\s?(\d{7})(?!\d)(?:\s?([URC])\b)?');

  /// Reference number: "06 14562 1211000 U" on WAPDA-company bills (14
  /// digits), or the account number on K-Electric bills. Prefers a number
  /// printed next to a "Reference" / "Account" label.
  static String? findReference(String upperText) {
    final t = fixDigits(upperText);
    String fmt(RegExpMatch m) => '${m.group(1)} ${m.group(2)} ${m.group(3)}${m.group(4) == null ? '' : ' ${m.group(4)}'}';

    final label = RegExp(r'REF(ERENCE)?\.?\s*(NO|NUMBER|#)?').firstMatch(t);
    if (label != null) {
      final near = t.substring(label.end, (label.end + 60).clamp(0, t.length));
      final m = _wapdaRef.firstMatch(near);
      if (m != null) return fmt(m);
    }
    final account = RegExp(r'(ACCOUNT|A/C|CONTRACT)\s*(NO|NUMBER|#)?\.?\s*:?\s*(\d{10,13})(?!\d)').firstMatch(t);
    if (account != null) return account.group(3);
    final any = _wapdaRef.firstMatch(t);
    return any == null ? null : fmt(any);
  }

  /// Full names and websites printed on each company's bills — the strongest
  /// clues. Short codes alone are weak: OCR often reads IESCO as "LESCO" (and
  /// the other way round) because I and L look alike in bill fonts.
  static const Map<String, List<String>> _strong = {
    'LESCO': ['LAHORE ELECTRIC SUPPLY', 'LESCO.GOV.PK', 'LESCO.COM.PK'],
    'IESCO': ['ISLAMABAD ELECTRIC SUPPLY', 'IESCO.COM.PK', 'IESCO.GOV.PK'],
    'FESCO': ['FAISALABAD ELECTRIC SUPPLY', 'FESCO.COM.PK', 'FESCO.GOV.PK'],
    'GEPCO': ['GUJRANWALA ELECTRIC POWER', 'GEPCO.COM.PK', 'GEPCO.GOV.PK'],
    'MEPCO': ['MULTAN ELECTRIC POWER', 'MEPCO.COM.PK', 'MEPCO.GOV.PK'],
    'PESCO': ['PESHAWAR ELECTRIC SUPPLY', 'PESCO.GOV.PK'],
    'HAZECO': ['HAZARA ELECTRIC SUPPLY', 'HAZECO.COM.PK'],
    'TESCO': ['TRIBAL AREAS ELECTRICITY', 'TRIBAL AREA ELECTRICITY', 'TESCO.GOV.PK'],
    'HESCO': ['HYDERABAD ELECTRIC SUPPLY', 'HESCO.GOV.PK'],
    'SEPCO': ['SUKKUR ELECTRIC POWER', 'SUKKUR ELECTRIC SUPPLY', 'SEPCO.COM.PK'],
    'QESCO': ['QUETTA ELECTRIC SUPPLY', 'QESCO.COM.PK'],
    'K-Electric': ['K-ELECTRIC', 'KELECTRIC', 'KARACHI ELECTRIC', 'KE.COM.PK'],
    'AJK-ED': ['AZAD JAMMU', 'AZAD GOVT', 'ELECTRICITY DEPARTMENT AJK', 'AJK ELECTRICITY'],
    'GB-WPD': ['GILGIT-BALTISTAN', 'GILGIT BALTISTAN', 'WATER & POWER DEPARTMENT', 'WATER AND POWER DEPARTMENT'],
  };

  /// Codes OCR mixes up with each other (I ↔ L, 1 ↔ I).
  static const Map<String, String> _lookalike = {'LESCO': 'IESCO', 'IESCO': 'LESCO'};

  /// The company whose bill this is, weighing every clue on the page: full
  /// name and website (strong), short code (medium — shared with look-alike
  /// codes), and city names in the address and office lines.
  /// [expected] (the meter's company) breaks ties: a weak, ambiguous clue
  /// like a lone "LESCO" won't override it, but a full name will.
  static String? detectCompany(String upperText, {String? expected}) {
    final t = upperText.toUpperCase();
    final score = <String, double>{};
    void add(String code, double points) => score[code] = (score[code] ?? 0) + points;
    bool has(String word) => RegExp('(?<![A-Z0-9])${RegExp.escape(word)}(?![A-Z0-9])').hasMatch(t);

    for (final e in _strong.entries) {
      for (final w in e.value) {
        if (has(w)) add(e.key, 6);
      }
    }
    for (final e in companies.entries) {
      final code = e.value.first;
      if (!has(code)) continue;
      final twin = _lookalike[code];
      if (twin == null) {
        add(e.key, 3);
      } else {
        // "LESCO" may be a misread "IESCO": count it for both, a bit more
        // for the code as read.
        add(e.key, 2);
        add(twin, 1);
      }
    }
    // OCR variants of IESCO: "1ESCO", "IESC0".
    if (RegExp(r'(?<![A-Z0-9])[1I]ESC[O0](?![A-Z0-9])').hasMatch(t) && !has('IESCO')) add('IESCO', 2);
    // City names (address, sub-division, office) point to the company that
    // serves them. Two cities are enough to outweigh a misread code.
    for (final city in Cities.names) {
      final owner = Cities.companyOf(city);
      // Short names ("Dir", "Tank", "Hub") also appear as ordinary words.
      if (owner != null && city.length >= 5 && has(city.toUpperCase())) add(owner, 1.5);
    }

    if (score.isEmpty) return null;
    if (expected != null && score.containsKey(expected)) add(expected, 1.5);
    final best = score.entries.reduce((a, b) => b.value > a.value ? b : a);
    return best.value >= 2 ? best.key : null;
  }

  static int? _year(String raw, DateTime today) {
    final y = int.tryParse(raw);
    if (y == null) return null;
    final full = raw.length == 2 ? 2000 + y : y;
    if (full < today.year - 5 || full > today.year + 1) return null;
    return full;
  }
}
