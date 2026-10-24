import '../../core/utils/formatters.dart';

/// One saved bill, as the assistant needs it.
class BillFact {
  const BillFact({required this.month, required this.units, this.amount = 0, this.dueDate, this.paid = false});

  final DateTime month;
  final int units;
  final double amount;
  final DateTime? dueDate;
  final bool paid;
}

/// One appliance with its monthly cost.
class ApplianceFact {
  const ApplianceFact(this.name, this.units, this.rupees);

  final String name;
  final double units;
  final double rupees;
}

/// Everything the assistant knows about the user's electricity, as plain
/// values, so the common questions are answered from the app's own numbers
/// (and unit-tested) instead of guessed by an AI.
class CoreFacts {
  const CoreFacts({
    required this.today,
    this.hasMeter = true,
    this.disco,
    this.isTou = false,
    this.unitsSoFar,
    this.dailyRate,
    this.projectedUnits,
    this.projectedBill,
    this.projectedSlab,
    this.daysLeft,
    this.cycleEnd,
    this.targetLimit,
    this.safeDailyBudget,
    this.extraCostIfCrossed = 0,
    this.isProtected,
    this.isLifeline = false,
    this.protectedThreshold = 200,
    this.protectedMonths = 6,
    this.bills = const [],
    this.predictedUnits,
    this.predictedBill,
    this.fcaPerUnit = 0,
    this.fcaLabel = '',
    this.qtaPerUnit = 0,
    this.gstPercent = 18,
    this.marginalRate = 0,
    this.tariffName = '',
    this.protectedSlabs = const [],
    this.unprotectedSlabs = const [],
    this.appliances = const [],
    this.helpline,
    this.estimate,
  });

  final DateTime today;
  final bool hasMeter;

  /// Company short code, e.g. "LESCO".
  final String? disco;
  final bool isTou;

  // This cycle, from meter readings (null when live tracking is off).
  final double? unitsSoFar;
  final double? dailyRate;
  final double? projectedUnits;
  final double? projectedBill;
  final String? projectedSlab;
  final int? daysLeft;
  final DateTime? cycleEnd;

  /// The next slab limit worth staying under, and the units a day that keeps you there.
  final int? targetLimit;
  final double? safeDailyBudget;
  final double extraCostIfCrossed;

  /// null = not known yet (no meter).
  final bool? isProtected;
  final bool isLifeline;
  final int protectedThreshold;
  final int protectedMonths;

  /// Newest first.
  final List<BillFact> bills;
  final int? predictedUnits;
  final double? predictedBill;

  final double fcaPerUnit;
  final String fcaLabel;
  final double qtaPerUnit;
  final double gstPercent;

  /// What one more unit costs at this month's usage.
  final double marginalRate;
  final String tariffName;

  /// (slab label, Rs per unit).
  final List<(String, double)> protectedSlabs;
  final List<(String, double)> unprotectedSlabs;

  /// Biggest first.
  final List<ApplianceFact> appliances;
  final String? helpline;

  /// Bill total with taxes for a number of units, from the tariff calculator.
  final double? Function(int units)? estimate;

  bool get live => unitsSoFar != null && projectedUnits != null;
  BillFact? get lastBill => bills.isEmpty ? null : bills.first;

