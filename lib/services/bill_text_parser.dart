import 'bill_values.dart';

/// Values found in an OCR'd electricity bill.
class ParsedBill {
  const ParsedBill({
    this.month,
    this.units,
    this.amount,
    this.dueDate,
    this.presentReading,
    this.previousReading,
    this.multiplier,
    this.disco,
  });

  /// "YYYY-MM"
  final String? month;
  final int? units;
  final double? amount;
  final DateTime? dueDate;
  final double? presentReading;
  final double? previousReading;
  final double? multiplier;
  final String? disco;

  List<String> get detectedFields => [
        if (month != null) 'month',
        if (units != null) 'units',
        if (amount != null) 'amount',
        if (dueDate != null) 'due_date',
        if (presentReading != null) 'present_reading',
        if (disco != null) 'disco',
      ];

  bool get isEmpty => detectedFields.isEmpty;
}

/// Plain-text parser for Pakistani DISCO and K-Electric bills. Used when no
/// layout (positions) is available, and as a fallback by the layout analyzer.
class BillTextParser {
  const BillTextParser();

  ParsedBill parse(String rawText, {DateTime? now}) {
    final text = rawText.toUpperCase().replaceAll('\r', '');
    final lines = text.split('\n').map(BillValues.clean).where((l) => l.isNotEmpty).toList();
    final today = now ?? DateTime.now();

    double? num(BillField f) => _numberAfter(lines, BillValues.spec(f));

    final present = num(BillField.presentReading);
    final previous = num(BillField.previousReading);
    final mf = num(BillField.multiplier);

    var units = num(BillField.units)?.round();
    if (units == null && present != null && previous != null && present > previous) {
      final diff = ((present - previous) * (mf ?? 1)).round();
      if (diff > 0 && diff < 20000) units = diff;
    }

    final due = _dateAfter(lines, BillValues.spec(BillField.dueDate), today);
    var month = _monthAfter(lines, BillValues.spec(BillField.month), today);
    if (month == null && due != null) {
      // Bills are usually due in the month after the bill month.
      month = BillValues.monthKey(due.year, due.month - 1);
    }

    return ParsedBill(
      month: month,
      units: units,
      amount: num(BillField.amount),
      dueDate: due,
      presentReading: present,
      previousReading: previous,
      multiplier: mf,
      disco: BillValues.detectCompany(text),
    );
  }

  /// Finds a label and returns the number after it on the same line, or on
  /// one of the next two lines. On the next lines (table rows) the number in
  /// the same column as the label is chosen.
  double? _numberAfter(List<String> lines, FieldSpec spec) {
    for (final label in spec.labels) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final m = label.firstMatch(line);
        if (m == null) continue;
        if (spec.exclude != null && spec.exclude!.hasMatch(line)) continue;

        final same = BillValues.numbers(line.substring(m.end), spec);
        if (same.isNotEmpty) return same.first.value;

        final column = (m.start + m.end) / 2 / line.length;
        for (var j = i + 1; j <= i + 2 && j < lines.length; j++) {
          final nums = BillValues.numbers(lines[j], spec);
          if (nums.isEmpty) continue;
          nums.sort((a, b) => (a.position - column).abs().compareTo((b.position - column).abs()));
          return nums.first.value;
        }
      }
    }
    return null;
  }

  DateTime? _dateAfter(List<String> lines, FieldSpec spec, DateTime today) {
    for (var i = 0; i < lines.length; i++) {
      final m = spec.labels.first.firstMatch(lines[i]);
      if (m == null) continue;
      if (spec.exclude != null && spec.exclude!.hasMatch(lines[i])) continue;
      for (final w in [lines[i].substring(m.end), ...lines.skip(i + 1).take(2)]) {
        final d = BillValues.parseDate(w, today);
        if (d != null) return d;
      }
    }
    return null;
  }

  String? _monthAfter(List<String> lines, FieldSpec spec, DateTime today) {
    for (var i = 0; i < lines.length; i++) {
      final m = spec.labels.first.firstMatch(lines[i]);
      if (m == null) continue;
      for (final w in [lines[i].substring(m.end), ...lines.skip(i + 1).take(1)]) {
        final month = BillValues.parseMonth(w, today);
        if (month != null) return month;
      }
    }
    return null;
  }
}
