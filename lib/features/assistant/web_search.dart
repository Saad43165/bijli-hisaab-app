import 'dart:async';

import 'package:http/http.dart' as http;

/// One web result.
class WebResult {
  const WebResult(this.title, this.snippet, this.url);

  final String title;
  final String snippet;
  final String url;

  /// "geo.tv"
  String get site => (Uri.tryParse(url)?.host ?? url).replaceFirst('www.', '');
}

/// Free, keyless web search for the assistant (DuckDuckGo's HTML page) and a
/// simple page reader. Results are plain text for the AI to summarise.
class WebSearch {
  WebSearch._();

  static Future<List<WebResult>> results(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final res = await http
          .get(Uri.https('html.duckduckgo.com', '/html/', {'q': q, 'kl': 'pk-en'}), headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return const [];
      final re = RegExp(
        r'class="result__a" href="([^"]+)"[^>]*>(.*?)</a>.*?class="result__snippet"[^>]*>(.*?)</a>',
        dotAll: true,
      );
      return [
        for (final m in re.allMatches(res.body).take(8))
          WebResult(_text(m.group(2)!), _text(m.group(3)!), _realUrl(_unescape(m.group(1)!))),
      ];
    } catch (_) {
      return const [];
    }
  }

  static const _ua = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Mobile Safari/537.36';

  static Future<String> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return 'Empty search.';
    try {
      final res = await http
          .get(Uri.https('html.duckduckgo.com', '/html/', {'q': q, 'kl': 'pk-en'}), headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return 'Search failed (${res.statusCode}).';
      final out = <String>[];
      final re = RegExp(
        r'class="result__a" href="([^"]+)"[^>]*>(.*?)</a>.*?class="result__snippet"[^>]*>(.*?)</a>',
        dotAll: true,
      );
      for (final m in re.allMatches(res.body)) {
        final url = _realUrl(_unescape(m.group(1)!));
        out.add('${_text(m.group(2)!)}\n${_text(m.group(3)!)}\n$url');
        if (out.length >= 6) break;
      }
      return out.isEmpty ? 'No results.' : out.join('\n\n');
    } on TimeoutException {
      return 'Search timed out.';
    } catch (e) {
      return 'Search failed: $e';
    }
  }

  static Future<String> read(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return 'Not a web address.';
    try {
      final res = await http.get(uri, headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return 'Could not open the page (${res.statusCode}).';
      final type = res.headers['content-type'] ?? '';
      if (!type.contains('html') && !type.contains('text')) return 'This page is not text (maybe a PDF).';
      var t = res.body.replaceAll(RegExp(r'<(script|style|nav|footer|header)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), ' ');
      t = _text(t);
      return t.length > 5000 ? '${t.substring(0, 5000)}…' : t;
    } on TimeoutException {
      return 'The page took too long.';
    } catch (e) {
      return 'Could not open the page: $e';
    }
  }

  /// DuckDuckGo wraps links: `//duckduckgo.com/l/?uddg=<real url>`
  static String _realUrl(String href) {
    final u = Uri.tryParse(href.startsWith('//') ? 'https:$href' : href);
    final real = u?.queryParameters['uddg'];
    return real ?? href;
  }

  static String _text(String html) =>
      _unescape(html.replaceAll(RegExp(r'<[^>]+>'), ' ')).replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}
