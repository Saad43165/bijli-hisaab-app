import 'package:flutter/material.dart';

import '../../core/constants/faq.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_ur.dart';
import '../../core/utils/formatters.dart';
import '../../services/bill_ocr_service.dart';
import '../../services/online_bill_service.dart';
import '../../services/appliance_planner.dart';
import '../home/widgets/advice_card.dart';
import '../home/widgets/bill_overview_card.dart';
import 'assistant_models.dart';
import 'assistant_tools.dart';

/// The built-in assistant: free, works offline, understands common requests
/// in English, Urdu and Roman Urdu, and can act on the app.
class LocalBrain implements AssistantBrain {
  LocalBrain(this.tools);

  final AssistantTools tools;

  /// Chat language chosen with "talk in Urdu" / "reply in English"; null =
  /// follow each message (Urdu script → Urdu, else the app language).
  String? chatLanguage;

  /// Language of the reply being built.
  bool _urdu = false;

  String _t(String key) => _urdu ? (urdu[key] ?? key) : key;
  String _tf(String key, Map<String, Object?> args) {
    var s = _t(key);
    args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
    return s;
  }

  static bool _has(String t, List<String> words) => words.any(t.contains);

  /// Whole words only ("due" must not match "reduce").
  static bool _word(String t, List<String> words) =>
      words.any((w) => RegExp('(^|[^a-z])${RegExp.escape(w)}(\$|[^a-z])').hasMatch(t));
  static final _urduScript = RegExp(r'[؀-ۿ]');

  /// Reply in Urdu for this message?
  bool replyUrdu(String input) =>
      chatLanguage != null ? chatLanguage == 'ur' : (_urduScript.hasMatch(input) || L10n.isUrdu);

