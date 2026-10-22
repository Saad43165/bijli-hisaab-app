import 'bill_text_parser.dart';
import 'bill_values.dart';

/// Axis-aligned box in image pixels (pure Dart so this file stays testable).
class OcrBox {
  const OcrBox(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  double vOverlap(OcrBox o) => (bottom < o.bottom ? bottom : o.bottom) - (top > o.top ? top : o.top);
  double hOverlap(OcrBox o) => (right < o.right ? right : o.right) - (left > o.left ? left : o.left);
}

/// One recognised line of text and where it is on which scanned page.
class OcrLine {
  const OcrLine(this.text, this.box, {this.page = 0});

  final String text;
  final OcrBox box;
  final int page;
}

enum FieldConfidence {
  /// Label and value found next to each other and cross-checks agree.
  high,

  /// Found, but by a weaker rule (value below the label, or text-only).
  medium,

  /// Found but a cross-check disagrees — the user must look at it.
  low,
}

class ScanField<T> {
  const ScanField(this.value, this.confidence, {this.source, this.note});

  final T value;
  final FieldConfidence confidence;

  /// The OCR line the value came from (for highlighting on the photo).
  final OcrLine? source;
  final String? note;

  ScanField<T> withConfidence(FieldConfidence c, {String? note}) =>
      ScanField(value, c, source: source, note: note ?? this.note);
}

/// Everything the scanner found, with a confidence per field and warnings.
class BillScanAnalysis {
  const BillScanAnalysis({
    this.month,
    this.units,
    this.amount,
    this.dueDate,
    this.presentReading,
    this.previousReading,
    this.multiplier,
    this.disco,
    this.load,
    this.readingDate,
    this.reference,
    this.warnings = const [],
    this.rawText = '',
    this.pageCount = 0,
  });

  final ScanField<String>? month;
  final ScanField<int>? units;
  final ScanField<double>? amount;
  final ScanField<DateTime>? dueDate;
  final ScanField<double>? presentReading;
  final ScanField<double>? previousReading;
  final ScanField<double>? multiplier;
  final String? disco;

  /// Sanctioned load in kW (for setting up a meter from a bill).
  final ScanField<double>? load;

  /// When the meter was read for this bill (gives the reading day).
  final ScanField<DateTime>? readingDate;

  /// Reference / account number.
  final String? reference;
  final List<String> warnings;
  final String rawText;
  final int pageCount;

  static const empty = BillScanAnalysis();

  List<ScanField<Object>> get _all => [
        if (month != null) month!,
        if (units != null) units!,
        if (amount != null) amount!,
        if (dueDate != null) dueDate!,
        if (presentReading != null) presentReading!,
      ];

  int get foundCount => _all.length;
  int get needsCheckCount => _all.where((f) => f.confidence == FieldConfidence.low).length;
  bool get isEmpty => foundCount == 0;

  /// Field keys for analytics / badges.
  List<String> get detectedFields => [
        if (month != null) 'month',
        if (units != null) 'units',
        if (amount != null) 'amount',
        if (dueDate != null) 'due_date',
        if (presentReading != null) 'present_reading',
        if (disco != null) 'disco',
      ];

  /// Combine two scans (e.g. "Scan again" or a second page), keeping the more
  /// confident value for each field.
  BillScanAnalysis mergeWith(BillScanAnalysis other) {
    ScanField<T>? pick<T>(ScanField<T>? a, ScanField<T>? b) {
      if (a == null) return b;
      if (b == null) return a;
      return b.confidence.index < a.confidence.index ? b : a;
    }

    return BillScanAnalysis(
      month: pick(month, other.month),
      units: pick(units, other.units),
      amount: pick(amount, other.amount),
      dueDate: pick(dueDate, other.dueDate),
      presentReading: pick(presentReading, other.presentReading),
      previousReading: pick(previousReading, other.previousReading),
      multiplier: pick(multiplier, other.multiplier),
      disco: disco ?? other.disco,
      load: pick(load, other.load),
      readingDate: pick(readingDate, other.readingDate),
      reference: reference ?? other.reference,
      warnings: {...warnings, ...other.warnings}.toList(),
      rawText: [rawText, other.rawText].where((s) => s.isNotEmpty).join('\n\n— — —\n\n'),
      pageCount: pageCount + other.pageCount,
    );
  }
}

/// Reads a bill using *where* text is on the page, not just its order:
/// a value is taken from the same line as its label, the cell to its right,
/// or the cell directly below (table columns). Then the values are checked
/// against each other.
class BillScanAnalyzer {
  const BillScanAnalyzer();

