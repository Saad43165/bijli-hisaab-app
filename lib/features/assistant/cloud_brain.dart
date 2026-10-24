import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/remote_config.dart';
import '../../core/l10n/l10n.dart';
import '../../core/utils/formatters.dart';
import '../../services/bill_ocr_service.dart';
import 'ai_guard.dart';
import 'assistant_models.dart';
import 'assistant_tools.dart';
import 'local_brain.dart';

/// The assistant. Commands and the common questions (bill estimate, units,
/// slab, protected, rates, appliances, due date) are answered on the phone
/// from the app's own numbers by [LocalBrain]. Only other electricity
/// questions go to a free AI (OpenAI-compatible chat API, Pollinations by
/// default), with a strict prompt and the user's figures, and its reply is
/// checked by [AiGuard] before it's shown. Names, addresses and reference
/// numbers never leave the phone.
class CloudBrain implements AssistantBrain {
  CloudBrain(this.tools, {http.Client? client})
      : _client = client ?? http.Client(),
        _local = LocalBrain(tools);

  final AssistantTools tools;
  final http.Client _client;
  final LocalBrain _local;

  static bool get configured => RemoteConfig.assistantUrl.startsWith('https://');

  /// What the assistant is doing right now, shown in the chat while it
  /// works. null when idle.
  final ValueNotifier<String?> status = ValueNotifier(null);

  bool _urduNow = false;
  void _say(String en, String ur) => status.value = _urduNow ? ur : en;

  /// The chat's language ("talk in Urdu"); null follows the app.
  String? get chatLanguage => _local.chatLanguage;
  set chatLanguage(String? v) => _local.chatLanguage = v;

  /// "New chat": forget the conversation.
  void reset() => _local.reset();

  /// The last [maxTurns] messages (user and assistant), oldest first,
  /// trimmed from the oldest to about [maxChars] characters.
  @visibleForTesting
  static List<ChatMessage> recent(List<ChatMessage> history, {int maxTurns = 8, int maxChars = 3000}) {
    final out = <ChatMessage>[];
    var used = 0;
    for (final m in history.reversed) {
      if (m.text.isEmpty || m.source == ReplySource.app) continue;
      if (out.length >= maxTurns || used + m.text.length > maxChars) break;
      used += m.text.length;
      out.add(m);
    }
    return out.reversed.toList();
  }

  @override
  Future<AssistantReply> respond(String text, {String? imagePath, List<ChatMessage> history = const []}) async {
    _urduNow = _local.replyUrdu(text);
    try {
      final local = await _local.respond(text, imagePath: imagePath, history: history);
      if (imagePath == null && local.understood && !local.canImprove) return local;
      if (imagePath != null && text.trim().isEmpty) return local;
      if (!configured) return local.understood ? local : _unsure(offline: false);
      try {
        _say('Thinking…', 'سوچ رہے ہیں…');
        final ai = await _ask(text, imagePath, history).timeout(const Duration(seconds: 20));
        if (ai != null) return AssistantReply(ai, source: ReplySource.ai);
      } on TimeoutException {
        if (!local.understood) return _unsure(offline: true);
      } on SocketException {
        if (!local.understood) return _unsure(offline: true);
      } catch (_) {
        // Busy or a bad reply: the phone's answer below.
      }
      return local.understood ? local : _unsure(offline: false);
    } finally {
      status.value = null;
    }
  }

  /// When neither the phone nor the AI has a trustworthy answer.
  AssistantReply _unsure({required bool offline}) {
    final help = tools.state.activeMeter == null ? null : tools.state.company;
    final line = help?.helpline == null
        ? (_urduNow ? 'اپنی بجلی کمپنی کی ہیلپ لائن' : 'your electricity company\'s helpline')
        : (_urduNow ? '${help!.shortCode} ہیلپ لائن ${help.helpline}' : '${help!.shortCode} helpline ${help.helpline}');
    final text = offline
        ? (_urduNow
            ? 'انٹرنیٹ نہیں ہے، اس لیے میں ابھی صرف آپ کے بل، یونٹس، سلیب، ریٹ اور آلات کے سوالوں کا جواب دے سکتا ہوں۔ نیچے دیے گئے سوالوں میں سے کوئی آزمائیں۔'
            : 'You\'re offline, so I can only answer questions about your bill, units, slab, rates and appliances right now. Try one of the questions above.')
        : (_urduNow
            ? 'مجھے اس کا پکا جواب معلوم نہیں۔ صحیح معلومات کے لیے اپنا اصل بل دیکھیں یا $line پر رابطہ کریں۔'
            : 'I\'m not sure about that. Please check your official bill or call $line for the exact answer.');
    return AssistantReply(text, understood: false, source: ReplySource.app);
  }

