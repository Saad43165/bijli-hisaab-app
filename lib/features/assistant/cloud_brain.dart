import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/remote_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/utils/formatters.dart';
import '../../services/bill_ocr_service.dart';
import 'assistant_models.dart';
import 'assistant_tools.dart';
import 'local_brain.dart';
import 'web_search.dart';

/// The smart assistant: a free AI model (OpenAI-compatible chat API, no key
/// needed — Pollinations by default) that understands any wording and calls
/// the app's tools to look things up and act. Bill photos are read on the
/// phone first; only the text found goes to the AI. Falls back to
/// [LocalBrain] when offline or the service is busy.
class CloudBrain implements AssistantBrain {
  CloudBrain(this.tools, {http.Client? client})
      : _client = client ?? http.Client(),
        _local = LocalBrain(tools);

  final AssistantTools tools;
  final http.Client _client;
  final LocalBrain _local;

  static bool get configured => RemoteConfig.assistantUrl.startsWith('https://');

  /// What the assistant is doing right now ("Searching the web for …"),
  /// shown in the chat while it works. null when idle.
  final ValueNotifier<String?> status = ValueNotifier(null);

  void _say(String en, String ur) => status.value = _urduNow ? ur : en;
  bool _urduNow = false;

  static final _urduScript = RegExp(r'[؀-ۿ]');
  static final _romanUrdu = RegExp(
    r'\b(hai|hain|kya|kyun|kaise|kitna|kitne|mera|meri|mere|mujhe|mujh|karo|karna|batao|bataen|ke|ka|ki|mein|nahi|aur|kab|kahan|tareeq\w*|bijli|wala|wali)\b',
  );

  /// The chat's language ("talk in Urdu"); null follows each message.
  String? get chatLanguage => _local.chatLanguage;
  set chatLanguage(String? v) => _local.chatLanguage = v;

  static const _tools = [
    {'name': 'get_overview', 'description': "Latest facts about the user's active meter: latest bill, due date, prediction, rate category, this month's usage, FCA, biggest appliances.", 'parameters': {'type': 'object', 'properties': {}}},
    {'name': 'get_bill_history', 'description': 'Units and amount of past bills, newest first.', 'parameters': {'type': 'object', 'properties': {'months': {'type': 'integer'}}}},
    {'name': 'estimate_bill', 'description': 'Bill total with taxes for a number of units on this meter.', 'parameters': {'type': 'object', 'properties': {'units': {'type': 'integer'}}, 'required': ['units']}},
    {'name': 'fetch_latest_bill', 'description': "Download the newest bill from the electricity company's website and save it.", 'parameters': {'type': 'object', 'properties': {}}},
    {'name': 'add_meter_reading', 'description': "Save today's meter reading (kWh number). Only when the user gives a number.", 'parameters': {'type': 'object', 'properties': {'value': {'type': 'number'}}, 'required': ['value']}},
    {'name': 'open_screen', 'description': 'Show a screen of the app.', 'parameters': {'type': 'object', 'properties': {'screen': {'type': 'string', 'enum': AssistantTools.screens}}, 'required': ['screen']}},
    {'name': 'switch_meter', 'description': "Make another of the user's meters active, by its name.", 'parameters': {'type': 'object', 'properties': {'name': {'type': 'string'}}, 'required': ['name']}},
    {'name': 'add_meter', 'description': 'Add a meter by its 14-digit bill reference number; company and bills are found automatically.', 'parameters': {'type': 'object', 'properties': {'reference': {'type': 'string'}, 'name': {'type': 'string'}}, 'required': ['reference']}},
    {'name': 'web_search', 'description': 'Search the internet (news, NEPRA decisions, FCA, tariffs, schedules, how-tos). Returns titles, snippets and links.', 'parameters': {'type': 'object', 'properties': {'query': {'type': 'string'}}, 'required': ['query']}},
    {'name': 'read_webpage', 'description': 'Read the text of a web page found with web_search.', 'parameters': {'type': 'object', 'properties': {'url': {'type': 'string'}}, 'required': ['url']}},
    {'name': 'set_language', 'description': 'Change the language of the WHOLE app. Only when the user asks to change the app language.', 'parameters': {'type': 'object', 'properties': {'code': {'type': 'string', 'enum': ['en', 'ur']}}, 'required': ['code']}},
    {'name': 'set_theme', 'description': 'Light or dark mode.', 'parameters': {'type': 'object', 'properties': {'mode': {'type': 'string', 'enum': ['light', 'dark', 'system']}}, 'required': ['mode']}},
    {'name': 'add_appliance', 'description': 'Add an appliance or set how many the user has (e.g. fan, AC, inverter AC, fridge, motor, iron, LED bulb, TV, geyser). Call once per appliance type.', 'parameters': {'type': 'object', 'properties': {'name': {'type': 'string'}, 'quantity': {'type': 'integer'}, 'hours_per_day': {'type': 'number'}}, 'required': ['name']}},
    {'name': 'list_appliances', 'description': "The user's appliances with watts, hours a day and monthly units/cost.", 'parameters': {'type': 'object', 'properties': {}}},
  ];