  /// Facts for the AI, in English. No meter name, reference number or
  /// address — only figures.
  String context() {
    final b = StringBuffer();
    if (!hasMeter) return 'No meter is set up in the app yet.';
    b.writeln('Company (DISCO): ${disco ?? 'unknown'}${isTou ? ', time-of-use (peak/off-peak) meter' : ''}.');
    if (live) {
      b.writeln('This billing cycle so far: ${Fmt.whole(unitsSoFar!)} units (${Fmt.oneDp(dailyRate ?? 0)} a day), '
          '${daysLeft ?? '?'} days left, heading for ${Fmt.whole(projectedUnits!)} units ≈ '
          '${Fmt.rs(projectedBill ?? 0)} with taxes${projectedSlab == null ? '' : ' (slab $projectedSlab)'}.');
      if (targetLimit != null) {
        b.writeln('Next limit to stay under: $targetLimit units'
            '${safeDailyBudget == null ? '' : ' (max ${Fmt.oneDp(safeDailyBudget!)} units a day)'}'
            '${extraCostIfCrossed > 0 ? '; crossing it adds about ${Fmt.rs(extraCostIfCrossed)}' : ''}.');
      }
    } else {
      b.writeln('No meter readings this cycle, so no live estimate.');
    }
    if (isProtected != null) {
      b.writeln(isLifeline
          ? 'Rate category: lifeline.'
          : isProtected!
              ? 'Rate category: protected (each of the last $protectedMonths bills was $protectedThreshold units or less).'
              : 'Rate category: unprotected (protected needs every one of the last $protectedMonths bills at '
                  '$protectedThreshold units or less).');
    }
    if (bills.isNotEmpty) {
      b.writeln('Recent bills: ${bills.take(6).map((x) => '${Fmt.monthKey(x.month)} ${x.units} units'
          '${x.amount > 0 ? ' ${Fmt.rs(x.amount)}' : ''}').join('; ')}.');
      final due = lastBill!.dueDate;
      if (due != null) b.writeln('Latest bill due date: ${Fmt.isoDate(due)}${lastBill!.paid ? ' (paid)' : ''}.');
    }
    if (predictedUnits != null) {
      b.writeln('Predicted next bill: about $predictedUnits units'
          '${predictedBill == null ? '' : ' ≈ ${Fmt.rs(predictedBill!)}'}.');
    }
    b.writeln('Tariff in the app: $tariffName. GST ${Fmt.oneDp(gstPercent)}%. '
        'FCA ${Fmt.rate(fcaPerUnit)} per unit${fcaLabel.isEmpty ? '' : ' ($fcaLabel)'}'
        '${qtaPerUnit != 0 ? ', QTA ${Fmt.rate(qtaPerUnit)} per unit' : ''}.');
    if (protectedSlabs.isNotEmpty) {
      b.writeln('Protected slab rates (Rs/unit before taxes): '
          '${protectedSlabs.map((s) => '${s.$1}: ${Fmt.twoDp(s.$2)}').join(', ')}.');
    }
    if (unprotectedSlabs.isNotEmpty) {
      b.writeln('Unprotected slab rates (Rs/unit before taxes): '
          '${unprotectedSlabs.map((s) => '${s.$1}: ${Fmt.twoDp(s.$2)}').join(', ')}.');
    }
    if (marginalRate > 0) b.writeln('One more unit costs about ${Fmt.rate(marginalRate)} at this usage.');
    if (appliances.isNotEmpty) {
      b.writeln('Biggest appliances: ${appliances.take(4).map((a) => '${a.name} ~${a.units.round()} units '
          '(${Fmt.rs(a.rupees)}) a month').join(', ')}.');
    }
    if (helpline != null) b.writeln('${disco ?? 'DISCO'} helpline: $helpline.');
    return b.toString().trim();
  }
}

enum CoreIntent {
  unitsCost,
  savingTips,
  billHigh,
  unitsLeft,
  protection,
  fca,
  tariff,
  appliances,
  daysLeft,
  dueDate,
  unitsSoFar,
  billEstimate,
  howTo,
}

/// A matched question: what it's about, plus a number of units if given.
class CoreMatch {
  const CoreMatch(this.intent, {this.units, this.appliance});

  final CoreIntent intent;
  final int? units;

  /// Words naming one appliance ("ac"), for "how much does my AC cost".
  final String? appliance;
}

/// The common questions, matched and answered on the phone from [CoreFacts].
class CoreAnswers {
  CoreAnswers._();

  static bool _has(String t, List<String> words) => words.any(t.contains);

  /// Whole words only ("due" must not match "reduce").
  static bool _word(String t, List<String> words) =>
      words.any((w) => RegExp('(^|[^a-z])${RegExp.escape(w)}(\$|[^a-z])').hasMatch(t));

  static const _applianceWords = [
    'ac', 'air conditioner', 'fan', 'pankha', 'پنکھ', 'fridge', 'refrigerator', 'فریج', 'motor', 'موٹر', 'iron',
    'استری', 'geyser', 'heater', 'tv', 'ٹی وی', 'cooler', 'washing', 'freezer', 'computer', 'pc', 'laptop', 'bulb',
    'light', 'microwave', 'oven', 'kettle', 'dispenser', 'ups',
  ];

