import 'dart:math' as math;

import 'bill_scan_analyzer.dart';
import 'bill_values.dart';

/// One possible meter reading found in a photo.
class MeterCandidate {
  const MeterCandidate({required this.value, required this.score, required this.source, this.reasons = const []});

  final double value;
  final double score;
  final OcrLine source;
  final List<String> reasons;
}

class MeterReadResult {
  const MeterReadResult({required this.candidates, required this.confidence, this.rawText = ''});

  /// Best first, at most 3, distinct values.
  final List<MeterCandidate> candidates;
  final FieldConfidence confidence;
  final String rawText;

  MeterCandidate? get best => candidates.isEmpty ? null : candidates.first;
  bool get isEmpty => candidates.isEmpty;

  static const empty = MeterReadResult(candidates: [], confidence: FieldConfidence.low);
}

/// Picks the meter reading out of OCR text from a photo of an electricity
/// meter. Pure Dart; see docs/FEATURE_PLANS.md (1) for the scoring rules.
class MeterReadingExtractor {
  const MeterReadingExtractor();

  /// Lines that hold other numbers printed on meters.
  static final _notReading = RegExp(
    r'\b(NO\.?|S\s?/\s?N|SR\.?|SERIAL|MODEL|IMP|REV|HZ|AMP|VOLT|CLASS|YEAR|MFG|MADE|TYPE|IEC|CONST|PHASE|REF|ID)\b|'
    r'\d\s?(V|A|HZ|IMP)\b|\d+\s?-\s?\d+\s?A\b',
  );