  bool get _replyUrdu => (_local.chatLanguage ?? L10n.language) == 'ur' || _urduNow;

  @visibleForTesting
  static String systemPrompt({required String facts, required bool urdu, required String today}) => [
        'You are the assistant inside "Bijli Hisaab", an independent app for Pakistani household electricity bills.',
        'You only help with: the user\'s electricity bill and units, NEPRA slabs and tariffs, DISCOs (LESCO, IESCO, MEPCO, '
            'FESCO, GEPCO, PESCO, HESCO, SEPCO, QESCO, TESCO, K-Electric), FCA/FPA and QTA, protected/unprotected and '
            'lifeline rates, taxes on the bill, due dates and late surcharge, meter readings, solar/net metering basics, '
            'and saving electricity at home.',
        'Rules:',
        '1. Use ONLY the user\'s facts below for any number about their bill, units, rates or costs. Never invent or '
            'estimate rates, prices, dates or figures that are not in the facts. If a number you need is missing, say '
            'you don\'t have it.',
        '2. If you are not sure, say so plainly and tell them to check their official bill or call their DISCO '
            'helpline (118 for most DISCOs).',
        '3. Answer in 2 to 5 short sentences of plain text. No markdown, lists, headings, links or emojis. No greetings '
            'or filler. Money as "Rs 1,234".',
        '4. Be specific to this user and Pakistan. Never give generic advice like "contact your local utility".',
        '5. If the question is not about electricity, bills or this app, politely say you can only help with '
            'electricity bills, in one sentence.',
        urdu
            ? '6. Reply in Urdu (Urdu script), simple everyday words.'
            : '6. Reply in English, simple everyday words.',
        '7. This is an ongoing chat: read short follow-ups ("and the fan?", "why?", "kitna?") as being about the '
            'previous messages.',
        'Today is $today.',
        '',
        'User\'s facts from the app:',
        facts,
      ].join('\n');

  Future<String?> _ask(String text, String? imagePath, List<ChatMessage> history) async {
    final facts = tools.facts().context();
    var question = text.trim().isEmpty ? 'What does this bill say?' : text.trim();
    var context = facts;
    if (imagePath != null) {
      final photo = await _photoText(imagePath);
      question = '$question\n\n$photo';
      context = '$facts\n$photo';
    }
    final past = recent(history);
    final messages = <Map<String, Object?>>[
      {
        'role': 'system',
        'content': systemPrompt(facts: facts, urdu: _replyUrdu, today: DateTime.now().toIso8601String().substring(0, 10)),
      },
      for (final m in past) {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
      {'role': 'user', 'content': question},
    ];
    final raw = await _call(messages);
    // Numbers the user typed or the chat already gave are fine to repeat.
    return AiGuard.check(raw, context: '$context\n${past.map((m) => m.text).join('\n')}\n$text');
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
    return '[Photo of an electricity bill. Values read on the phone: '
        '${found.isEmpty ? 'none could be read' : found.join(', ')}.]';
  }

  /// One chat request, tried twice (the free service is often busy).
  Future<String> _call(List<Map<String, Object?>> messages) async {
    Object? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        _say('The AI is busy — trying again…', 'AI مصروف ہے — دوبارہ کوشش…');
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
      try {
        final res = await _client
            .post(
              Uri.parse(RemoteConfig.assistantUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'model': RemoteConfig.assistantModel,
                'messages': messages,
                'temperature': 0.2,
                'max_tokens': 300,
                'referrer': 'bijli-hisaab',
              }),
            )
            .timeout(const Duration(seconds: 9));
        if (res.statusCode != 200) throw HttpException('assistant ${res.statusCode}');
        final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final msg = ((body['choices'] as List).first['message'] as Map).cast<String, dynamic>();
        final content = (msg['content'] as String? ?? '').trim();
        if (content.isEmpty) throw const FormatException('empty');
        return content;
      } on SocketException {
        rethrow;
      } catch (e) {
        last = e;
      }
    }
    throw last ?? const HttpException('assistant');
  }
}