  /// What a question is about, or null when it isn't one of the core ones.
  static CoreMatch? match(String input) {
    final t = ' ${input.toLowerCase().trim()} ';

    final units = RegExp(r'(\d{1,4})\s*(units?|یونٹ)').firstMatch(t)?.group(1);
    if (units != null &&
        _has(t, ['calculat', 'kitna', 'kitne', 'how much', 'cost', 'hisab', 'حساب', 'کتنا', 'bill', 'بل', 'price'])) {
      return CoreMatch(CoreIntent.unitsCost, units: int.parse(units));
    }
    if (_has(t, [
          'save', 'saving', 'reduce', 'lower my', 'lower the', 'pay less', 'tips', 'bachat', 'bachao', 'bachaun',
          'بچت', 'بچاؤ', 'بچاوں', 'kam kar', 'kam kaise', 'kam ho', 'kam karna', 'کم کر', 'کم کیسے', 'cut my', 'cut the',
        ]) &&
        !_word(t, ['reading'])) {
      return const CoreMatch(CoreIntent.savingTips);
    }
    if (_has(t, ['why', 'kyun', 'kyon', 'kiyon', 'کیوں']) &&
        _has(t, ['high', 'zyada', 'ziada', 'zayada', 'زیادہ', 'mehnga', 'expensive', 'so much', 'increase', 'barh', 'بڑھ'])) {
      return const CoreMatch(CoreIntent.billHigh);
    }
    if (_has(t, [
      'still use', 'units left', 'unit left', 'more units', 'remaining unit', 'how many units can', 'units can i',
      'unit bache', 'units bache', 'unit bachay', 'kitne aur', 'baqi', 'baaki', 'باقی', 'بچے', 'limit', 'حد',
      'stay under', 'cross',
    ])) {
      return const CoreMatch(CoreIntent.unitsLeft);
    }
    if (_has(t, ['protected', 'protect', 'mehfooz', 'mahfooz', 'محفوظ', 'lifeline', 'لائف لائن'])) {
      return const CoreMatch(CoreIntent.protection);
    }
    if (_word(t, ['fca', 'fpa']) || _has(t, ['fuel', 'ایف سی اے', 'فیول', 'adjustment'])) {
      return const CoreMatch(CoreIntent.fca);
    }
    if (_word(t, ['rate', 'rates', 'tariff', 'slab', 'slabs', 'gst', 'tax', 'taxes', 'reet', 'nepra']) ||
        _has(t, ['per unit', 'unit ka rate', 'unit price', 'ریٹ', 'ٹیرف', 'سلیب', 'ٹیکس', 'فی یونٹ'])) {
      return const CoreMatch(CoreIntent.tariff);
    }
    final named = _applianceWords.where((w) => RegExp('(^|[^a-z])${RegExp.escape(w)}([^a-z]|\$)').hasMatch(t)).firstOrNull;
    if (_has(t, [
          'biggest', 'power user', 'most power', 'uses most', 'use most', 'most electricity', 'most units', 'consum',
          'sab se zyada', 'sabse zyada', 'سب سے زیادہ', 'which appliance', 'appliance', 'آلات', 'آلہ',
        ]) ||
        (named != null && _has(t, ['cost', 'kharch', 'kitna', 'how much', 'کتنا', 'خرچ', 'units', 'یونٹ']))) {
      return CoreMatch(CoreIntent.appliances, appliance: named);
    }
    if (_has(t, ['days left', 'how many days', 'kitne din', 'din bache', 'din baqi', 'کتنے دن', 'دن باقی', 'reading day', 'cycle end', 'next reading'])) {
      return const CoreMatch(CoreIntent.daysLeft);
    }
    if (_word(t, ['due', 'deadline']) ||
        _has(t, ['last date', 'akhri tareekh', 'akhri tarikh', 'آخری تاریخ', 'pay by', 'kab tak', 'کب تک', 'when to pay', 'jama karwana'])) {
      return const CoreMatch(CoreIntent.dueDate);
    }
    if (_has(t, [
      'units so far', 'so far', 'this month', 'is mahine', 'is mahinay', 'اس مہینے', 'kitne unit', 'how many units',
      'units used', 'usage', 'استعمال', 'کتنے یونٹ',
    ])) {
      return const CoreMatch(CoreIntent.unitsSoFar);
    }
    if (_has(t, [
      'bill be', 'my bill', 'bill kitna', 'kitna bill', 'estimate', 'bill aayega', 'bill ayega', 'bill aye ga',
      'bill aaye', 'how much will', 'بل کتنا', 'اندازہ', 'projected', 'month end', 'mera bill', 'میرا بل', 'next bill',
      'agla bill', 'اگلا بل',
    ])) {
      return const CoreMatch(CoreIntent.billEstimate);
    }
    if (_has(t, ['how do i', 'how to', 'how can i', 'kaise', 'kese', 'کیسے', 'use the app', 'what can you do']) &&
        _has(t, ['reading', 'scan', 'meter', 'reminder', 'backup', 'appliance', 'widget', 'language', 'app', 'ریڈنگ', 'میٹر', 'اسکین', 'ایپ'])) {
      return const CoreMatch(CoreIntent.howTo);
    }
    return null;
  }