  BillScanAnalysis analyze(
    List<OcrLine> lines, {
    DateTime? now,
    int pageCount = 1,

    /// Returns the expected bill in Rs for a number of units (sanity check).
    double Function(int units)? estimateAmount,

    /// The meter's company, to settle look-alike codes (IESCO / LESCO).
    String? expectedCompany,
  }) {
    final today = now ?? DateTime.now();
    final cleaned = [
      for (final l in lines)
        if (BillValues.clean(l.text).isNotEmpty) OcrLine(BillValues.clean(l.text), l.box, page: l.page),
    ];
    final rawText = _readingOrderText(cleaned);
    final fallback = const BillTextParser().parse(rawText, now: today);

    ScanField<double>? number(BillField f) => _findNumber(cleaned, BillValues.spec(f));

    var present = number(BillField.presentReading);
    var previous = number(BillField.previousReading);
    final mf = number(BillField.multiplier);
    var unitsNum = number(BillField.units);
    var amount = number(BillField.amount);
    var due = _findDate(cleaned, today, BillValues.spec(BillField.dueDate));
    final readingDate = _findDate(cleaned, today, BillValues.spec(BillField.readingDate));
    final load = number(BillField.load);
    var month = _findMonth(cleaned, today);

    // Fill gaps from the text-only parser (medium confidence).
    present ??= _fromText(fallback.presentReading);
    previous ??= _fromText(fallback.previousReading);
    unitsNum ??= _fromText(fallback.units?.toDouble());
    amount ??= _fromText(fallback.amount);
    due ??= fallback.dueDate == null ? null : ScanField(fallback.dueDate!, FieldConfidence.medium);
    month ??= fallback.month == null ? null : ScanField(fallback.month!, FieldConfidence.medium);

    var units = unitsNum == null
        ? null
        : ScanField(unitsNum.value.round(), unitsNum.confidence, source: unitsNum.source);

    final warnings = <String>[];
    final factor = mf?.value ?? 1;

    // Cross-check 1: units vs (present − previous) × MF.
    if (present != null && previous != null && present.value >= previous.value) {
      final fromReadings = ((present.value - previous.value) * factor).round();
      if (units == null) {
        if (fromReadings > 0 && fromReadings < 20000) {
          units = ScanField(fromReadings, FieldConfidence.medium,
              note: 'Worked out from present − previous reading');
        }
      } else if ((units.value - fromReadings).abs() <= 1) {
        units = units.withConfidence(FieldConfidence.high);
        present = present.withConfidence(FieldConfidence.high);
        previous = previous.withConfidence(FieldConfidence.high);
      } else {
        units = units.withConfidence(FieldConfidence.low,
            note: 'Readings give $fromReadings units');
        warnings.add('Units (${units.value}) don\'t match the meter readings ($fromReadings). '
            'Check the units on your bill.');
      }
    }

    // Cross-check 2: amount should be roughly what these units cost.
    if (amount != null && units != null && estimateAmount != null) {
      final expected = estimateAmount(units.value);
      if (expected > 0) {
        final ratio = amount.value / expected;
        if (ratio < 0.55 || ratio > 1.8) {
          amount = amount.withConfidence(FieldConfidence.low,
              note: 'Expected about Rs ${expected.round()}');
          warnings.add('The amount looks unusual for ${units.value} units '
              '(expected about Rs ${expected.round()}). It may include arrears or be misread.');
        }
      }
    }

    // Cross-check 3: due date should be recent.
    if (due != null) {
      final days = due.value.difference(DateTime(today.year, today.month, today.day)).inDays;
      if (days < -120 || days > 60) {
        due = due.withConfidence(FieldConfidence.low, note: 'Date looks far from today');
      }
    }

    // Cross-check 4: bill month vs due date (due in the same or next month).
    if (month == null && due != null) {
      month = ScanField(BillValues.monthKey(due.value.year, due.value.month - 1), FieldConfidence.medium,
          note: 'Guessed from the due date');
    } else if (month != null && due != null) {
      final parts = month.value.split('-');
      final m = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      final gap = (due.value.year - m.year) * 12 + due.value.month - m.month;
      if (gap < 0 || gap > 2) {
        month = month.withConfidence(FieldConfidence.low, note: 'Doesn\'t fit the due date');
      }
    }

    return BillScanAnalysis(
      month: month,
      units: units,
      amount: amount,
      dueDate: due,
      presentReading: present,
      previousReading: previous,
      multiplier: mf,
      disco: BillValues.detectCompany(rawText, expected: expectedCompany),
      load: load,
      readingDate: readingDate,
      reference: BillValues.findReference(rawText),
      warnings: warnings,
      rawText: rawText,
      pageCount: pageCount,
    );
  }