  @override
  Future<AssistantReply> respond(String input, {String? imagePath, List<ChatMessage> history = const []}) async {
    _urdu = replyUrdu(input);
    if (imagePath != null) return _photo(imagePath);
    final t = ' ${input.toLowerCase().trim()} ';
    final state = tools.state;
    final question = RegExp(
      r'\b(why|how|should|explain|what is|what are|which|kyun|kyon|kaise|kesay|kya karun|kya karoon|batao|samjhao)\b|کیوں|کیسے|کیا کروں|بتائیں|سمجھائیں|\?|؟',
    ).hasMatch(t);

    // ----------------------------------------------- languages
    // "Talk in Urdu" changes only the chat; "change the app language to
    // Urdu" changes the whole app.
    final wantsUrdu = _has(t, ['urdu', 'اردو']);
    final wantsEnglish = _has(t, ['english', 'انگریزی', 'angrezi', 'inglish']);
    if (wantsUrdu || wantsEnglish) {
      final code = wantsUrdu && !wantsEnglish ? 'ur' : 'en';
      final appWide = _has(t, [
        'app', 'ایپ', 'language', 'zaban', 'zuban', 'زبان', 'setting', 'سیٹنگ', 'whole', 'poori', 'puri', 'پوری',
        'change', 'badal', 'بدل', 'switch', 'interface',
      ]);
      final chatOnly = _has(t, [
        'talk', 'speak', 'reply', 'answer', 'respond', 'chat', 'baat', 'bat kar', 'jawab', 'jwab', 'بات', 'جواب',
        'bolo', 'bol ', 'likho', 'لکھو', 'بولو', 'samjhao', 'سمجھاؤ',
      ]);
      if (appWide && !chatOnly) {
        await tools.setLanguage(code);
        chatLanguage = code;
        _urdu = code == 'ur';
        return AssistantReply(code == 'ur'
            ? 'پوری ایپ اب اردو میں ہے۔ میں آپ کی کیا مدد کروں؟'
            : 'The whole app is now in English. How can I help?');
      }
      if (chatOnly || t.trim().split(RegExp(r'\s+')).length <= 4) {
        chatLanguage = code;
        _urdu = code == 'ur';
        return AssistantReply(
          code == 'ur'
              ? 'ٹھیک ہے، اب میں اردو میں بات کروں گا۔ (پوری ایپ اردو میں چاہیے تو کہیں: "ایپ کی زبان اردو کریں")'
              : 'Sure, I\'ll reply in English now. (For the whole app, say "change app language to English".)',
          actions: [
            ReplyAction(code == 'ur' ? 'پوری ایپ اردو میں کریں' : 'Switch the whole app too', () async {
              await tools.setLanguage(code);
              return code == 'ur' ? 'پوری ایپ اب اردو میں ہے۔' : 'The whole app is now in English.';
            }),
          ],
        );
      }
    }
    if (_has(t, ['dark mode', 'dark theme', 'ڈارک'])) {
      await tools.setTheme('dark');
      return AssistantReply(_t('Dark mode is on.'));
    }
    if (_has(t, ['light mode', 'light theme', 'لائٹ موڈ'])) {
      await tools.setTheme('light');
      return AssistantReply(_t('Light mode is on.'));
    }

    // ----------------------------------------------- "I have 2 ACs, 5 fans and a motor"
    if (_has(t, ['have', ' hai', ' hain', 'paas', 'پاس', 'ہیں', 'ہے', 'add', 'shamil', 'شامل']) &&
        !_has(t, ['reading', 'ریڈنگ', 'meter ', 'bill'])) {
      final found = <(String, int)>[];
      for (final chunk in t.split(RegExp(r',|\band\b|\baur\b|اور|&'))) {
        final name = AssistantTools.applianceNamed(chunk);
        if (name == null) continue;
        final n = int.tryParse(RegExp(r'\d+').firstMatch(chunk)?.group(0) ?? '') ?? 1;
        found.add((name, n.clamp(1, 50)));
      }
      if (found.isNotEmpty) {
        for (final (name, n) in found) {
          await tools.addAppliance(name, quantity: n);
        }
        return AssistantReply(
          _tf('Saved: {0}. Open Appliances to see what each costs and where to save.', {'0': found.map((f) => '${_t(f.$1)} × ${f.$2}').join(', ')}),
          actions: [_go(_t('Open Appliances'), 'appliances')],
        );
      }
    }

    // ----------------------------------------------- add a meter (14 digits)
    final digits = input.replaceAll(RegExp(r'[\s-]'), '');
    final ref14 = RegExp(r'\d{14}').firstMatch(digits)?.group(0);
    if (ref14 != null) {
      final r = await tools.addMeterByReference(ref14);
      return AssistantReply(_localizeResult(r), actions: [_go(_t('Open Home'), 'home')]);
    }

    // ----------------------------------------------- add a reading
    final number = RegExp(r'(\d{3,6}(?:\.\d+)?)').firstMatch(input.replaceAll(',', ''))?.group(1);
    if (number != null && _has(t, ['reading', 'ریڈنگ', 'meter', 'میٹر', 'add', 'save', 'darj', 'likh', 'درج'])) {
      final r = await tools.addReading(double.parse(number));
      final s = state.summary;
      if (r.startsWith('Not saved')) {
        final before = state.readingBefore(DateTime.now());
        return AssistantReply(_tf('That\'s lower than your last reading ({0} on {1}). Check the digits and try again.', {'0': Fmt.whole(before?.value ?? 0), '1': before == null ? '' : Fmt.dayShort(before.date)}));
      }
      return AssistantReply(
        s != null && s.hasData
            ? _tf('Saved {0}. This month: {1} units so far, heading for {2} ≈ {3}.', {
                '0': Fmt.whole(double.parse(number)),
                '1': Fmt.whole(s.unitsUsed),
                '2': Fmt.whole(s.projectedUnits),
                '3': Fmt.rs(s.estimateProjected.total),
              })
            : _tf('Saved {0}. Add another reading in a few days and I\'ll show this month\'s units and warnings.', {'0': Fmt.whole(double.parse(number))}),
      );
    }

    // ----------------------------------------------- calculate
    final units = RegExp(r'(\d{1,4})\s*(units?|unit|یونٹ)').firstMatch(t)?.group(1);
    if (units != null && _has(t, ['calculat', 'kitna', 'kitne', 'how much', 'cost', 'hisab', 'حساب', 'کتنا', 'bill'])) {
      final n = int.parse(units);
      final e = state.estimateFor(n);
      if (e == null) return AssistantReply(_t('Set up your meter first.'));
      return AssistantReply(_tf('{0} units ≈ {1} with taxes ({2} per unit, all-in).', {'0': n, '1': Fmt.rs(e.total), '2': Fmt.rate(n == 0 ? 0 : e.total / n)}));
    }

    // ----------------------------------------------- fetch / scan
    final aboutBill = _has(t, ['bill', 'بل']);
    if (_has(t, ['fetch', 'download', 'new bill', 'naya bill', 'نیا بل', 'check bill', 'bill check', 'bill aya', 'bill aaya']) ||
        (aboutBill && _word(t, ['update', 'online', 'latest', 'refresh']))) {
      return _fetch();
    }
    if (_has(t, ['scan', 'photo', 'picture', 'camera', 'tasveer', 'تصویر', 'اسکین'])) {
      tools.openScreen('scan_bill');
      return AssistantReply(_t('Opening the bill scanner — point the camera at your bill.'));
    }

    // ----------------------------------------------- switch meter
    if (_has(t, ['switch', 'change meter', 'meter badlo', 'میٹر بدلیں'])) {
      for (final m in state.meters) {
        if (t.contains(m.name.toLowerCase())) {
          await tools.switchMeter(m.name);
          return AssistantReply(_tf('Switched to {0}.', {'0': m.name}));
        }
      }
      return AssistantReply(_t('Which meter?'), actions: [
        for (final m in state.meters)
          ReplyAction(m.name, () async {
            await tools.switchMeter(m.name);
            return _tf('Switched to {0}.', {'0': m.name});
          }),
      ]);
    }
    if (_has(t, ['add meter', 'another meter', 'new meter', 'dusra meter', 'دوسرا میٹر', 'نیا میٹر'])) {
      return AssistantReply(
        _t('Send me the 14-digit reference number from that meter\'s bill and I\'ll add it with all its bills.'),
        actions: [_go(_t('Add meter screen'), 'add_meter')],
      );
    }

    // ----------------------------------------------- "I paid my bill"
    if (_has(t, ['paid', 'pay kar diya', 'pay kr diya', 'jama kar', 'jama kr', 'jama karwa', 'bhar diya', 'ada kar', 'ادا کر', 'جمع کر'])) {
      final latest = state.bills.firstOrNull;
      if (latest == null) return AssistantReply(_t('I don\'t have a bill saved yet.'));
      await state.setBillPaid(latest, true);
      return AssistantReply(_tf('Marked your {0} bill as paid. I won\'t remind you about it again.', {'0': Fmt.month(latest.monthDate)}));
    }

    // ----------------------------------------------- "how do I pay less?"
    if (_has(t, [
          'save', 'saving', 'lower', 'reduce', 'cut ', 'pay less', 'plan', 'tips', 'bachat', 'bacha', 'بچت', 'بچا',
          'kam kar', 'kam ho', 'kam kaise', 'kam karna', 'کم کر', 'کم کیسے', 'tareeq', 'طریق',
        ]) &&
        !_word(t, ['reading'])) {
      return _plan();
    }

    // ----------------------------------------------- questions about my bill
    if (_has(t, ['next bill', 'agla bill', 'اگلا بل', 'predict', 'forecast', 'aglay', 'next month'])) {
      return _next();
    }
    if (_word(t, ['due', 'deadline']) || _has(t, ['last date', 'akhri', 'آخری تاریخ', 'kab tak', 'pay by'])) {
      return _due();
    }
    if (_has(t, ['this month', 'is mahine', 'اس مہینے', 'kitne unit', 'units so far', 'usage'])) {
      return _thisMonth();
    }
    if (_has(t, ['history', 'pichle', 'پچھلے', 'all bills', 'previous bills', 'last year'])) {
      return AssistantReply(_tf('{0}\n\n{1}', {'0': _t('Your bills:'), '1': tools.billHistory(12)}),
          actions: [_go(_t('Open History'), 'history')]);
    }
    if (_has(t, ['my bill', 'mera bill', 'میرا بل', 'bill kitna', 'how much is my bill', 'bill amount', 'kitna bill', 'bill kya'])) {
      return _bill();
    }
    if (_has(t, ['protected', 'protect', 'محفوظ', 'mehfooz', '200'])) {
      final p = _protected();
      return AssistantReply(p.text, actions: p.actions, canImprove: question);
    }

    // ----------------------------------------------- open a screen
    final screen = _screenFor(t);
    if (screen != null && _has(t, ['open', 'kholo', 'کھولیں', 'کھولو', 'go to', 'show', 'dikhao', 'دکھائیں', 'le chalo'])) {
      tools.openScreen(screen);
      return AssistantReply(_t('Opened.'));
    }

    // ----------------------------------------------- greetings / help
    if (_has(t, [' hi ', ' hello', 'salam', 'aoa', 'السلام', 'assalam', ' hey'])) {
      return AssistantReply(_hello(), canImprove: true);
    }
    if (_has(t, ['help', 'what can you', 'kya kar', 'madad', 'مدد'])) return AssistantReply(_hello(), canImprove: true);

    // ----------------------------------------------- FAQs
    final faq = _bestFaq(t);
    if (faq != null) return AssistantReply(_t(faq.answer), canImprove: true);

    if (screen != null) {
      tools.openScreen(screen);
      return AssistantReply(_t('Opened.'));
    }
    if (_has(t, ['bill', 'بل'])) {
      final b = _bill();
      return AssistantReply(b.text, actions: b.actions, canImprove: true);
    }

    return AssistantReply(
      _t('I\'m not sure what you mean. Try one of these, or ask in your own words:'),
      understood: false,
    );
  }

