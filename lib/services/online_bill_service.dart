import 'dart:async';

import 'package:http/http.dart' as http;

import '../core/constants/companies.dart';

/// One month in the bill's 12-month history table.
class OnlineBillMonth {
  const OnlineBillMonth({required this.month, required this.units, required this.bill, required this.paid});

  /// First day of the bill month.
  final DateTime month;
  final int units;
  final double bill;
  final double paid;
}

/// The latest bill as published on the company's PITC bill page. Only bill
/// figures are kept: names, addresses and ID numbers on the page are ignored.
class OnlineBill {
  const OnlineBill({
    required this.reference,
    required this.month,
    required this.units,
    required this.amount,
    this.dueDate,
    this.readingDate,
    this.presentReading,
    this.previousReading,
    this.sanctionedLoadKw,
    this.protectedCategory,
    this.amountAfterDue,
    this.history = const [],
  });

  final String reference;
  final DateTime month;
  final int units;

  /// Payable within due date.
  final double amount;
  final double? amountAfterDue;
  final DateTime? dueDate;
  final DateTime? readingDate;
  final double? presentReading;
  final double? previousReading;
  final double? sanctionedLoadKw;

  /// true = "Protected", false = "Unprotected", null = not shown.
  final bool? protectedCategory;

  /// Oldest first; does not include the current bill.
  final List<OnlineBillMonth> history;
}

class OnlineBillException implements Exception {
  const OnlineBillException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Fetches a bill from bill.pitc.com.pk: loads the search form, posts the
/// reference number back with the form's hidden fields, reads the result.
class OnlineBillService {
  OnlineBillService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _ua = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Mobile Safari/537.36';
  static const _timeout = Duration(seconds: 25);

  /// Companies whose bills are on the PITC site.
  static bool supports(PowerCompany c) => c.billUrl?.contains('bill.pitc.com.pk') ?? false;

  static String digitsOf(String ref) => ref.replaceAll(RegExp(r'\D'), '');

  static bool validReference(String ref) => digitsOf(ref).length == 14;

  /// Finds the bill without knowing the company: asks every PITC company at
  /// once and returns the first that knows this reference number.
  Future<(PowerCompany, OnlineBill)> find(String reference) async {
    if (!validReference(reference)) throw const OnlineBillException('Enter the 14-digit reference number');
    final companies = PowerCompanies.all.where(supports).toList();
    final done = Completer<(PowerCompany, OnlineBill)>();
    var failed = 0;
    OnlineBillException? lastError;
    for (final c in companies) {
      fetch(c, reference).then((b) {
        if (!done.isCompleted) done.complete((c, b));
      }, onError: (Object e) {
        failed++;
        if (e is OnlineBillException && e.message != 'No bill found for this reference number') lastError = e;
        if (failed == companies.length && !done.isCompleted) {
          done.completeError(lastError ?? const OnlineBillException('No bill found for this reference number'));
        }
      });
    }
    return done.future;
  }