  String _system() {
    final chat = _local.chatLanguage;
    return [
      'You are the assistant inside "Bijli Hisaab", an independent Pakistani electricity bill app (not a government app).',
      'You are an expert on Pakistani electricity: bills, due dates, units, slabs, protected rates (every one of the last',
      '6 bills at 200 units or less), lifeline, FCA/FPA and QTA adjustments, GST, electricity duty, TV fee, late payment',
      'surcharge (~10%), net metering/net billing for solar, peak/off-peak (TOU) meters, NEPRA decisions and DISCO procedures',
      '(new connection, meter change, wrong bill complaints, load shedding), and saving tips (AC at 26°C, inverter AC,',
      'DC fans, LED, motor timing, geyser, solar sizing).',
      'Think step by step before answering. Use the user\'s data below and the tools; never invent the user\'s numbers.',
      'For news, current NEPRA/FCA decisions, schedules or anything you are unsure of, call web_search (and read_webpage',
      'for details) and say where the information came from.',
      'When asked to do something a tool can do, call the tool, then say briefly what you did and what it means for them.',
      'Give specific, useful advice with rupee amounts when you can, and suggest the next step.',
      chat == 'ur'
          ? 'The user asked you to talk in Urdu: always reply in Urdu script.'
          : chat == 'en'
              ? 'The user asked you to talk in English: always reply in English.'
              : 'Reply in the same language and script as the user\'s latest message (English, Urdu, Roman Urdu, '
                  'Punjabi, Pashto, Sindhi or any other).',
      'set_language changes the whole app: call it only when the user clearly asks to change the app\'s language,',
      'not when they just want you to talk in a language.',
      'Style: warm, clear, plain text (no markdown, no tables), short paragraphs, money as "Rs 1,234".',
      'Politely decline requests that have nothing to do with electricity, energy, bills, money saving or this app.',
      'Today is ${DateTime.now().toIso8601String().substring(0, 10)}.',
      '',
      'App screens you can open: ${AssistantTools.screens.join(', ')}.',
      '',
      "User's data now:",
      tools.overview(),
    ].join('\n');
  }

  @override
  Future<AssistantReply> respond(String text, {String? imagePath, List<ChatMessage> history = const []}) async {
    _urduNow = _local.replyUrdu(text);
    try {
      return await _respond(text, imagePath: imagePath, history: history);
    } finally {
      status.value = null;
    }
  }

  Future<AssistantReply> _respond(String text, {String? imagePath, List<ChatMessage> history = const []}) async {
    // "Search…", "news", "internet pe dekho": a real web search, every time.
    if (imagePath == null && _searchIntent.hasMatch(text.toLowerCase())) return _searchAnswer(text, history);

    // Local first: commands and your own bill facts are answered instantly on
    // the phone. Open questions go to the AI, with the phone's answer as backup.
    if (imagePath == null) {
      final local = await _local.respond(text, history: history);
      if ((local.understood && !local.canImprove) || !configured) return local;
      try {
        _say('Asking the smart AI…', 'سمارٹ AI سے پوچھ رہے ہیں…');
        return await _talk(text, null, history).timeout(const Duration(seconds: 60));
      } catch (_) {
        if (local.understood) {
          return AssistantReply('${_busyNote(text)}\n\n${local.text}', actions: local.actions);
        }
        // Nothing useful offline: look it up on the web instead.
        return _searchAnswer(text, history);
      }
    }
    if (!configured) return _local.respond(text, imagePath: imagePath, history: history);
    try {
      _say('Reading your bill…', 'آپ کا بل پڑھ رہے ہیں…');
      return await _talk(text, imagePath, history).timeout(const Duration(seconds: 60));
    } catch (_) {
      // No internet or the service is busy: read the photo on the phone.
      return _local.respond(text, imagePath: imagePath, history: history);
    }
  }