  // ------------------------------------------------------------ replies

  String _hello() => _t('Hi! I can tell you your bill and due date, predict the next one, fetch new bills, save a meter reading ("reading 12450"), work out a bill ("250 units kitna"), switch meters, open any screen, and answer questions about rates.');

  /// A personal plan to pay less: the biggest appliance savings in rupees,
  /// the most useful bill advice, and what to do first.
  AssistantReply _plan() {
    final state = tools.state;
    final rate = state.marginalRate;
    final ideas = AppliancePlanner.savings(state.appliances, rate, max: 3);
    final advice = AdviceCard.adviceFor(state)
        .where((a) => a.screen != 'bill_online' && a.screen != 'add_reading')
        .take(2)
        .toList();
    final lines = <String>[];
    var total = 0.0;
    for (final i in ideas) {
      total += i.rupees;
      lines.add('• ${_t(i.title)} — ${_tf('about {0} a month', {'0': Fmt.rs(i.rupees)})}');
    }
    for (final a in advice) {
      lines.add('• ${a.title}: ${a.body}');
    }
    if (lines.isEmpty) {
      lines.addAll([
        '• ${_t('AC at 26°C with a fan on — every degree lower adds about 6% to its bill.')}',
        '• ${_t('Run the water motor, iron and washing machine together, once a day.')}',
        '• ${_t('Switch off geysers and heaters as soon as the water or room is warm.')}',
      ]);
    }
    final head = _t('Here\'s your plan to pay less:');
    final foot = total > 0
        ? '\n\n${_tf('Together that\'s up to {0} a month.', {'0': Fmt.rs(total)})}'
        : state.appliances.isEmpty
            ? '\n\n${_t('Fill in your appliances and I\'ll work out the savings in rupees.')}'
            : '';
    return AssistantReply(
      '$head\n${lines.join('\n')}$foot',
      actions: [
        _go(_t('Open Appliances'), 'appliances'),
        _go(_t('Saving tips'), 'tips'),
      ],
    );
  }

  AssistantReply _bill() {
    final bills = tools.state.bills;
    if (bills.isEmpty) {
      return AssistantReply(_t('I don\'t have a bill yet. Shall I fetch it from your company\'s website?'),
          actions: [ReplyAction(_t('Fetch my bill'), () async => (await _fetch()).text)]);
    }
    final b = bills.first;
    final due = b.dueDate;
    final days = due == null ? null : DateUtils.dateOnly(due).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    final dueText = due == null
        ? ''
        : days! >= 0
            ? ' ${_tf('Due {0} ({1} days left).', {'0': Fmt.day(due), '1': days})}'
            : ' ${_tf('The due date ({0}) has passed.', {'0': Fmt.day(due)})}';
    return AssistantReply(
      _tf('Your {0} bill: {1} units{2}.{3}', {
        '0': Fmt.month(b.monthDate),
        '1': b.units,
        '2': b.amount > 0 ? ', ${Fmt.rs(b.amount)}' : '',
        '3': dueText,
      }),
      actions: [
        if (tools.state.company.billUrl != null) _go(_t('View full bill'), 'bill_online'),
        _go(_t('Open History'), 'history'),
      ],
    );
  }

  AssistantReply _due() {
    final b = tools.state.bills.firstOrNull;
    if (b?.dueDate == null) return _bill();
    return _bill();
  }

  AssistantReply _next() {
    final bills = tools.state.bills;
    final n = BillOverviewCard.nextUnits(bills);
    if (n == null) return AssistantReply(_t('I need at least one bill to predict the next one.'));
    final amt = tools.state.estimateFor(n)?.total;
    final next = DateTime(bills.first.monthDate.year, bills.first.monthDate.month + 1);
    final lastYear = bills.any((b) => b.monthDate == DateTime(next.year - 1, next.month));
    return AssistantReply(
      _tf('Next bill ({0}): about {1} units{2}. {3}', {
        '0': Fmt.month(next),
        '1': n,
        '2': amt == null ? '' : ' ≈ ${Fmt.rs(amt)}',
        '3': lastYear
            ? _t('Based on the same month last year.')
            : _t('Based on your last 3 bills.'),
      }),
    );
  }

  AssistantReply _thisMonth() {
    final s = tools.state.summary;
    if (s == null || !s.hasData) {
      return AssistantReply(
        _t('Live tracking is off — I need two meter readings this month. Tell me today\'s reading, like "reading 12450".'),
        actions: [_go(_t('Add reading'), 'add_reading')],
      );
    }
    return AssistantReply(
      _tf('This month: {0} units so far ({1} a day), heading for {2} ≈ {3}. You are {4}.', {
        '0': Fmt.whole(s.unitsUsed),
        '1': Fmt.oneDp(s.dailyRate),
        '2': Fmt.whole(s.projectedUnits),
        '3': Fmt.rs(s.estimateProjected.total),
        '4': _t(AssistantTools.statusWordEn(s.status)),
      }),
    );
  }

  AssistantReply _protected() {
    final p = tools.state.protection;
    final faq = _t(Faq.all.first.answer);
    if (p == null) return AssistantReply(faq);
    return AssistantReply(_tf('{0}\n\n{1}', {
      '0': p.consumerClass.hasProtection ? _t('You are on protected rates.') : _t('You are not on protected rates right now.'),
      '1': faq,
    }), actions: [_go(_t('Open History'), 'history')]);
  }

  Future<AssistantReply> _fetch() async {
    final state = tools.state;
    if (!state.canFetchOnlineBill) {
      return AssistantReply(
        OnlineBillService.supports(state.company)
            ? _t('Add this meter\'s reference number first (Tools → Meters).')
            : _tf('{0} bills aren\'t online — scan your bill instead.', {'0': state.company.shortCode}),
        actions: [_go(_t('Scan bill'), 'scan_bill')],
      );
    }
    try {
      final before = state.bills.length;
      final b = await state.fetchOnlineBill();
      final added = state.bills.length - before;
      return AssistantReply(
        _tf('Got your {0} bill: {1} units, {2}{3}. {4}', {
          '0': Fmt.month(b.month),
          '1': b.units,
          '2': Fmt.rs(b.amount),
          '3': b.dueDate == null ? '' : ', ${_tf('due {0}', {'0': Fmt.day(b.dueDate!)})}',
          '4': added > 0 ? _tf('Saved {0} new months.', {'0': added}) : _t('Your history was already up to date.'),
        }),
        actions: [_go(_t('View full bill'), 'bill_online')],
      );
    } on OnlineBillException catch (e) {
      return AssistantReply(_t(e.message));
    }
  }

  /// Reads a bill photo on the phone and says what it found.
  Future<AssistantReply> _photo(String path) async {
    try {
      final r = await BillOcrService().read([path], expectedCompany: tools.state.activeMeter?.disco);
      final a = r.analysis;
      final parts = <String>[
        if (a.disco != null) a.disco!,
        if (a.month?.value != null) Fmt.monthKeyLabel(a.month!.value),
        if (a.units?.value != null) _tf('{0} units', {'0': a.units!.value}),
        if (a.amount?.value != null) Fmt.rs(a.amount!.value),
        if (a.dueDate?.value != null) _tf('due {0}', {'0': Fmt.day(a.dueDate!.value)}),
      ];
      if (parts.isEmpty) {
        return AssistantReply(_t('I couldn\'t read that photo. Try again in good light, with the whole bill in view.'),
            actions: [_go(_t('Scan bill'), 'scan_bill')]);
      }
      return AssistantReply(
        _tf('From the photo: {0}. To save it, use the scanner so you can check each value.', {'0': parts.join(' · ')}),
        actions: [_go(_t('Scan & save'), 'scan_bill')],
      );
    } catch (e) {
      return AssistantReply(_t('I couldn\'t read that photo. Try again in good light, with the whole bill in view.'));
    }
  }

  // ------------------------------------------------------------ helpers

  ReplyAction _go(String label, String screen) => ReplyAction(label, () async {
        tools.openScreen(screen);
        return null;
      });

  static String? _screenFor(String t) {
    const map = {
      'history': 'history', 'ہسٹری': 'history', 'appliance': 'appliances', 'آلات': 'appliances',
      'tools': 'tools', 'ٹولز': 'tools', 'home': 'home', 'ہوم': 'home', 'scanner': 'scan_bill',
      'calculator': 'calculators', 'کیلکولیٹر': 'calculators', 'solar': 'solar_calculator', 'سولر': 'solar_calculator',
      'reminder': 'reminders', 'ریمائنڈر': 'reminders', 'rates': 'rates', 'tariff': 'rates', 'ریٹ': 'rates',
      'backup': 'backup', 'بیک اپ': 'backup', 'meters': 'meters', 'tips': 'tips', 'saving': 'tips',
      'readings': 'readings', 'help': 'help', 'guide': 'help',
    };
    for (final e in map.entries) {
      if (t.contains(e.key)) return e.value;
    }
    return null;
  }

  static Faq? _bestFaq(String t) {
    Faq? best;
    var score = 0;
    for (final f in Faq.all) {
      final s = f.keywords.where(t.contains).length;
      if (s > score) {
        score = s;
        best = f;
      }
    }
    return best;
  }

  /// Tool results are English (for the cloud model); show Urdu users a
  /// friendlier line when we have one.
  String _localizeResult(String r) => _t(r);
}