  Future<OnlineBill> fetch(PowerCompany company, String reference) async {
    if (!supports(company)) throw const OnlineBillException('Online bills aren\'t available for this company');
    final ref = digitsOf(reference);
    if (ref.length != 14) throw const OnlineBillException('Enter the 14-digit reference number');
    final base = Uri.parse(company.billUrl!);
    final cookies = <String, String>{};

    void keep(http.BaseResponse r) {
      final raw = r.headers['set-cookie'];
      if (raw == null) return;
      for (final m in RegExp(r'(?:^|,)\s*([^=;,\s]+)=([^;,]*)').allMatches(raw)) {
        final name = m.group(1)!;
        if (const {'path', 'expires', 'domain', 'samesite', 'max-age'}.contains(name.toLowerCase())) continue;
        cookies[name] = m.group(2)!;
      }
    }

    Map<String, String> headers({bool form = false}) => {
          'User-Agent': _ua,
          if (cookies.isNotEmpty) 'Cookie': cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
          if (form) 'Content-Type': 'application/x-www-form-urlencoded',
          if (form) 'Referer': base.toString(),
        };

    try {
      final page = await _client.get(base, headers: headers()).timeout(_timeout);
      keep(page);
      final html = page.body;
      String field(String name) {
        final e = RegExp.escape(name);
        final m = RegExp('name="$e"[^>]*value="([^"]*)"').firstMatch(html) ??
            RegExp('value="([^"]*)"[^>]*name="$e"').firstMatch(html);
        return m == null ? '' : _unescape(m.group(1)!);
      }

      final body = {
        '__EVENTTARGET': '',
        '__EVENTARGUMENT': '',
        '__LASTFOCUS': '',
        '__VIEWSTATE': field('__VIEWSTATE'),
        '__VIEWSTATEGENERATOR': field('__VIEWSTATEGENERATOR'),
        '__EVENTVALIDATION': field('__EVENTVALIDATION'),
        '__RequestVerificationToken': field('__RequestVerificationToken'),
        'rbSearchByList': 'refno',
        'searchTextBox': ref,
        'ruCodeTextBox': '',
        'btnSearch': 'Search',
      };
      var res = await _client.post(base, headers: headers(form: true), body: body).timeout(_timeout);
      keep(res);
      // The search answers with a redirect to /general?refno=...
      for (var hops = 0; hops < 4 && res.statusCode >= 300 && res.statusCode < 400; hops++) {
        final loc = res.headers['location'];
        if (loc == null) break;
        res = await _client.get(base.resolve(loc), headers: headers()).timeout(_timeout);
        keep(res);
      }
      if (res.statusCode != 200) throw OnlineBillException('Bill site returned ${res.statusCode}');
      final bill = OnlineBillParser.parse(htmlToText(res.body), reference: ref);
      if (bill == null) {
        throw const OnlineBillException('No bill found for this reference number');
      }
      return bill;
    } on TimeoutException {
      throw const OnlineBillException('The bill site is not responding. Try again later.');
    } on OnlineBillException {
      rethrow;
    } catch (e) {
      throw const OnlineBillException('No internet, or the bill site is down');
    }
  }

  /// HTML → one text item per line, like the page's visible text.
  static String htmlToText(String html) {
    var t = html.replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'<[^>]+>'), '\n');
    t = _unescape(t);
    return t
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
  }

  static String _unescape(String s) => s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)));
}

/// Reads the PITC bill page text. Labels are on their own line in English,
/// followed by an Urdu line and then the value.
class OnlineBillParser {
  OnlineBillParser._();