  MeterReadResult extract(
    List<OcrLine> lines, {
    double? lastReading,
    int daysSinceLast = 30,

    /// Image size, if known; otherwise the text's own extent is used.
    double? imageWidth,
    double? imageHeight,
  }) {
    final cleaned = [
      for (final l in lines)
        if (BillValues.clean(l.text).isNotEmpty) OcrLine(BillValues.clean(l.text), l.box, page: l.page),
    ];
    if (cleaned.isEmpty) return MeterReadResult.empty;

    final raw = cleaned.map((l) => l.text).join('\n');
    final candidates = <({double value, int digits, OcrLine line, bool joined})>[];

    for (final line in cleaned) {
      if (_notReading.hasMatch(line.text)) continue;
      for (final c in _numbersIn(line.text)) {
        candidates.add((value: c.value, digits: c.digits, line: line, joined: false));
      }
    }

    // OCR often reads drum digits as separate pieces ("124" "50", or one
    // digit per window): join runs of digit-only pieces on the same row.
    final digitLines = cleaned.where((l) => RegExp(r'^\d{1,7}$').hasMatch(BillValues.fixDigits(l.text))).toList()
      ..sort((a, b) => a.box.left.compareTo(b.box.left));
    bool adjacent(OcrLine a, OcrLine b) {
      final h = math.min(a.box.height, b.box.height);
      final gap = b.box.left - a.box.right;
      return a.page == b.page && gap >= -h * 0.2 && gap <= h * 0.9 && a.box.vOverlap(b.box) >= h * 0.5;
    }

    for (var start = 0; start < digitLines.length; start++) {
      final run = [digitLines[start]];
      var joined = BillValues.fixDigits(digitLines[start].text);
      for (var j = start + 1; j < digitLines.length && joined.length < 8; j++) {
        if (!adjacent(run.last, digitLines[j])) continue;
        run.add(digitLines[j]);
        joined += BillValues.fixDigits(digitLines[j].text);
        if (joined.length < 4 || joined.length > 8) continue;
        final merged = OcrLine(
          joined,
          OcrBox(
            run.first.box.left,
            run.map((r) => r.box.top).reduce(math.min),
            run.last.box.right,
            run.map((r) => r.box.bottom).reduce(math.max),
          ),
          page: run.first.page,
        );
        candidates.add((value: double.parse(joined), digits: joined.length, line: merged, joined: true));
      }
    }

    if (candidates.isEmpty) return MeterReadResult(candidates: const [], confidence: FieldConfidence.low, rawText: raw);

    // Frame of reference for "near the centre".
    final minX = cleaned.map((l) => l.box.left).reduce(math.min);
    final maxX = cleaned.map((l) => l.box.right).reduce(math.max);
    final minY = cleaned.map((l) => l.box.top).reduce(math.min);
    final maxY = cleaned.map((l) => l.box.bottom).reduce(math.max);
    final cx = imageWidth != null ? imageWidth / 2 : (minX + maxX) / 2;
    final cy = imageHeight != null ? imageHeight / 2 : (minY + maxY) / 2;
    final maxDist = math.max(1.0, math.sqrt(math.pow((imageWidth ?? (maxX - minX)) / 2, 2) + math.pow((imageHeight ?? (maxY - minY)) / 2, 2)));
    final maxH = candidates.map((c) => c.line.box.height).reduce(math.max);
    final kwhLines = cleaned.where((l) => l.text.contains('KWH')).toList();

    final scored = <MeterCandidate>[];
    for (final c in candidates) {
      var score = 0.0;
      final reasons = <String>[];
      final box = c.line.box;

      score += 0.35 * (box.height / maxH);
      final dist = math.sqrt(math.pow(box.centerX - cx, 2) + math.pow(box.centerY - cy, 2));
      score += 0.2 * (1 - (dist / maxDist).clamp(0.0, 1.0));

      score += switch (c.digits) {
        5 || 6 => 0.2,
        4 || 7 => 0.12,
        _ => 0.04,
      };
      // Pieces glued together are a guess; a number read whole wins a tie.
      if (c.joined) score -= 0.05;

      final nearKwh = kwhLines.any((k) =>
          identical(k, c.line) ||
          (k.page == c.line.page && (k.box.centerY - box.centerY).abs() < box.height * 2.5));
      if (nearKwh) {
        score += 0.1;
        reasons.add('next to kWh');
      }

      if (lastReading != null) {
        final maxIncrease = math.max(30.0, 150.0 * math.max(1, daysSinceLast).toDouble());
        final diff = c.value - lastReading;
        if (diff < 0) {
          score -= 0.8;
          reasons.add('lower than your last reading');
        } else if (diff <= maxIncrease) {
          score += 0.6;
          reasons.add('fits your last reading');
          if (c.value.round().toString().length == lastReading.round().toString().length) score += 0.1;
        } else {
          score -= 0.4;
          reasons.add('much higher than expected');
        }
      }

      scored.add(MeterCandidate(value: c.value, score: score, source: c.line, reasons: reasons));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final distinct = <MeterCandidate>[];
    for (final s in scored) {
      if (distinct.any((d) => d.value == s.value)) continue;
      distinct.add(s);
      if (distinct.length == 3) break;
    }

    final top = distinct.first;
    final margin = distinct.length > 1 ? top.score - distinct[1].score : 1.0;
    final plausible = lastReading == null || top.reasons.contains('fits your last reading');
    final confidence = top.score >= 0.9 && margin >= 0.2 && plausible
        ? FieldConfidence.high
        : top.score >= 0.5
            ? FieldConfidence.medium
            : FieldConfidence.low;

    return MeterReadResult(candidates: distinct, confidence: confidence, rawText: raw);
  }

  /// Numbers of 3–8 digits in [text], with digits the OCR spaced out joined
  /// ("1 2 4 5 0") and decimals dropped ("12450.6" → 12450).
  static List<({double value, int digits})> _numbersIn(String text) {
    var t = BillValues.fixDigits(text)
        .replaceAll(RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\b'), ' ') // dates
        .replaceAll(RegExp(r'\d{1,2}[-/.]\s?[A-Z]{3}[A-Z]*[-/.]\s?\d{2,4}'), ' ');
    t = t.replaceAllMapped(RegExp(r'\b\d{1,2}(?: \d{1,2}){2,}\b'), (m) => m.group(0)!.replaceAll(' ', ''));
    final out = <({double value, int digits})>[];
    for (final m in RegExp(r'(?<![\d.,])(\d{3,8})(?:[.,]\d{1,2})?(?![\d])').allMatches(t)) {
      final digits = m.group(1)!;
      out.add((value: double.parse(digits), digits: digits.length));
    }
    return out;
  }
}