  static ScanField<double>? _fromText(double? v) =>
      v == null ? null : ScanField(v, FieldConfidence.medium);

  // ------------------------------------------------------------ geometry

  /// Lines to the right of [label] on the same row, nearest first.
  static List<OcrLine> _rightOf(OcrLine label, List<OcrLine> all) {
    final out = all.where((l) {
      if (identical(l, label) || l.page != label.page) return false;
      final minH = l.box.height < label.box.height ? l.box.height : label.box.height;
      return l.box.left >= label.box.right - 6 && label.box.vOverlap(l.box) >= minH * 0.45;
    }).toList()
      ..sort((a, b) => a.box.left.compareTo(b.box.left));
    return out.take(3).toList();
  }

  /// Lines directly below [label] that share its column, nearest first.
  static List<OcrLine> _below(OcrLine label, List<OcrLine> all) {
    final maxGap = label.box.height * 3.5;
    final out = all.where((l) {
      if (identical(l, label) || l.page != label.page) return false;
      final gap = l.box.top - label.box.bottom;
      if (gap < -label.box.height * 0.3 || gap > maxGap) return false;
      final minW = l.box.width < label.box.width ? l.box.width : label.box.width;
      return label.box.hOverlap(l.box) >= minW * 0.25;
    }).toList()
      ..sort((a, b) => a.box.top.compareTo(b.box.top));
    return out.take(2).toList();
  }

  ScanField<double>? _findNumber(List<OcrLine> lines, FieldSpec spec) {
    for (var p = 0; p < spec.labels.length; p++) {
      final strong = p == 0 ? FieldConfidence.high : FieldConfidence.medium;
      for (final line in lines) {
        final m = spec.labels[p].firstMatch(line.text);
        if (m == null) continue;
        if (spec.exclude != null && spec.exclude!.hasMatch(line.text)) continue;

        // 1. Same line, after the label.
        final same = BillValues.numbers(line.text.substring(m.end), spec);
        if (same.isNotEmpty) return ScanField(same.first.value, strong, source: line);

        // 2. Next cell on the same row.
        for (final r in _rightOf(line, lines)) {
          final nums = BillValues.numbers(r.text, spec);
          if (nums.isNotEmpty) return ScanField(nums.first.value, strong, source: r);
        }

        // 3. Cell below, in the label's column (table layouts). When the
        // row below holds several numbers, take the one under the label.
        final labelX = line.box.left + line.box.width * ((m.start + m.end) / 2 / line.text.length);
        for (final b in _below(line, lines)) {
          final nums = BillValues.numbers(b.text, spec);
          if (nums.isEmpty) continue;
          nums.sort((x, y) {
            final dx = (b.box.left + b.box.width * x.position - labelX).abs();
            final dy = (b.box.left + b.box.width * y.position - labelX).abs();
            return dx.compareTo(dy);
          });
          return ScanField(nums.first.value, FieldConfidence.medium, source: b);
        }
      }
    }
    return null;
  }