  /// The answer, worked out from [f]. null for [CoreIntent.savingTips],
  /// which the app builds from its appliance planner.
  static String? answer(CoreMatch m, CoreFacts f, {required bool urdu, String question = ''}) {
    String u(String en, String ur) => urdu ? ur : en;
    if (!f.hasMeter && m.intent != CoreIntent.howTo && m.intent != CoreIntent.tariff && m.intent != CoreIntent.fca) {
      return u('Set up your meter first (Tools → Meters), then I can work this out from your own numbers.',
          'پہلے اپنا میٹر شامل کریں (ٹولز ← میٹر)، پھر میں آپ کے اپنے نمبروں سے حساب بتا دوں گا۔');
    }
    final addReading = u('Add today\'s meter reading (say "reading 12450") for a live figure.',
        'اصل حساب کے لیے آج کی میٹر ریڈنگ درج کریں (مثلاً "ریڈنگ 12450")۔');
    switch (m.intent) {
      case CoreIntent.unitsCost:
        final n = m.units!;
        final total = f.estimate?.call(n);
        if (total == null) return u('Set up your meter first.', 'پہلے اپنا میٹر شامل کریں۔');
        return u(
          '$n units ≈ ${Fmt.rs(total)} with taxes (about ${Fmt.rate(n == 0 ? 0 : total / n)} per unit, all-in).',
          '$n یونٹ ≈ ${Fmt.rs(total)} ٹیکس سمیت (تقریباً ${Fmt.rate(n == 0 ? 0 : total / n)} فی یونٹ، سب ملا کر)۔',
        );

      case CoreIntent.savingTips:
        return null;

      case CoreIntent.billHigh:
        final bills = f.bills;
        if (bills.isEmpty) {
          return u('I need at least one saved bill to see why it\'s high. Fetch or scan your bill first.',
              'زیادہ بل کی وجہ دیکھنے کے لیے کم از کم ایک بل محفوظ ہونا چاہیے۔ پہلے اپنا بل لائیں یا اسکین کریں۔');
        }
        final last = bills.first;
        final prev = bills.skip(1).take(6).toList();
        final reasons = <String>[];
        if (prev.isNotEmpty) {
          final avg = prev.fold<int>(0, (a, b) => a + b.units) / prev.length;
          final diff = last.units - avg;
          reasons.add(diff > 10
              ? u('You used ${last.units} units, ${diff.round()} more than your average of ${avg.round()}.',
                  'آپ نے ${last.units} یونٹ استعمال کیے، جو آپ کی اوسط ${avg.round()} سے ${diff.round()} زیادہ ہیں۔')
              : u('Your ${last.units} units are close to your average of ${avg.round()}, so the rate is the main cause.',
                  'آپ کے ${last.units} یونٹ اوسط ${avg.round()} کے قریب ہیں، اس لیے اصل وجہ ریٹ ہے۔'));
        }
        if (f.isProtected == false && last.units <= f.protectedThreshold) {
          reasons.add(u('You are not on protected rates, so even ${last.units} units are charged at the higher unprotected rate.',
              'آپ محفوظ صارف نہیں ہیں، اس لیے ${last.units} یونٹ بھی مہنگے غیر محفوظ ریٹ پر لگے۔'));
        } else if (last.units > f.protectedThreshold) {
          reasons.add(u('Going above ${f.protectedThreshold} units puts the bill on unprotected rates.',
              '${f.protectedThreshold} یونٹ سے اوپر جانے پر بل غیر محفوظ ریٹ پر آ جاتا ہے۔'));
        }
        if (f.fcaPerUnit > 0) {
          reasons.add(u('The fuel adjustment (FCA) adds ${Fmt.rate(f.fcaPerUnit)} per unit.',
              'فیول ایڈجسٹمنٹ (FCA) فی یونٹ ${Fmt.rate(f.fcaPerUnit)} بڑھاتی ہے۔'));
        }
        if (f.appliances.isNotEmpty) {
          final a = f.appliances.first;
          reasons.add(u('Your biggest user is ${a.name}: about ${a.units.round()} units (${Fmt.rs(a.rupees)}) a month.',
              'سب سے زیادہ بجلی ${a.name} لیتا ہے: تقریباً ${a.units.round()} یونٹ (${Fmt.rs(a.rupees)}) ماہانہ۔'));
        }
        return reasons.take(4).join(' ');

      case CoreIntent.unitsLeft:
        if (!f.live) return '${u('I need two meter readings this cycle to know how many units you have left.', 'باقی یونٹ جاننے کے لیے اس مہینے کی دو میٹر ریڈنگز چاہئیں۔')} $addReading';
        final limit = f.targetLimit;
        if (limit == null) {
          return u('You\'ve used ${Fmt.whole(f.unitsSoFar!)} units and are already in the highest slab, so there is no cheaper limit left to protect this month.',
              'آپ ${Fmt.whole(f.unitsSoFar!)} یونٹ استعمال کر چکے ہیں اور سب سے اونچے سلیب میں ہیں، اس مہینے بچانے کو کوئی سستی حد باقی نہیں۔');
        }
        final left = (limit - f.unitsSoFar!).clamp(0, 99999);
        final days = f.daysLeft ?? 0;
        final perDay = f.safeDailyBudget ?? (days > 0 ? left / days : left.toDouble());
        final cross = f.extraCostIfCrossed > 0
            ? u(' Crossing it would add about ${Fmt.rs(f.extraCostIfCrossed)}.', ' اس سے اوپر جانے پر تقریباً ${Fmt.rs(f.extraCostIfCrossed)} زیادہ لگیں گے۔')
            : '';
        if (left <= 0) {
          return u('You\'ve already passed $limit units (${Fmt.whole(f.unitsSoFar!)} so far).$cross',
              'آپ $limit یونٹ کی حد پار کر چکے ہیں (اب تک ${Fmt.whole(f.unitsSoFar!)})۔$cross');
        }
        return u(
          'You can use ${Fmt.whole(left)} more units to stay under $limit — about ${Fmt.oneDp(perDay)} a day for the $days days left.$cross',
          '$limit کی حد میں رہنے کے لیے آپ مزید ${Fmt.whole(left)} یونٹ استعمال کر سکتے ہیں — باقی $days دنوں میں روزانہ تقریباً ${Fmt.oneDp(perDay)}۔$cross',
        );

      case CoreIntent.protection:
        final rule = u(
          'Protected rates need every one of your last ${f.protectedMonths} bills at ${f.protectedThreshold} units or less.',
          'محفوظ ریٹ کے لیے پچھلے ${f.protectedMonths} مہینوں کا ہر بل ${f.protectedThreshold} یونٹ یا کم ہونا چاہیے۔',
        );
        if (f.isProtected == null) return rule;
        final over = f.bills.take(f.protectedMonths).where((b) => b.units > f.protectedThreshold).toList();
        final head = f.isLifeline
            ? u('You are on lifeline rates.', 'آپ لائف لائن ریٹ پر ہیں۔')
            : f.isProtected!
                ? u('Yes, you are on protected rates.', 'جی ہاں، آپ محفوظ (پروٹیکٹڈ) ریٹ پر ہیں۔')
                : u('No, you are not on protected rates right now.', 'نہیں، آپ ابھی محفوظ ریٹ پر نہیں ہیں۔');
        final parts = [head, rule];
        if (f.isProtected == false && over.isNotEmpty) {
          final o = over.first;
          parts.add(u('Your ${Fmt.month(o.month)} bill had ${o.units} units.', 'آپ کے ${Fmt.month(o.month)} کے بل میں ${o.units} یونٹ تھے۔'));
        }
        if (f.isProtected == true && f.live && f.projectedUnits! > f.protectedThreshold) {
          parts.add(u('Careful: you are heading for ${Fmt.whole(f.projectedUnits!)} units this month, which would end it.',
              'خیال رکھیں: اس مہینے آپ ${Fmt.whole(f.projectedUnits!)} یونٹ کی طرف جا رہے ہیں، جس سے یہ ختم ہو جائے گا۔'));
        }
        return parts.join(' ');

      case CoreIntent.fca:
        if (f.fcaPerUnit == 0) {
          return u('There is no fuel adjustment (FCA) in the app\'s tariff right now. Check the "FPA" line on your bill for the exact amount.',
              'ایپ کے ٹیرف میں ابھی کوئی فیول ایڈجسٹمنٹ (FCA) نہیں۔ صحیح رقم کے لیے اپنے بل پر "FPA" والی لائن دیکھیں۔');
        }
        final sign = f.fcaPerUnit > 0 ? u('adds', 'بڑھاتی') : u('takes off', 'کم کرتی');
        final on = f.lastBill?.units ?? f.projectedUnits?.round();
        final effect = on == null
            ? ''
            : u(' On $on units that\'s about ${Fmt.rs((f.fcaPerUnit * on).abs())}.',
                ' $on یونٹ پر یہ تقریباً ${Fmt.rs((f.fcaPerUnit * on).abs())} بنتی ہے۔');
        return u(
          'The fuel adjustment (FCA${f.fcaLabel.isEmpty ? '' : ', ${f.fcaLabel}'}) $sign ${Fmt.rate(f.fcaPerUnit.abs())} per unit.$effect Protected users under 200 units usually don\'t pay it.',
          'فیول ایڈجسٹمنٹ (FCA${f.fcaLabel.isEmpty ? '' : '، ${f.fcaLabel}'}) فی یونٹ ${Fmt.rate(f.fcaPerUnit.abs())} $sign ہے۔$effect 200 یونٹ سے کم والے محفوظ صارفین عموماً یہ ادا نہیں کرتے۔',
        );

      case CoreIntent.tariff:
        final slabs = f.isProtected == true ? f.protectedSlabs : f.unprotectedSlabs;
        final which = f.isProtected == true ? u('protected', 'محفوظ') : u('unprotected', 'غیر محفوظ');
        final list = slabs.take(6).map((s) => '${s.$1}: ${Fmt.rate(s.$2)}').join(urdu ? '، ' : ', ');
        final now = f.marginalRate > 0
            ? u(' At your usage, one more unit costs about ${Fmt.rate(f.marginalRate)} before taxes.',
                ' آپ کے استعمال پر ایک اور یونٹ ٹیکس سے پہلے تقریباً ${Fmt.rate(f.marginalRate)} کا پڑتا ہے۔')
            : '';
        return u(
          'Your $which slab rates per unit (before taxes): $list.$now GST is ${Fmt.oneDp(f.gstPercent)}% on top.',
          'آپ کے $which سلیب ریٹ فی یونٹ (ٹیکس سے پہلے): $list۔$now اس کے اوپر ${Fmt.oneDp(f.gstPercent)}% جی ایس ٹی ہے۔',
        );

      case CoreIntent.appliances:
        if (f.appliances.isEmpty) {
          return u('You haven\'t added appliances yet. Tell me what you have, like "2 ACs, 5 fans and a fridge", and I\'ll work out what each costs.',
              'آپ نے ابھی آلات شامل نہیں کیے۔ مجھے بتائیں، جیسے "2 اے سی، 5 پنکھے اور ایک فریج"، میں ہر ایک کا خرچ بتا دوں گا۔');
        }
        final want = m.appliance;
        if (want != null && !_has(question.toLowerCase(), ['biggest', 'most', 'zyada', 'زیادہ'])) {
          final a = f.appliances.where((x) => _matchesAppliance(x.name, want)).firstOrNull;
          if (a != null) {
            return u('${a.name}: about ${a.units.round()} units a month, roughly ${Fmt.rs(a.rupees)} on your bill.',
                '${a.name}: تقریباً ${a.units.round()} یونٹ ماہانہ، آپ کے بل پر لگ بھگ ${Fmt.rs(a.rupees)}۔');
          }
        }
        final top = f.appliances.take(3).toList();
        final total = f.appliances.fold<double>(0, (s, a) => s + a.units);
        final first = top.first;
        final share = total <= 0 ? 0 : (first.units / total * 100).round();
        final rest = top.skip(1).map((a) => '${a.name} ~${a.units.round()}').join(urdu ? '، ' : ', ');
        return u(
          'Your biggest power user is ${first.name}: about ${first.units.round()} units (${Fmt.rs(first.rupees)}) a month, $share% of your appliances.${rest.isEmpty ? '' : ' Next: $rest units.'}',
          'سب سے زیادہ بجلی ${first.name} استعمال کرتا ہے: تقریباً ${first.units.round()} یونٹ (${Fmt.rs(first.rupees)}) ماہانہ، یعنی آلات کا $share%۔${rest.isEmpty ? '' : ' اس کے بعد: $rest یونٹ۔'}',
        );

      case CoreIntent.daysLeft:
        if (f.daysLeft == null) return '${u('I need meter readings to know your billing cycle.', 'بلنگ سائیکل جاننے کے لیے میٹر ریڈنگز چاہئیں۔')} $addReading';
        return u(
          '${f.daysLeft} days are left in this billing cycle${f.cycleEnd == null ? '' : ' (next reading around ${Fmt.dayShort(f.cycleEnd!)})'}.',
          'اس بلنگ سائیکل میں ${f.daysLeft} دن باقی ہیں${f.cycleEnd == null ? '' : ' (اگلی ریڈنگ تقریباً ${Fmt.dayShort(f.cycleEnd!)})'}۔',
        );

      case CoreIntent.dueDate:
        final b = f.lastBill;
        if (b == null) return u('I don\'t have a bill saved yet. Fetch or scan your bill first.', 'ابھی کوئی بل محفوظ نہیں۔ پہلے اپنا بل لائیں یا اسکین کریں۔');
        final due = b.dueDate;
        if (due == null) {
          return u('Your ${Fmt.month(b.month)} bill has no due date saved. It\'s printed on the bill under "Due Date".',
              'آپ کے ${Fmt.month(b.month)} کے بل کی آخری تاریخ محفوظ نہیں۔ یہ بل پر "Due Date" کے نیچے لکھی ہوتی ہے۔');
        }
        final days = DateTime(due.year, due.month, due.day).difference(DateTime(f.today.year, f.today.month, f.today.day)).inDays;
        final amt = b.amount > 0 ? ' (${Fmt.rs(b.amount)})' : '';
        if (b.paid) return u('Your ${Fmt.month(b.month)} bill$amt is marked paid.', 'آپ کا ${Fmt.month(b.month)} کا بل$amt ادا شدہ ہے۔');
        if (days < 0) {
          return u('Your ${Fmt.month(b.month)} bill$amt was due on ${Fmt.day(due)}, ${-days} days ago. A late surcharge (about 10%) may apply.',
              'آپ کے ${Fmt.month(b.month)} کے بل$amt کی آخری تاریخ ${Fmt.day(due)} تھی، ${-days} دن پہلے۔ لیٹ سرچارج (تقریباً 10%) لگ سکتا ہے۔');
        }
        return u('Your ${Fmt.month(b.month)} bill$amt is due on ${Fmt.day(due)} — ${days == 0 ? 'today' : '$days days left'}.',
            'آپ کے ${Fmt.month(b.month)} کے بل$amt کی آخری تاریخ ${Fmt.day(due)} ہے — ${days == 0 ? 'آج' : '$days دن باقی'}۔');

      case CoreIntent.unitsSoFar:
        if (!f.live) {
          final b = f.lastBill;
          final last = b == null
              ? ''
              : u(' Your last bill (${Fmt.month(b.month)}) was ${b.units} units.', ' آپ کا پچھلا بل (${Fmt.month(b.month)}) ${b.units} یونٹ تھا۔');
          return '${u('Live tracking is off — I need two meter readings this cycle.', 'لائیو ٹریکنگ بند ہے — اس مہینے کی دو میٹر ریڈنگز چاہئیں۔')}$last $addReading';
        }
        return u(
          'You\'ve used ${Fmt.whole(f.unitsSoFar!)} units so far this cycle (${Fmt.oneDp(f.dailyRate ?? 0)} a day), heading for about ${Fmt.whole(f.projectedUnits!)} by the end.',
          'اس سائیکل میں اب تک ${Fmt.whole(f.unitsSoFar!)} یونٹ استعمال ہوئے (روزانہ ${Fmt.oneDp(f.dailyRate ?? 0)})، آخر تک تقریباً ${Fmt.whole(f.projectedUnits!)} یونٹ ہوں گے۔',
        );

      case CoreIntent.billEstimate:
        if (f.live && f.projectedBill != null) {
          return u(
            'At your current pace you\'re heading for about ${Fmt.whole(f.projectedUnits!)} units, so this bill should be about ${Fmt.rs(f.projectedBill!)} with taxes${f.projectedSlab == null ? '' : ' (slab ${f.projectedSlab})'}. ${f.daysLeft ?? 0} days are left.',
            'موجودہ رفتار سے آپ تقریباً ${Fmt.whole(f.projectedUnits!)} یونٹ کی طرف جا رہے ہیں، اس لیے یہ بل ٹیکس سمیت تقریباً ${Fmt.rs(f.projectedBill!)} ہوگا${f.projectedSlab == null ? '' : ' (سلیب ${f.projectedSlab})'}۔ ${f.daysLeft ?? 0} دن باقی ہیں۔',
          );
        }
        if (f.predictedUnits != null) {
          final amt = f.predictedBill == null ? '' : ' ≈ ${Fmt.rs(f.predictedBill!)}';
          return u('From your past bills, the next one should be about ${f.predictedUnits} units$amt with taxes. $addReading',
              'آپ کے پچھلے بلوں کے حساب سے اگلا بل تقریباً ${f.predictedUnits} یونٹ$amt ٹیکس سمیت ہوگا۔ $addReading');
        }
        final b = f.lastBill;
        if (b != null) {
          return u('Your last bill (${Fmt.month(b.month)}) was ${b.units} units${b.amount > 0 ? ', ${Fmt.rs(b.amount)}' : ''}. $addReading',
              'آپ کا پچھلا بل (${Fmt.month(b.month)}) ${b.units} یونٹ${b.amount > 0 ? '، ${Fmt.rs(b.amount)}' : ''} تھا۔ $addReading');
        }
        return '${u('I don\'t have a bill or readings yet.', 'ابھی کوئی بل یا ریڈنگ نہیں۔')} $addReading';