  static final _searchIntent = RegExp(
    r'\b(search|searh|serch|google|internet|news|khabar|khabrain|dhoond\w*|dhund\w*|talash|find out|look up|web)\b|تلاش|خبر|انٹرنیٹ|سرچ|گوگل',
  );

  bool _replyUrdu(String text) => _local.replyUrdu(text);

  /// Roman Urdu → English search words ("punjab m bill zyada aty ya kpk m"
  /// → "electricity bill higher Punjab or Khyber Pakhtunkhwa Pakistan").
  @visibleForTesting
  static String searchQuery(String text) {
    const words = {
      'zyada': 'higher', 'zyadfa': 'higher', 'ziada': 'higher', 'zayada': 'higher', 'mehnga': 'expensive',
      'mehngi': 'expensive', 'sasta': 'cheaper', 'sasti': 'cheaper', 'kam': 'lower', 'ya': 'or', 'aur': 'and',
      'kpk': 'Khyber Pakhtunkhwa', 'bijli': 'electricity', 'bill': 'electricity bill', 'qeemat': 'price',
      'rate': 'rate', 'reet': 'rate', 'loadshedding': 'load shedding', 'load': 'load', 'kab': 'when', 'kyun': 'why',
      'kitna': 'how much', 'kitni': 'how much', 'naya': 'new', 'nayi': 'new', 'solar': 'solar', 'tax': 'tax',
      'subsidy': 'subsidy', 'mahina': 'month', 'mahine': 'month', 'saal': 'year',
    };
    const drop = {
      'm', 'me', 'mein', 'main', 'mai', 'aty', 'ata', 'ati', 'aate', 'hai', 'hain', 'he', 'ka', 'ki', 'ke', 'ko', 'se',
      'kya', 'koi', 'bhi', 'to', 'tu', 'hy', 'hoti', 'hota', 'raha', 'rahi', 'please', 'plz', 'bro', 'yar', 'yaar',
      'mujhe', 'mera', 'meri', 'batao', 'bata', 'do', 'dain', 'dein', 'kro', 'karo', 'kar', 'kr',
    };
    final out = <String>[];
    for (final raw in text.split(RegExp(r'\s+'))) {
      final w = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9؀-ۿ-]'), '');
      if (w.isEmpty || drop.contains(w)) continue;
      out.add(words[w] ?? raw);
    }
    var q = out.join(' ');
    if (!RegExp('electric|bijli|بجلی|bill|بل|nepra|fca|tariff|solar|load', caseSensitive: false).hasMatch(q)) {
      q = '$q electricity';
    }
    if (!q.toLowerCase().contains('pakistan')) q = '$q Pakistan';
    return q;
  }

  String _busyNote(String text) => _replyUrdu(text)
      ? '(سمارٹ AI ابھی مصروف ہے — فون پر محفوظ جواب:)'
      : '(The smart AI is busy right now — here is the quick answer saved on the phone:)';

  /// Searches the web on the phone, then asks the AI to answer from the
  /// results. If the AI is busy, shows the best results with links.
  Future<AssistantReply> _searchAnswer(String text, List<ChatMessage> history) async {
    final query = text
        .replaceAll(_searchIntent, ' ')
        .replaceAll(RegExp(r'\b(kro|karo|kar|please|plz|kr|krdo|kardo)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (query.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').length < 3) {
      return AssistantReply(_replyUrdu(text)
          ? 'کیا تلاش کروں؟ مثلاً: "نومبر کا FCA کتنا ہے" یا "لیسکو لوڈ شیڈنگ شیڈول"'
          : 'What should I search for? For example: "FCA for November" or "LESCO load shedding schedule".');
    }
    final q = searchQuery(query);
    _say('Searching the web for "$q"…', 'انٹرنیٹ پر تلاش: "$q"…');
    final results = await WebSearch.results(q);
    if (results.isEmpty) {
      return AssistantReply(_replyUrdu(text)
          ? 'انٹرنیٹ پر کچھ نہیں ملا، یا انٹرنیٹ نہیں ہے۔ سوال تھوڑا بدل کر دوبارہ پوچھیں۔'
          : 'I couldn\'t find anything online (or there\'s no internet). Try asking a little differently.');
    }
    final links = [
      for (final r in results.take(3))
        ReplyAction(r.site, () async {
          await launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication);
          return null;
        }),
    ];
    final sites = results.take(4).map((r) => r.site).toSet().join(', ');
    _say('Found results on $sites. Writing the answer…', '$sites پر نتائج ملے۔ جواب لکھ رہے ہیں…');
    if (configured) {
      final found = results.take(6).map((r) => '- ${r.title}: ${r.snippet} (${r.site})').join('\n');
      final messages = <Map<String, Object?>>[
        {'role': 'system', 'content': _system()},
        for (final m in history.reversed.take(6).toList().reversed)
          if (m.text.isNotEmpty) {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
        {
          'role': 'user',
          'content': '$text\n\n[Web search results for "$q":\n$found\n'
              'Answer the question from these results in 3-6 short sentences, mention which sources say what, '
              'and add what it means for this user if relevant. If the results don\'t answer it, say so.]',
        },
      ];
      try {
        final msg = await _call(messages, tools: false, attempts: 1, timeout: const Duration(seconds: 25));
        final reply = _clean((msg['content'] as String?) ?? '');
        if (reply.isNotEmpty) return AssistantReply(reply, actions: links);
      } catch (_) {
        // Fall through to the plain results.
      }
    }
    final urduReply = _replyUrdu(text);
    final top = results
        .take(4)
        .map((r) => '• ${r.title}\n  ${r.snippet.length > 160 ? '${r.snippet.substring(0, 160)}…' : r.snippet}\n  (${r.site})')
        .join('\n\n');
    return AssistantReply(
      '${urduReply ? 'انٹرنیٹ پر یہ ملا (سمارٹ AI ابھی مصروف ہے، اس لیے خلاصہ نہیں):' : 'Here\'s what I found online (the smart AI is busy, so no summary this time):'}\n\n$top',
      actions: links,
    );
  }

  Future<String> _photoText(String path) async {
    final r = await BillOcrService().read([path], expectedCompany: tools.state.activeMeter?.disco);
    final a = r.analysis;
    final found = [
      if (a.disco != null) 'company ${a.disco}',
      if (a.month?.value != null) 'bill month ${Fmt.monthKeyLabel(a.month!.value)}',
      if (a.units?.value != null) 'units ${a.units!.value}',
      if (a.amount?.value != null) 'amount Rs ${Fmt.whole(a.amount!.value)}',
      if (a.dueDate?.value != null) 'due ${Fmt.day(a.dueDate!.value)}',
      if (a.presentReading?.value != null) 'present reading ${Fmt.whole(a.presentReading!.value)}',
    ];
    // Only the figures: the raw text can hold the name, address and
    // reference number, which never leave the phone.
    return '[The user sent a photo of an electricity bill. Values read on the phone: '
        '${found.isEmpty ? 'none could be read' : found.join(', ')}.]';
  }

  Future<AssistantReply> _talk(String text, String? imagePath, List<ChatMessage> history) async {
    var userText = text.isEmpty ? 'What does this bill say?' : text;
    if (imagePath != null) userText = '$userText\n\n${await _photoText(imagePath)}';
    // Roman Urdu reads best answered in Roman Urdu (the model drifts to Urdu script).
    if (_local.chatLanguage == null && _romanUrdu.hasMatch(text.toLowerCase()) && !_urduScript.hasMatch(text)) {
      userText = '$userText\n\n[Reply in Roman Urdu, i.e. Urdu written in English letters.]';
    }
    final messages = <Map<String, Object?>>[
      {'role': 'system', 'content': _system()},
      for (final m in history.reversed.take(10).toList().reversed)
        if (m.text.isNotEmpty) {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
      {'role': 'user', 'content': userText},
    ];
    for (var round = 0; round < 5; round++) {
      final msg = await _call(messages);
      final calls = (msg['tool_calls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (calls.isEmpty) {
        final reply = _clean((msg['content'] as String?) ?? '');
        if (reply.isEmpty) throw const FormatException('empty');
        return AssistantReply(reply);
      }
      messages.add({'role': 'assistant', 'content': msg['content'], 'tool_calls': calls});
      for (final c in calls) {
        final f = (c['function'] as Map).cast<String, dynamic>();
        Map<String, dynamic> args;
        try {
          args = (jsonDecode('${f['arguments'] ?? '{}'}') as Map).cast<String, dynamic>();
        } catch (_) {
          args = const {};
        }
        _toolStatus('${f['name']}', args);
        messages.add({'role': 'tool', 'tool_call_id': c['id'], 'content': await _run('${f['name']}', args)});
      }
    }
    return AssistantReply('Done.'.tr);
  }

  /// One chat request. The free service often times out or says it's busy,
  /// so it's tried up to 3 times with a short pause.
  Future<Map<String, dynamic>> _call(
    List<Map<String, Object?>> messages, {
    bool tools = true,
    int attempts = 2,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    Object? last;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0) {
        _say('The AI is busy — trying again…', 'AI مصروف ہے — دوبارہ کوشش…');
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      try {
        final res = await _client
            .post(
              Uri.parse(RemoteConfig.assistantUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'model': RemoteConfig.assistantModel,
                'messages': messages,
                if (tools) 'tools': [for (final t in _tools) {'type': 'function', 'function': t}],
                'temperature': 0.3,
                'referrer': 'bijli-hisaab',
              }),
            )
            .timeout(timeout);
        if (res.statusCode != 200) throw HttpException('assistant ${res.statusCode}');
        final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final msg = ((body['choices'] as List).first['message'] as Map).cast<String, dynamic>();
        final empty = (msg['content'] as String? ?? '').trim().isEmpty && (msg['tool_calls'] as List? ?? const []).isEmpty;
        if (empty) throw const FormatException('empty');
        return msg;
      } catch (e) {
        last = e;
      }
    }
    throw last ?? const HttpException('assistant');
  }

  /// Plain text for the chat bubble: no markdown stars, odd spaces.
  static String _clean(String s) => s
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAll('₨', 'Rs')
      .replaceAll(RegExp(r'[  ]'), ' ')
      .trim();

  void _toolStatus(String name, Map<String, dynamic> a) {
    switch (name) {
      case 'web_search':
        _say('Searching the web for "${a['query']}"…', 'انٹرنیٹ پر تلاش: "${a['query']}"…');
      case 'read_webpage':
        final host = Uri.tryParse('${a['url']}')?.host.replaceFirst('www.', '') ?? '';
        _say('Reading $host…', '$host پڑھ رہے ہیں…');
      case 'fetch_latest_bill':
        _say('Getting your latest bill from the company website…', 'کمپنی کی ویب سائٹ سے آپ کا تازہ بل لا رہے ہیں…');
      case 'get_overview' || 'get_bill_history' || 'list_appliances':
        _say('Checking your bills and appliances…', 'آپ کے بل اور آلات دیکھ رہے ہیں…');
      case 'estimate_bill':
        _say('Working out the bill…', 'بل کا حساب لگا رہے ہیں…');
      case 'open_screen':
        _say('Opening ${a['screen']}…', 'کھول رہے ہیں…');
      default:
        _say('Working on it…', 'کام ہو رہا ہے…');
    }
  }

  Future<String> _run(String name, Map<String, dynamic> a) async {
    num? n(String k) => a[k] is num ? a[k] as num : num.tryParse('${a[k]}');
    switch (name) {
      case 'get_overview':
        return tools.overview();
      case 'get_bill_history':
        return tools.billHistory((n('months') ?? 12).toInt());
      case 'estimate_bill':
        return tools.estimateBill((n('units') ?? 0).toInt());
      case 'fetch_latest_bill':
        return tools.fetchLatestBill();
      case 'add_meter_reading':
        final v = n('value');
        return v == null ? 'No value given.' : tools.addReading(v.toDouble());
      case 'open_screen':
        return tools.openScreen('${a['screen']}');
      case 'switch_meter':
        return tools.switchMeter('${a['name']}');
      case 'add_meter':
        return tools.addMeterByReference('${a['reference']}', name: a['name'] as String?);
      case 'set_language':
        return tools.setLanguage('${a['code']}');
      case 'set_theme':
        return tools.setTheme('${a['mode']}');
      case 'add_appliance':
        return tools.addAppliance('${a['name']}',
            quantity: (n('quantity') ?? 1).toInt().clamp(1, 50), hours: n('hours_per_day')?.toDouble());
      case 'web_search':
        return WebSearch.search('${a['query']}');
      case 'read_webpage':
        return WebSearch.read('${a['url']}');
      case 'list_appliances':
        return tools.appliances();
      default:
        return 'Unknown tool $name.';
    }
  }
}
