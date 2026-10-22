class SavingTip {
  const SavingTip({required this.en, required this.ur, required this.category});

  final String en;
  final String ur;
  final String category;
}

class SavingTips {
  SavingTips._();

  static const List<SavingTip> all = [
    SavingTip(
      category: 'cooling',
      en: 'Set the AC to 26°C. Every degree lower adds roughly 6–8% to its consumption.',
      ur: 'اے سی کو 26 ڈگری پر رکھیں۔ ہر ایک ڈگری کم کرنے سے بجلی کا خرچ تقریباً 6 سے 8 فیصد بڑھ جاتا ہے۔',
    ),
    SavingTip(
      category: 'cooling',
      en: 'Run the ceiling fan with the AC. You can raise the AC temperature by 2°C and feel the same.',
      ur: 'اے سی کے ساتھ پنکھا چلائیں۔ اس طرح آپ اے سی کا درجہ حرارت 2 ڈگری بڑھا سکتے ہیں۔',
    ),
    SavingTip(
      category: 'cooling',
      en: 'Clean AC filters every two weeks in summer. Dirty filters make the compressor work harder.',
      ur: 'گرمیوں میں ہر دو ہفتے بعد اے سی کے فلٹر صاف کریں۔ گندے فلٹر سے کمپریسر زیادہ بجلی لیتا ہے۔',
    ),
    SavingTip(
      category: 'cooling',
      en: 'Replacing an old ceiling fan with a DC inverter fan can cut its use by about half.',
      ur: 'پرانے پنکھے کی جگہ ڈی سی انورٹر پنکھا لگانے سے اس کی بجلی تقریباً آدھی ہو جاتی ہے۔',
    ),
    SavingTip(
      category: 'kitchen',
      en: 'Keep the fridge 4–5 inches away from the wall and don\'t put hot food inside.',
      ur: 'فریج کو دیوار سے 4 سے 5 انچ دور رکھیں اور گرم کھانا اندر نہ رکھیں۔',
    ),
    SavingTip(
      category: 'laundry',
      en: 'Iron clothes in one batch instead of one item every day — the iron uses most power while heating up.',
      ur: 'روزانہ ایک ایک کپڑا استری کرنے کے بجائے ایک ہی بار سب کپڑے استری کریں۔',
    ),
    SavingTip(
      category: 'pump',
      en: 'Run the water motor once a day to fill the tank, not several short times.',
      ur: 'پانی کی موٹر دن میں کئی بار تھوڑی دیر چلانے کے بجائے ایک بار ٹینکی بھرنے تک چلائیں۔',
    ),
    SavingTip(
      category: 'lighting',
      en: 'Swap tube lights and old bulbs for LEDs. A 12 W LED gives the same light as a 40 W tube light.',
      ur: 'ٹیوب لائٹ اور پرانے بلب کی جگہ ایل ای ڈی لگائیں۔ 12 واٹ کی ایل ای ڈی 40 واٹ کی ٹیوب جتنی روشنی دیتی ہے۔',
    ),
    SavingTip(
      category: 'other',
      en: 'Switch off TV, PC and chargers at the plug. Standby power adds up over a month.',
      ur: 'ٹی وی، کمپیوٹر اور چارجر کو پلگ سے بند کریں۔ اسٹینڈ بائی پر بھی بجلی خرچ ہوتی ہے۔',
    ),
    SavingTip(
      category: 'slab',
      en: 'If you are a protected consumer, staying at 200 units or below keeps your lower rates. One month at 201 removes protection for 6 months.',
      ur: 'اگر آپ پروٹیکٹڈ صارف ہیں تو 200 یونٹ یا اس سے کم رہیں۔ ایک ماہ بھی 201 یونٹ ہوئے تو 6 ماہ کے لیے پروٹیکشن ختم ہو جاتی ہے۔',
    ),
    SavingTip(
      category: 'slab',
      en: 'Check your meter every 3–4 days near the end of the month. That is when a few units decide your slab.',
      ur: 'مہینے کے آخر میں ہر 3 سے 4 دن بعد میٹر چیک کریں۔ انہی دنوں چند یونٹ آپ کا سلیب طے کرتے ہیں۔',
    ),
    SavingTip(
      category: 'heating',
      en: 'Use a gas geyser or a timer for the electric geyser. An electric geyser can use 2 units per hour.',
      ur: 'گیس گیزر استعمال کریں یا الیکٹرک گیزر پر ٹائمر لگائیں۔ الیکٹرک گیزر ایک گھنٹے میں 2 یونٹ تک لے سکتا ہے۔',
    ),
  ];

  /// Same tip for the whole day, rotating daily.
  static SavingTip ofTheDay([DateTime? now]) {
    final d = now ?? DateTime.now();
    final dayOfYear = d.difference(DateTime(d.year)).inDays;
    return all[dayOfYear % all.length];
  }
}
