/// Questions people ask about electricity bills in Pakistan, with short
/// answers. Used by the Guide screen and the assistant. English is the key;
/// Urdu comes from the strings table like everything else.
class Faq {
  const Faq(this.question, this.answer, this.keywords);

  final String question;
  final String answer;

  /// Lower-case words (English, Roman Urdu, Urdu) that point to this answer.
  final List<String> keywords;

  static const all = <Faq>[
    Faq(
      'What are protected rates?',
      'If each of your last 6 bills was 200 units or less, you\'re a "protected" consumer and pay much lower rates. One bill above 200 units ends that for the next 6 months — so watching the 200-unit line saves the most money.',
      ['protected', 'unprotected', '200', 'protect', 'mehfooz', 'محفوظ'],
    ),
    Faq(
      'Where is my reference number?',
      'It\'s the 14-digit number at the top of your bill, labelled "Reference No", for example 06 14562 1211000. Ignore the letter (U or R) after it.',
      ['reference', 'ref', 'refrence', 'number', 'ریفرنس', 'نمبر'],
    ),
    Faq(
      'Why is my bill so high?',
      'Usually three things: more units in summer (AC, motor, fridge), crossing a slab (one extra unit can make every unit dearer), and the monthly fuel adjustment (FCA) and taxes. Open History to see which months jumped, and Appliances to see what uses the most.',
      ['high', 'zyada', 'ziada', 'mehnga', 'expensive', 'why', 'kyun', 'زیادہ', 'مہنگا'],
    ),
    Faq(
      'What is a slab?',
      'Rates go up in steps (slabs) by how many units you use in the month. Staying just under a step — 100, 200, 300 units and so on — can save a lot, because crossing it raises the rate.',
      ['slab', 'slaab', 'سلیب', 'rate', 'step'],
    ),
    Faq(
      'What is FCA / fuel adjustment?',
      'FCA (fuel charges adjustment) is an extra charge or refund per unit that NEPRA sets every month based on fuel costs a few months earlier. It\'s added to your bill on top of normal rates. The Home screen shows this month\'s FCA.',
      ['fca', 'fpa', 'fuel', 'adjustment', 'nepra', 'qta'],
    ),
    Faq(
      'How do I read my meter?',
      'Read the number on the meter display (kWh), leaving out digits in red or after a decimal point. Add it on the same day each week — or just take a photo and the app reads it for you.',
      ['meter', 'read', 'reading', 'parhna', 'ریڈنگ', 'میٹر'],
    ),
    Faq(
      'Why is the estimate different from my real bill?',
      'The app uses NEPRA rates, taxes and the FCA. Your real bill can also include arrears, installments, income tax for non-filers, or a different reading date. Once your bill is out, the app saves the exact amount automatically.',
      ['estimate', 'different', 'wrong', 'galat', 'fark', 'غلط', 'فرق'],
    ),
    Faq(
      'How can I save on my bill?',
      'Biggest wins: use the AC at 26°C with a fan, switch old fans to DC inverter fans, run the water motor and iron less often, and stay under the 200-unit line. Saving tips in Tools has more, and Appliances shows what costs you the most.',
      ['save', 'bachat', 'kam', 'reduce', 'tips', 'بچت', 'کم'],
    ),
    Faq(
      'What happens if I pay late?',
      'A late payment surcharge (about 10% of the bill) is added after the due date. The app reminds you 2 days before and on the due date.',
      ['late', 'surcharge', 'due', 'der', 'jurmana', 'تاخیر', 'جرمانہ'],
    ),
    Faq(
      'Is my data safe?',
      'Everything stays on your phone. There is no account. Only your reference number goes to your company\'s official bill site to get your bill, and only the bill figures are saved — never your name or address.',
      ['data', 'privacy', 'safe', 'secure', 'محفوظ ڈیٹا', 'پرائیویسی'],
    ),
    Faq(
      'Does it work for K-Electric?',
      'Bills for K-Electric, AJK and Gilgit-Baltistan aren\'t on the PITC site, so the app can\'t fetch them by itself. Scan your bill or add it by hand — everything else works the same.',
      ['k-electric', 'kelectric', 'karachi', 'ke', 'ajk', 'gilgit'],
    ),
    Faq(
      'How do I add another meter?',
      'Go to Tools → Meters → Add meter, or tap your meter name at the top of Home. Type the new reference number and the app finds the company and bills by itself.',
      ['another', 'second', 'new meter', 'dusra', 'add meter', 'دوسرا', 'نیا میٹر'],
    ),
  ];
}
