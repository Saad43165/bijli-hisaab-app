import '../core/l10n/l10n.dart';
import '../core/utils/formatters.dart';
import '../data/models/bill.dart';

/// One piece of advice on Home: what to do next and why, in rupees.
class Advice {
  const Advice({required this.art, required this.title, required this.body, this.screen, this.ask});

  final String art;
  final String title;
  final String body;

  /// Screen to open (AssistantTools.screens), if any.
  final String? screen;

  /// Question to hand to the assistant, if any.
  final String? ask;
}

/// Turns the bill history into the 1–3 most useful things to do now.
/// Pure: estimates come in as functions, so it's unit-tested.
class AdviceEngine {
  const AdviceEngine({
    required this.estimate,
    this.protectedLimit = 200,
    this.protectedMonths = 6,
  });

  /// Bill total for (units, protectedRates).
  final double? Function(int units, bool protectedRates) estimate;
  final int protectedLimit;
  final int protectedMonths;

  static const _slabs = [100, 200, 300, 400, 500, 600, 700];

  List<Advice> build({
    required List<Bill> newestFirst,
    required DateTime today,
    required bool isProtected,
    required int? predictedNext,
    required bool tracking,
    bool latestPaid = false,
    String receiptArt = 'receipt',
    String shieldArt = 'shield',
    String warnArt = 'warning',
    String sunArt = 'sun',
    String plugArt = 'plug',
    String meterArt = 'meter',
  }) {
    final out = <Advice>[];
    if (newestFirst.isEmpty) return out;
    final latest = newestFirst.first;
    final day = DateTime(today.year, today.month, today.day);

    // 1. Due date.
    final due = latestPaid ? null : latest.dueDate;
    if (due != null) {
      final d = DateTime(due.year, due.month, due.day).difference(day).inDays;
      if (d >= 0 && d <= 5) {
        out.add(Advice(
          art: receiptArt,
          title: latest.amount > 0
              ? 'Pay {0} by {1}'.trf({'0': Fmt.rs(latest.amount), '1': Fmt.dayShort(due)})
              : 'Your bill is due {0}'.trf({'0': Fmt.dayShort(due)}),
          body: d == 0
              ? 'Today is the last day. After it, a late payment surcharge (about 10%) is added.'.tr
              : 'After the due date a late payment surcharge of about 10% is added.'.tr,
          screen: 'bill_online',
        ));
      } else if (d < 0 && d >= -15) {
        out.add(Advice(
          art: warnArt,
          title: 'Your bill was due {0}'.trf({'0': Fmt.dayShort(due)}),
          body: 'If it isn\'t paid yet, pay it soon — the surcharge grows after a few days.'.tr,
          screen: 'bill_online',
        ));
      }
    }

    final next = predictedNext;
    final nextMonth = DateTime(latest.monthDate.year, latest.monthDate.month + 1);

    // 2. Protected rates.
    final last = newestFirst.take(protectedMonths).toList();
    if (!isProtected && last.length >= 3) {
      final over = last.where((b) => b.units > protectedLimit).toList();
      if (over.isNotEmpty && over.length <= 3) {
        final typical = (last.fold<int>(0, (a, b) => a + b.units) / last.length).round().clamp(1, protectedLimit);
        final un = estimate(typical, false);
        final pr = estimate(typical, true);
        final save = un == null || pr == null ? 0.0 : un - pr;
        if (save > 200) {
          out.add(Advice(
            art: shieldArt,
            title: 'Protected rates are within reach'.tr,
            body: 'Only {0} went above {1} units. Keep your next {2} bills at {1} or less and you\'d pay about {3} less every month.'
                .trf({
              '0': over.map((b) => Fmt.monthShort(b.monthDate)).join(', '),
              '1': protectedLimit,
              '2': protectedMonths,
              '3': Fmt.rs(save),
            }),
            ask: 'How can I stay under 200 units?'.tr,
          ));
        }
      }
    } else if (isProtected && next != null && next > protectedLimit) {
      final un = estimate(next, false);
      final pr = estimate(next, true);
      final extra = un == null || pr == null ? null : un - pr;
      out.add(Advice(
        art: warnArt,
        title: 'Your next bill could cross {0} units'.trf({'0': protectedLimit}),
        body: 'We expect about {0} units in {1}. One bill above {2} ends protected rates for {3} months{4}.'.trf({
          '0': next,
          '1': Fmt.month(nextMonth),
          '2': protectedLimit,
          '3': protectedMonths,
          '4': extra == null || extra <= 0 ? '' : ' — ${'about {0} more every month'.trf({'0': Fmt.rs(extra)})}',
        }),
        ask: 'How can I stay under 200 units?'.tr,
      ));
    }

    // 3. Just over a slab.
    if (next != null) {
      for (final limit in _slabs) {
        if (next > limit && next - limit <= 15) {
          final over = estimate(next, isProtected);
          final at = estimate(limit, isProtected);
          final save = over == null || at == null ? 0.0 : over - at;
          if (save > 300) {
            out.add(Advice(
              art: meterArt,
              title: 'Cut {0} units next month'.trf({'0': next - limit}),
              body: 'About {0} units would put you just over {1}. Staying at {1} saves about {2}.'
                  .trf({'0': next, '1': limit, '2': Fmt.rs(save)}),
              ask: 'How can I save {0} units?'.trf({'0': next - limit}),
            ));
          }
          break;
        }
      }
    }

    // 4. Summer is coming.
    final hot = nextMonth.month >= 5 && nextMonth.month <= 9;
    if (hot && newestFirst.length >= 6) {
      final ly = newestFirst.where((b) => b.monthDate == DateTime(nextMonth.year - 1, nextMonth.month)).firstOrNull;
      final avg = newestFirst.take(12).fold<int>(0, (a, b) => a + b.units) / newestFirst.take(12).length;
      if (ly != null && ly.units > avg * 1.3) {
        out.add(Advice(
          art: sunArt,
          title: 'Summer bills are coming'.tr,
          body: 'Last {0} you used {1} units — {2}× your average. AC at 26°C with a fan, and fewer motor runs, make the biggest difference.'
              .trf({'0': Fmt.month(ly.monthDate), '1': ly.units, '2': (ly.units / avg).toStringAsFixed(1)}),
          screen: 'appliances',
        ));
      }
    }

    // 5. A big jump.
    if (newestFirst.length >= 2) {
      final prev = newestFirst[1];
      if (prev.units > 0 && latest.units > prev.units * 1.3 && latest.units - prev.units > 40) {
        out.add(Advice(
          art: plugArt,
          title: 'Your units jumped {0}%'.trf({'0': ((latest.units / prev.units - 1) * 100).round()}),
          body: '{0} units in {1} against {2} in {3}. Appliances shows what uses the most.'.trf({
            '0': latest.units,
            '1': Fmt.monthShort(latest.monthDate),
            '2': prev.units,
            '3': Fmt.monthShort(prev.monthDate),
          }),
          screen: 'appliances',
        ));
      }
    }

    // 6. Live tracking.
    if (!tracking) {
      out.add(Advice(
        art: meterArt,
        title: 'Get warnings before the bill comes'.tr,
        body: 'Add your meter reading once a week and we\'ll warn you before you cross a slab — or just tell the assistant "reading 12450".'.tr,
        screen: 'add_reading',
      ));
    }

    return out.take(3).toList();
  }
}
