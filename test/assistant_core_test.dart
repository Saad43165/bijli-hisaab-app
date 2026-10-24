import 'package:bijli_bachao/features/assistant/ai_guard.dart';
import 'package:bijli_bachao/features/assistant/core_answers.dart';
import 'package:flutter_test/flutter_test.dart';

CoreIntent? intent(String q) => CoreAnswers.match(q)?.intent;

final live = CoreFacts(
  today: DateTime(2026, 10, 24),
  disco: 'LESCO',
  unitsSoFar: 142,
  dailyRate: 7.1,
  projectedUnits: 213,
  projectedBill: 9876,
  projectedSlab: '201–300',
  daysLeft: 10,
  cycleEnd: DateTime(2026, 11, 3),
  targetLimit: 200,
  safeDailyBudget: 5.8,
  extraCostIfCrossed: 2400,
  isProtected: true,
  bills: [
    BillFact(month: DateTime(2026, 9), units: 180, amount: 5200, dueDate: DateTime(2026, 10, 28)),
    BillFact(month: DateTime(2026, 8), units: 195, amount: 5600),
  ],
  fcaPerUnit: 1.25,
  fcaLabel: 'Sep 2026',
  gstPercent: 18,
  marginalRate: 22.44,
  protectedSlabs: const [('1–100', 10.54), ('101–200', 13.01)],
  unprotectedSlabs: const [('1–100', 22.44), ('101–200', 28.91)],
  appliances: const [
    ApplianceFact('AC 1.5 ton (inverter)', 180, 4039),
    ApplianceFact('Refrigerator', 45, 1010),
    ApplianceFact('Ceiling fan', 40, 898),
  ],
  helpline: '118',
  estimate: (n) => n * 30.0,
);

