/// Checks an AI reply before it's shown: strips filler and markdown, keeps
/// it short, and rejects replies that are generic, off-topic or quote
/// rupee amounts the app never gave it (made-up rates and bills).
class AiGuard {
  AiGuard._();

  static const maxSentences = 5;
  static const maxChars = 600;

  /// Plain, short text, or null when the reply shouldn't be shown.
  /// [context] is the facts the AI was given; rupee amounts in the reply
  /// must come from it (or from simple arithmetic on it).
  static String? check(String raw, {required String context}) {
    final text = clean(raw);
    if (text.length < 8) return null;
    final lower = text.toLowerCase();
    if (_generic.any(lower.contains)) return null;
    final refusal = _refusal.any(lower.contains);
    if (!refusal && !_topic.hasMatch(lower)) return null;
    if (!_numbersOk(text, context)) return null;
    return text;
  }

  /// Markdown, emoji headers and filler removed; at most [maxSentences]
  /// sentences and [maxChars] characters.
  static String clean(String s) {
    var t = s
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .replaceAll(RegExp(r'\*\*|__|`|~~'), '')
        .replaceAll(RegExp(r'(?<!\w)\*(?!\s)|(?<!\s)\*(?!\w)'), '')
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*([-*•]|\d+[.)])\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\((https?:[^)]+)\)'), r'$1')
        .replaceAll('₨', 'Rs')
        .replaceAll(RegExp(r'Rs\.\s*'), 'Rs ')
        .replaceAll(RegExp(r'[ \t  ]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
    final sentences = _sentences(t).where((x) => !_filler.hasMatch(x.trim())).toList();
    t = sentences.take(maxSentences).join(' ').replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
    if (t.length > maxChars) {
      final cut = t.substring(0, maxChars);
      final end = cut.lastIndexOf(RegExp(r'[.!?۔؟]'));
      t = end > maxChars ~/ 2 ? cut.substring(0, end + 1) : '${cut.trimRight()}…';
    }
    return t;
  }

  static List<String> _sentences(String t) => [
        for (final m in RegExp(r'[^.!?۔؟\n]+(?:[.!?۔؟]+|\n|$)').allMatches(t))
          if (m.group(0)!.trim().isNotEmpty) m.group(0)!.trim(),
      ];

  static final _filler = RegExp(
    r'^(sure|certainly|of course|absolutely|great question|good question|happy to help|i hope this helps|hope this helps|'
    r'feel free to (ask|reach)|let me know if|as an ai|i am an ai|i\x27m an ai|is there anything else)\b',
    caseSensitive: false,
  );

  static const _generic = [
    'contact your local utility', 'your local utility', 'consult a professional', 'consult an electrician for',
    'varies depending on your location', 'depends on your location', 'varies by region', 'i don\'t have access to your',
    'i do not have access to your', 'i cannot access your', 'i can\'t access your', 'as of my last update',
    'my knowledge cutoff', 'in your country', 'your electricity provider',
  ];

  static const _refusal = [
    'only help with', 'only answer', 'can only', 'not able to help with that', 'outside what i can',
    'صرف بجلی', 'صرف بل', 'میں صرف',
  ];

  static final _topic = RegExp(
    r'bill|unit|electric|bijli|power|slab|rate|tariff|fca|fpa|nepra|disco|lesco|iesco|mepco|fesco|gepco|pesco|hesco|'
    r'sepco|qesco|tesco|k-electric|meter|reading|protected|lifeline|rs |rupee|appliance|\bac\b|fan|fridge|motor|'
    r'geyser|solar|watt|kwh|save|saving|gst|tax|due|helpline|load|بل|یونٹ|بجلی|ریٹ|سلیب|میٹر|محفوظ|روپے|بچت|ٹیکس',
  );

  /// Every rupee amount in [text] must be within 5% of a number in
  /// [context], or within 2% of the sum or difference of two of them.
  static bool _numbersOk(String text, String context) {
    final amounts = [
      for (final m in RegExp(r'(?:rs|pkr)\s*([\d,]+(?:\.\d+)?)|([\d,]+(?:\.\d+)?)\s*(?:روپے|rupees|pkr)', caseSensitive: false)
          .allMatches(text))
        double.tryParse((m.group(1) ?? m.group(2))!.replaceAll(',', '')),
    ].whereType<double>().where((v) => v >= 1).toList();
    if (amounts.isEmpty) return true;
    final known = [
      for (final m in RegExp(r'-?\d[\d,]*(?:\.\d+)?').allMatches(context))
        double.tryParse(m.group(0)!.replaceAll(',', '')),
    ].whereType<double>().map((v) => v.abs()).where((v) => v > 0).toSet().toList();
    bool near(double a, double b, [double share = 0.05]) => (a - b).abs() <= (b.abs() * share).clamp(1, double.infinity);
    for (final a in amounts) {
      if (known.any((k) => near(a, k))) continue;
      var ok = false;
      outer:
      for (var i = 0; i < known.length; i++) {
        for (var j = i; j < known.length; j++) {
          final x = known[i], y = known[j];
          if (near(a, x + y, 0.02) || near(a, (x - y).abs(), 0.02)) {
            ok = true;
            break outer;
          }
        }
      }
      if (!ok) return false;
    }
    return true;
  }
}