  static const _months = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
  };

  static final _urdu = RegExp(r'[؀-ۿ]');

  static OnlineBill? parse(String text, {String reference = ''}) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    /// The first value line after [label] (skips Urdu captions and symbols).
    String? after(String label, {int from = 0}) {
      for (var i = from; i < lines.length; i++) {
        if (_norm(lines[i]) != label) continue;
        for (var j = i + 1; j < lines.length && j <= i + 4; j++) {
          final v = lines[j];
          if (_urdu.hasMatch(v)) continue;
          return v;
        }
      }
      return null;
    }

    double? number(String? s) {
      if (s == null) return null;
      final m = RegExp(r'-?[\d,]+(?:\.\d+)?').firstMatch(s);
      return m == null ? null : double.tryParse(m.group(0)!.replaceAll(',', ''));
    }

    final month = _monthYear(after('BILL MONTH'));
    final units = number(after('UNITS'));
    if (month == null || units == null) return null;

    // "PAYABLE WITHIN" / "DUE DATE" are two lines; the amount follows.
    double? amount;
    for (var i = 0; i < lines.length - 2; i++) {
      if (_norm(lines[i]) == 'PAYABLE WITHIN' && _norm(lines[i + 1]) == 'DUE DATE') {
        for (var j = i + 2; j < lines.length && j <= i + 5; j++) {
          if (_urdu.hasMatch(lines[j])) continue;
          amount = number(lines[j]);
          break;
        }
        break;
      }
    }
    amount ??= number(after('GRAND TOTAL'));

    double? afterDue;
    final till = lines.indexWhere((l) => l.toUpperCase().startsWith('TILL '));
    if (till >= 0 && till + 1 < lines.length) afterDue = number(lines[till + 1]);

    final category = after('CATEGORY')?.toUpperCase();
    final ref = OnlineBillService.digitsOf(after('REFERENCE NO') ?? reference);

    return OnlineBill(
      reference: ref.length == 14 ? ref : reference,
      month: month,
      units: units.round(),
      amount: amount ?? 0,
      amountAfterDue: afterDue,
      dueDate: _date(after('DUE DATE')),
      readingDate: _date(after('READING DATE')),
      presentReading: number(after('PRESENT READING')),
      previousReading: number(after('PREVIOUS READING')),
      sanctionedLoadKw: number(after('SAN LOAD')),
      protectedCategory: category == null
          ? null
          : category.startsWith('UNPROTECTED')
              ? false
              : category.startsWith('PROTECTED')
                  ? true
                  : null,
      history: _history(lines, month),
    );
  }

  static String _norm(String s) => s.replaceAll(RegExp(r'^[^A-Za-z]+'), '').trim().toUpperCase();

  /// "OCT 26" → 2026-10-01.
  static DateTime? _monthYear(String? s) {
    if (s == null) return null;
    final m = RegExp(r'([A-Za-z]{3})\w*\s*-?\s*(\d{2,4})').firstMatch(s);
    if (m == null) return null;
    final mon = _months[m.group(1)!.toUpperCase()];
    if (mon == null) return null;
    var y = int.parse(m.group(2)!);
    if (y < 100) y += 2000;
    return DateTime(y, mon);
  }

  /// "02 NOV 26" → 2026-11-02.
  static DateTime? _date(String? s) {
    if (s == null) return null;
    final m = RegExp(r'(\d{1,2})\s*-?\s*([A-Za-z]{3})\w*\s*-?\s*(\d{2,4})').firstMatch(s);
    if (m == null) return null;
    final mon = _months[m.group(2)!.toUpperCase()];
    if (mon == null) return null;
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    final d = int.parse(m.group(1)!);
    if (d < 1 || d > 31) return null;
    return DateTime(y, mon, d);
  }

  /// Rows "Oct25 / [status] / 284 / 11736 / 11736" after "BILL HISTORY".
  static List<OnlineBillMonth> _history(List<String> lines, DateTime current) {
    final start = lines.indexWhere((l) => _norm(l) == 'BILL HISTORY');
    if (start < 0) return const [];
    final row = RegExp(r'^([A-Za-z]{3})[\s-]?(\d{2})$');
    final out = <DateTime, OnlineBillMonth>{};
    for (var i = start + 1; i < lines.length && i < start + 200; i++) {
      final l = lines[i];
      if (_norm(l) == 'BILL MONTH' || _norm(l).startsWith('DEFERRED')) break;
      final m = row.firstMatch(l);
      if (m == null) continue;
      final mon = _months[m.group(1)!.toUpperCase()];
      if (mon == null) continue;
      final date = DateTime(2000 + int.parse(m.group(2)!), mon);
      final nums = <double>[];
      for (var j = i + 1; j < lines.length && j <= i + 5 && nums.length < 3; j++) {
        if (row.hasMatch(lines[j])) break;
        final v = double.tryParse(lines[j].replaceAll(',', ''));
        if (v != null) nums.add(v);
      }
      if (nums.isEmpty || !date.isBefore(current)) continue;
      out[date] = OnlineBillMonth(
        month: date,
        units: nums[0].round(),
        bill: nums.length > 1 ? nums[1] : 0,
        paid: nums.length > 2 ? nums[2] : 0,
      );
    }
    final list = out.values.toList()..sort((a, b) => a.month.compareTo(b.month));
    return list;
  }
}