  ScanField<DateTime>? _findDate(List<OcrLine> lines, DateTime today, FieldSpec spec) {
    for (final line in lines) {
      final m = spec.labels.first.firstMatch(line.text);
      if (m == null || (spec.exclude?.hasMatch(line.text) ?? false)) continue;
      final same = BillValues.parseDate(line.text.substring(m.end), today);
      if (same != null) return ScanField(same, FieldConfidence.high, source: line);
      for (final n in _rightOf(line, lines)) {
        final d = BillValues.parseDate(n.text, today);
        if (d != null) return ScanField(d, FieldConfidence.medium, source: n);
      }
      // Table header ("READING DATE  ISSUE DATE  DUE DATE") with the dates
      // on the row below: take the date under this label.
      final labelX = line.box.left + line.box.width * ((m.start + m.end) / 2 / line.text.length);
      for (final b in _below(line, lines)) {
        final ds = BillValues.datesIn(b.text, today);
        if (ds.isEmpty) continue;
        ds.sort((x, y) => (b.box.left + b.box.width * x.position - labelX)
            .abs()
            .compareTo((b.box.left + b.box.width * y.position - labelX).abs()));
        return ScanField(ds.first.date, FieldConfidence.medium, source: b);
      }
    }
    return null;
  }

  ScanField<String>? _findMonth(List<OcrLine> lines, DateTime today) {
    final spec = BillValues.spec(BillField.month);
    for (final line in lines) {
      final m = spec.labels.first.firstMatch(line.text);
      if (m == null) continue;
      final same = BillValues.parseMonth(line.text.substring(m.end), today);
      if (same != null) return ScanField(same, FieldConfidence.high, source: line);
      for (final n in _rightOf(line, lines)) {
        final v = BillValues.parseMonth(n.text, today);
        if (v != null) return ScanField(v, FieldConfidence.medium, source: n);
      }
      // Header row ("CONNECTION DATE  BILL MONTH  READING DATE") with values
      // below: take the month under this label, not the first one in the row.
      final labelX = line.box.left + line.box.width * ((m.start + m.end) / 2 / line.text.length);
      for (final b in _below(line, lines)) {
        final ms = BillValues.monthsIn(b.text, today);
        if (ms.isEmpty) continue;
        ms.sort((x, y) => (b.box.left + b.box.width * x.position - labelX)
            .abs()
            .compareTo((b.box.left + b.box.width * y.position - labelX).abs()));
        return ScanField(ms.first.month, FieldConfidence.medium, source: b);
      }
    }
    return null;
  }

  /// Rebuilds rows (top to bottom, left to right) for the text fallback.
  static String _readingOrderText(List<OcrLine> lines) {
    final buffer = StringBuffer();
    final pages = <int>{for (final l in lines) l.page}.toList()..sort();
    for (final page in pages) {
      final ls = lines.where((l) => l.page == page).toList()
        ..sort((a, b) => a.box.centerY.compareTo(b.box.centerY));
      final rows = <List<OcrLine>>[];
      for (final l in ls) {
        if (rows.isNotEmpty) {
          final ref = rows.last.first;
          if ((l.box.centerY - ref.box.centerY).abs() < (l.box.height < ref.box.height ? l.box.height : ref.box.height) * 0.6) {
            rows.last.add(l);
            continue;
          }
        }
        rows.add([l]);
      }
      for (final row in rows) {
        row.sort((a, b) => a.box.left.compareTo(b.box.left));
        buffer.writeln(row.map((l) => l.text).join('  '));
      }
    }
    return buffer.toString();
  }
}