void main() {
  group('intent matching', () {
    test('the suggestion chips', () {
      expect(intent('How much will my bill be?'), CoreIntent.billEstimate);
      expect(intent('How many units can I still use?'), CoreIntent.unitsLeft);
      expect(intent('Am I protected?'), CoreIntent.protection);
      expect(intent('Biggest power user?'), CoreIntent.appliances);
      expect(intent('How to save?'), CoreIntent.savingTips);
      expect(intent('میرا بل کتنا آئے گا؟'), CoreIntent.billEstimate);
      expect(intent('کتنے یونٹ باقی ہیں؟'), CoreIntent.unitsLeft);
      expect(intent('کیا میں محفوظ صارف ہوں؟'), CoreIntent.protection);
      expect(intent('سب سے زیادہ بجلی کون استعمال کرتا ہے؟'), CoreIntent.appliances);
      expect(intent('بجلی کیسے بچاؤں؟'), CoreIntent.savingTips);
    });

    test('English, Roman Urdu and Urdu', () {
      expect(intent('250 units kitna bill?'), CoreIntent.unitsCost);
      expect(CoreAnswers.match('300 units cost')?.units, 300);
      expect(intent('mera bill kitna aayega'), CoreIntent.billEstimate);
      expect(intent('میرا بل کتنا آئے گا'), CoreIntent.billEstimate);
      expect(intent('kitne unit bache hain'), CoreIntent.unitsLeft);
      expect(intent('کیا میں محفوظ صارف ہوں'), CoreIntent.protection);
      expect(intent('FCA kitna hai'), CoreIntent.fca);
      expect(intent('what is the rate per unit'), CoreIntent.tariff);
      expect(intent('When is my bill due?'), CoreIntent.dueDate);
      expect(intent('units so far this month'), CoreIntent.unitsSoFar);
      expect(intent('how many days left'), CoreIntent.daysLeft);
      expect(intent('why is my bill so high'), CoreIntent.billHigh);
      expect(intent('bijli ka bill kam kaise karun'), CoreIntent.savingTips);
      expect(intent('how much does my AC cost'), CoreIntent.appliances);
      expect(intent('how do I add a reading'), CoreIntent.howTo);
    });

    test('"reduce" is about saving, not the due date', () {
      expect(intent('how to reduce my bill'), CoreIntent.savingTips);
    });

    test('off-topic questions are not matched', () {
      expect(intent('who won the cricket match'), isNull);
      expect(intent('write me a poem'), isNull);
    });
  });

  group('answers from the app numbers', () {
    String ans(String q, {bool urdu = false, CoreFacts? f}) =>
        CoreAnswers.answer(CoreAnswers.match(q)!, f ?? live, urdu: urdu, question: q)!;

    test('bill estimate uses the projection', () {
      final a = ans('How much will my bill be?');
      expect(a, contains('213 units'));
      expect(a, contains('Rs 9,876'));
      expect(a, contains('201–300'));
    });

    test('units left to the next limit, per day', () {
      final a = ans('How many units can I still use?');
      expect(a, contains('58 more units'));
      expect(a, contains('200'));
      expect(a, contains('5.8 a day'));
      expect(a, contains('Rs 2,400'));
    });

    test('protected, with a warning when the month will end it', () {
      final a = ans('Am I protected?');
      expect(a, startsWith('Yes'));
      expect(a, contains('213 units'));
    });

    test('units cost comes from the tariff calculator', () {
      expect(ans('250 units kitna bill?'), contains('Rs 7,500'));
    });

    test('biggest appliance with its share', () {
      final a = ans('Biggest power user?');
      expect(a, contains('AC 1.5 ton (inverter)'));
      expect(a, contains('Rs 4,039'));
      expect(a, contains('68%'));
    });

    test('one appliance by name', () {
      expect(ans('how much does my fridge cost'), contains('Refrigerator: about 45 units'));
    });

    test('due date in days', () {
      expect(ans('When is my bill due?'), contains('4 days left'));
    });

    test('FCA effect on the last bill', () {
      expect(ans('FCA kitna hai'), contains('Rs 1.25 per unit'));
      expect(ans('FCA kitna hai'), contains('Rs 225'));
    });

    test('Urdu replies', () {
      final a = ans('میرا بل کتنا آئے گا', urdu: true);
      expect(a, contains('Rs 9,876'));
      expect(RegExp(r'[؀-ۿ]').hasMatch(a), isTrue);
    });

    test('without readings it asks for one instead of guessing', () {
      final f = CoreFacts(today: DateTime(2026, 10, 24), isProtected: false);
      expect(ans('How many units can I still use?', f: f), contains('reading'));
      expect(ans('How much will my bill be?', f: f), contains('reading'));
    });

    test('no meter: set one up first', () {
      final f = CoreFacts(today: DateTime(2026, 10, 24), hasMeter: false);
      expect(ans('Am I protected?', f: f), contains('Set up your meter'));
    });

    test('AI context has figures but no meter name or reference', () {
      final c = live.context();
      expect(c, contains('LESCO'));
      expect(c, contains('Rs 9,876'));
      expect(c, contains('Protected slab rates'));
    });
  });

  group('follow-ups use the conversation', () {
    /// Resolves each line against the one before, like the chat does.
    List<CoreMatch?> chain(List<String> lines) {
      CoreMatch? last;
      return [
        for (final l in lines) last = CoreAnswers.resolve(l, last) ?? last,
      ];
    }

    String ans(CoreMatch m, String q, {bool urdu = false}) => CoreAnswers.answer(m, live, urdu: urdu, question: q)!;

    test('English: appliance, then another, then why/how much', () {
      final c = chain(['Biggest power user?', 'and the fan?', 'what about the fridge?']);
      expect(c[1]!.intent, CoreIntent.appliances);
      expect(ans(c[1]!, 'and the fan?'), contains('Ceiling fan: about 40 units'));
      expect(ans(c[2]!, 'what about the fridge?'), contains('Refrigerator: about 45 units'));
    });

    test('English: estimate → why? → last month → the month before', () {
      final c = chain(['How much will my bill be?', 'why?', 'what about last month?', 'and the month before?']);
      expect(c[1]!.intent, CoreIntent.billHigh);
      expect(c[2]!.intent, CoreIntent.lastBill);
      expect(ans(c[2]!, ''), contains('180 units'));
      expect(c[3]!.monthsBack, 1);
      expect(ans(c[3]!, ''), contains('195 units'));
    });

    test('units left → how much would that cost?', () {
      final c = chain(['How many units can I still use?', 'how much would that cost?']);
      expect(c[1]!.intent, CoreIntent.billEstimate);
    });

    test('Roman Urdu: 250 units kitna → aur 300? → isko kam kaise karun', () {
      final c = chain(['250 units kitna bill?', 'aur 300?', 'isko kam kaise karun']);
      expect(c[1]!.units, 300);
      expect(ans(c[1]!, 'aur 300?'), contains('Rs 9,000'));
      expect(c[2]!.intent, CoreIntent.savingTips);
    });

    test('Roman Urdu: aur AC ka? → kitna?', () {
      final c = chain(['sab se zyada bijli kaun use karta', 'aur AC ka?', 'kitna?']);
      expect(c[1]!.appliance, 'ac');
      expect(c[2]!.appliance, 'ac');
      expect(ans(c[2]!, 'kitna?'), contains('AC 1.5 ton (inverter): about 180 units'));
    });

    test('Urdu: estimate → کیوں؟ → پچھلے مہینے کا؟', () {
      final c = chain(['میرا بل کتنا آئے گا؟', 'کیوں؟', 'پچھلے مہینے کا؟']);
      expect(c[1]!.intent, CoreIntent.billHigh);
      expect(c[2]!.intent, CoreIntent.lastBill);
      expect(ans(c[2]!, '', urdu: true), contains('180'));
    });

    test('a new question is not swallowed by the old topic', () {
      final c = chain(['Biggest power user?', 'Am I protected?']);
      expect(c[1]!.intent, CoreIntent.protection);
    });

    test('long unrelated messages are not follow-ups', () {
      expect(CoreAnswers.resolve('tell me a long story about cricket and football please', const CoreMatch(CoreIntent.fca)),
          isNull);
    });
  });

  group('AI reply guard', () {
    final ctx = live.context();

    test('strips markdown and filler, caps length', () {
      final r = AiGuard.check(
        'Sure! **Net metering** lets you sell solar units back to LESCO.\n\n- It needs a bidirectional meter.\n'
        'The DISCO checks your system first. Approval takes a few weeks. You then get credit on the bill. '
        'Credits are adjusted monthly. Extra sentence here about meters. I hope this helps!',
        context: ctx,
      )!;
      expect(r, isNot(contains('**')));
      expect(r, isNot(startsWith('Sure')));
      expect(r, isNot(contains('hope this helps')));
      expect(RegExp(r'[.!?]').allMatches(r).length, lessThanOrEqualTo(AiGuard.maxSentences));
    });

    test('rejects made-up rupee amounts', () {
      expect(AiGuard.check('Your bill will be about Rs 14,500 this month.', context: ctx), isNull);
      expect(AiGuard.check('Your bill should be about Rs 9,876 this month.', context: ctx), isNotNull);
    });

    test('rejects generic and off-topic replies', () {
      expect(AiGuard.check('Rates vary, so contact your local utility for details.', context: ctx), isNull);
      expect(AiGuard.check('The capital of France is Paris.', context: ctx), isNull);
    });

    test('a polite refusal is allowed', () {
      expect(AiGuard.check('Sorry, I can only help with electricity bills.', context: ctx), isNotNull);
    });
  });
}