      case CoreIntent.howTo:
        final t = question.toLowerCase();
        if (_has(t, ['reading', 'ریڈنگ'])) {
          return u('Tap + on Home → Add reading, type the number on your meter (or use the camera). Or just tell me "reading 12450".',
              'ہوم پر + دبائیں ← ریڈنگ درج کریں، میٹر کا نمبر لکھیں (یا کیمرہ استعمال کریں)۔ یا مجھے کہیں "ریڈنگ 12450"۔');
        }
        if (_has(t, ['scan', 'اسکین'])) {
          return u('Tap the scanner button below or say "scan my bill", then point the camera at the whole bill. Check the values and tap Save.',
              'نیچے اسکینر بٹن دبائیں یا کہیں "میرا بل اسکین کرو"، پھر کیمرہ پورے بل پر رکھیں۔ نمبر چیک کریں اور محفوظ کریں۔');
        }
        if (_has(t, ['meter', 'میٹر'])) {
          return u('Go to Tools → Meters → Add meter, or send me the 14-digit reference number from the bill and I\'ll add it with its bills.',
              'ٹولز ← میٹر ← میٹر شامل کریں پر جائیں، یا بل کا 14 ہندسوں والا ریفرنس نمبر مجھے بھیجیں، میں بلوں سمیت شامل کر دوں گا۔');
        }
        if (_has(t, ['reminder', 'ریمائنڈر'])) {
          return u('Open Tools → Reminders and turn on Smart reminders. You\'ll get slab warnings, reading-day and due-date alerts.',
              'ٹولز ← ریمائنڈرز کھولیں اور سمارٹ ریمائنڈرز آن کریں۔ آپ کو سلیب، ریڈنگ ڈے اور آخری تاریخ کے الرٹ ملیں گے۔');
        }
        if (_has(t, ['backup'])) {
          return u('Open Tools → Backup to save your data to a file or Google Drive, and restore it on a new phone.',
              'ٹولز ← بیک اپ کھولیں، اپنا ڈیٹا فائل یا گوگل ڈرائیو میں محفوظ کریں اور نئے فون پر واپس لائیں۔');
        }
        return u('Add your meter, then save a meter reading every few days. Home shows your units, estimated bill and slab warnings; History has past bills; Appliances shows what each one costs. Ask me anything about your bill.',
            'اپنا میٹر شامل کریں، پھر ہر چند دن بعد میٹر ریڈنگ درج کریں۔ ہوم پر یونٹ، اندازاً بل اور سلیب وارننگ، ہسٹری میں پچھلے بل، اور آلات میں ہر ایک کا خرچ نظر آتا ہے۔ اپنے بل کے بارے میں کچھ بھی پوچھیں۔');
    }
  }

  static bool _matchesAppliance(String name, String word) {
    final n = name.toLowerCase();
    return switch (word) {
      'ac' || 'air conditioner' => n.startsWith('ac') || n.contains('air con'),
      'fan' || 'pankha' || 'پنکھ' => n.contains('fan'),
      'fridge' || 'refrigerator' || 'فریج' => n.contains('refrigerator') || n.contains('fridge'),
      'motor' || 'موٹر' => n.contains('motor') || n.contains('pump'),
      'iron' || 'استری' => n.contains('iron'),
      'tv' || 'ٹی وی' => n.contains('tv'),
      'pc' || 'computer' => n.contains('pc') || n.contains('computer'),
      'bulb' || 'light' => n.contains('bulb') || n.contains('light'),
      _ => n.contains(word),
    };
  }
}
