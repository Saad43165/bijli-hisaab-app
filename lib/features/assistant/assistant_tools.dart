import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/companies.dart';
import '../../data/models/appliance.dart';
import '../../data/models/meter.dart';
import '../../data/models/tariff.dart';
import '../../core/l10n/l10n.dart';
import '../../core/navigation/app_nav.dart';
import '../../core/utils/formatters.dart';
import '../../services/online_bill_service.dart';
import '../../services/usage_forecaster.dart';
import '../../state/app_state.dart';
import '../appliances/appliances_screen.dart';
import '../bills/online_bill_screen.dart';
import '../bills/scan_bill_screen.dart';
import '../home/bill_calculator_screen.dart';
import '../home/calculators_screen.dart';
import '../home/solar_calculator_screen.dart';
import '../../services/appliance_planner.dart';
import '../home/widgets/advice_card.dart';
import '../home/widgets/bill_overview_card.dart';
import '../meters/add_meter_screen.dart';
import 'core_answers.dart';
import '../meters/meters_screen.dart';
import '../readings/add_reading_screen.dart';
import '../readings/readings_screen.dart';
import '../settings/backup_screen.dart';
import '../settings/help_screen.dart';
import '../settings/reminders_screen.dart';
import '../settings/tariff_screen.dart';
import '../settings/tips_screen.dart';

/// Everything the assistant can look up or do in the app. Each method
/// returns a short plain-text result the assistant can read back or reason
/// about (the cloud model gets these as function results).
class AssistantTools {
  AssistantTools(this.state);

  final AppState state;

  /// Screens the assistant can open.
  static const screens = [
    'home', 'history', 'appliances', 'tools', 'scan_bill', 'bill_online', 'add_reading', 'readings',
    'calculators', 'bill_calculator', 'solar_calculator', 'reminders', 'rates', 'backup', 'meters',
    'add_meter', 'tips', 'help',
  ];

  // ------------------------------------------------------------ look up

  /// The user's numbers for the assistant, from the tariff calculator and
  /// the app's data.
  CoreFacts facts() {
    final m = state.activeMeter;
    final t = state.effectiveTariff;
    final s = state.summary;
    final live = s != null && s.hasData;
    final p = state.protection;
    final bills = state.bills;
    final next = BillOverviewCard.nextUnits(bills);
    final rate = state.marginalRate;
    final apps = [...state.appliances]..sort((a, z) => z.monthlyUnits.compareTo(a.monthlyUnits));
    List<(String, double)> slabs(List<Slab> list) => [for (final x in list) (x.label, x.rate)];
    return CoreFacts(
      today: DateTime.now(),
      hasMeter: m != null,
      disco: m == null ? null : state.company.shortCode,
      isTou: m?.meterType == MeterType.tou,
      unitsSoFar: live ? s.unitsUsed : null,
      dailyRate: live ? s.dailyRate : null,
      projectedUnits: live ? s.projectedUnits : null,
      projectedBill: live ? s.estimateProjected.total : null,
      projectedSlab: live ? s.estimateProjected.slabLabel : null,
      daysLeft: live ? s.daysLeft : null,
      cycleEnd: live ? s.cycleEnd : null,
      targetLimit: live ? s.targetLimit : null,
      safeDailyBudget: live ? s.safeDailyBudget : null,
      extraCostIfCrossed: live ? s.extraCostIfCrossed : 0,
      isProtected: p?.isProtected,
      isLifeline: p?.consumerClass == ConsumerClass.lifeline,
      protectedThreshold: t.protectedThresholdUnits,
      protectedMonths: t.protectedMonths,
      bills: [
        for (final b in bills.take(12))
          BillFact(month: b.monthDate, units: b.units, amount: b.amount, dueDate: b.dueDate, paid: state.isBillPaid(b)),
      ],
      predictedUnits: next,
      predictedBill: next == null ? null : state.estimateFor(next)?.total,
      fcaPerUnit: t.fcaPerUnit,
      fcaLabel: t.fcaLabel,
      qtaPerUnit: t.qtaPerUnit,
      gstPercent: t.gstPercent,
      marginalRate: rate,
      tariffName: t.name,
      protectedSlabs: slabs(t.protectedCategory.slabs),
      unprotectedSlabs: slabs(t.unprotectedCategory.slabs),
      appliances: [for (final a in apps) ApplianceFact(a.name, a.monthlyUnits, a.monthlyUnits * rate)],
      helpline: m == null ? null : state.company.helpline,
      estimate: m == null ? null : (n) => state.estimateFor(n)?.total,
    );
  }

  /// Facts about the active meter: bill, due date, prediction, this month.
  String overview() {
    final m = state.activeMeter;
    if (m == null) return 'No meter is set up yet.';
    final b = StringBuffer();
    final today = DateUtils.dateOnly(DateTime.now());
    b.writeln('Meter: ${m.name} (${state.company.shortCode}), ${m.meterType.name} meter, '
        '${Fmt.oneDp(m.sanctionedLoadKw)} kW load. ${state.meters.length} meter(s) in the app: '
        '${state.meters.map((x) => x.name).join(', ')}.');
    final bills = state.bills;
    if (bills.isEmpty) {
      b.writeln('No bills saved yet.');
    } else {
      final last = bills.first;
      b.write('Latest bill: ${Fmt.month(last.monthDate)}, ${last.units} units');
      if (last.amount > 0) b.write(', ${Fmt.rs(last.amount)}');
      if (last.dueDate != null) {
        final d = DateUtils.dateOnly(last.dueDate!).difference(today).inDays;
        b.write(', due ${Fmt.day(last.dueDate!)} (${d >= 0 ? '$d days left' : '${-d} days ago'})');
      }
      b.writeln('.');
      final next = BillOverviewCard.nextUnits(bills);
      if (next != null) {
        final amt = state.estimateFor(next)?.total;
        b.writeln('Predicted next bill: about $next units${amt == null ? '' : ' ≈ ${Fmt.rs(amt)}'}.');
      }
      final recent = bills.take(12).toList();
      final avg = recent.fold<int>(0, (a, x) => a + x.units) / recent.length;
      b.writeln('Average of last ${recent.length} bills: ${avg.round()} units.');
    }
    final p = state.protection;
    if (p != null) b.writeln('Rate category: ${p.consumerClass.name}. ${p.reason}');
    final s = state.summary;
    if (s != null && s.hasData) {
      b.writeln('This month so far: ${Fmt.whole(s.unitsUsed)} units, ${Fmt.oneDp(s.dailyRate)} a day, '
          'heading for ${Fmt.whole(s.projectedUnits)} units ≈ ${Fmt.rs(s.estimateProjected.total)} '
          '(${s.daysLeft} days left in the cycle, status ${s.status.name}).');
      if (s.targetLimit != null && s.safeDailyBudget != null) {
        b.writeln('To stay under ${s.targetLimit} units: max ${Fmt.oneDp(s.safeDailyBudget!)} units a day.');
      }
    } else {
      b.writeln('No meter readings this month (live tracking is off).');
    }
    final t = state.effectiveTariff;
    if (t.fcaPerUnit != 0) b.writeln('This month\'s FCA: Rs ${Fmt.twoDp(t.fcaPerUnit)} per unit (${t.fcaLabel}).');
    final ideas = AppliancePlanner.savings(state.appliances, state.marginalRate, max: 4);
    if (ideas.isNotEmpty) {
      b.writeln('Biggest savings (worked out by the app): '
          '${ideas.map((i) => '${i.title} ~${Fmt.rs(i.rupees)}/month').join('; ')}.');
    }
    final tips = AdviceCard.adviceFor(state);
    if (tips.isNotEmpty) b.writeln('Advice shown on Home: ${tips.map((x) => '${x.title} (${x.body})').join(' | ')}');
    final top = [...state.appliances]..sort((a, z) => z.monthlyUnits.compareTo(a.monthlyUnits));
    if (top.isNotEmpty) {
      b.writeln('Biggest appliances: ${top.take(3).map((a) => '${a.name} ~${a.monthlyUnits.round()} units/month').join(', ')}.');
    }
    return b.toString().trim();
  }

  String appliances() {
    final list = [...state.appliances]..sort((a, z) => z.monthlyUnits.compareTo(a.monthlyUnits));
    if (list.isEmpty) return 'No appliances added yet.';
    final rate = state.marginalRate;
    return list
        .map((a) => '${a.name}: ${a.watts} W, ${Fmt.oneDp(a.hoursPerDay)} h/day, '
            '~${a.monthlyUnits.round()} units/month${rate > 0 ? ' (~${Fmt.rs(a.monthlyUnits * rate)})' : ''}')
        .join('\n');
  }

  /// Words people use → catalogue name.
  static const _applianceWords = {
    'inverter ac': 'AC 1.5 ton (inverter)', 'ac': 'AC 1.5 ton (inverter)', 'air conditioner': 'AC 1.5 ton (inverter)',
    'non inverter': 'AC 1.5 ton (non-inverter)', 'dc fan': 'Ceiling fan (DC inverter)', 'fan': 'Ceiling fan',
    'pankha': 'Ceiling fan', 'پنکھ': 'Ceiling fan', 'cooler': 'Air cooler', 'fridge': 'Refrigerator',
    'refrigerator': 'Refrigerator', 'فریج': 'Refrigerator', 'freezer': 'Deep freezer', 'microwave': 'Microwave oven',
    'kettle': 'Electric kettle', 'iron': 'Iron', 'استری': 'Iron', 'washing': 'Washing machine', 'bulb': 'LED bulb',
    'light': 'LED bulb', 'tube': 'Tube light', 'tv': 'LED TV', 'ٹی وی': 'LED TV', 'computer': 'Desktop PC',
    'pc': 'Desktop PC', 'laptop': 'Laptop', 'router': 'Wi-Fi router', 'wifi': 'Wi-Fi router', 'motor': 'Water motor (1 HP)',
    'pump': 'Water motor (1 HP)', 'موٹر': 'Water motor (1 HP)', 'geyser': 'Electric geyser', 'heater': 'Room heater',
    'ups': 'UPS charging', 'dispenser': 'Water dispenser', 'charger': 'Phone charger', 'oven': 'Electric oven',
  };

  /// Catalogue name for what the user called it, or null.
  static String? applianceNamed(String words) {
    final w = words.toLowerCase();
    if (ApplianceCatalog.preset(words) != null) return words;
    for (final p in ApplianceCatalog.presets) {
      if (p.name.toLowerCase() == w) return p.name;
    }
    // Longest keyword first, so "inverter ac" beats "ac".
    final keys = _applianceWords.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (RegExp('(^|[^a-z])${RegExp.escape(k)}').hasMatch(w)) return _applianceWords[k];
    }
    return null;
  }

  /// Adds (or sets the count of) an appliance by everyday name.
  Future<String> addAppliance(String name, {int quantity = 1, double? hours}) async {
    final meterId = state.activeMeter?.id;
    if (meterId == null) return 'Set up a meter first.';
    final preset = applianceNamed(name);
    if (preset == null) return 'Unknown appliance "$name". Add it from the Appliances screen.';
    final p = ApplianceCatalog.preset(preset)!;
    final existing = state.appliances.where((a) => a.name == p.name).firstOrNull;
    if (existing != null) {
      await state.saveAppliance(existing.copyWith(quantity: quantity, hoursPerDay: hours ?? existing.hoursPerDay));
    } else {
      await state.saveAppliance(Appliance(
        meterId: meterId,
        name: p.name,
        category: p.category,
        watts: p.watts,
        quantity: quantity,
        hoursPerDay: hours ?? p.hoursPerDay,
        createdAt: DateTime.now(),
      ));
    }
    final h = hours ?? existing?.hoursPerDay ?? p.hoursPerDay;
    final units = p.watts * quantity * h * 30 / 1000;
    return 'Saved ${p.name} × $quantity, ${Fmt.oneDp(h)} h a day: about ${units.round()} units a month.';
  }

  String billHistory([int months = 12]) {
    final bills = state.bills.take(months.clamp(1, 24)).toList();
    if (bills.isEmpty) return 'No bills saved yet.';
    return bills
        .map((x) => '${Fmt.month(x.monthDate)}: ${x.units} units${x.amount > 0 ? ', ${Fmt.rs(x.amount)}' : ''}')
        .join('\n');
  }

  String estimateBill(int units) {
    final e = state.estimateFor(units);
    if (e == null) return 'Set up a meter first.';
    return '$units units ≈ ${Fmt.rs(e.total)} with taxes (slab ${e.slabLabel}, about '
        '${Fmt.rate(units == 0 ? 0 : e.total / units)} per unit all-in).';
  }

  // ------------------------------------------------------------ do things

  Future<String> fetchLatestBill() async {
    if (!state.canFetchOnlineBill) {
      return OnlineBillService.supports(state.company)
          ? 'This meter has no reference number saved. Add it in Meters.'
          : '${state.company.shortCode} bills are not available online. Scan the bill instead.';
    }
    try {
      final before = state.bills.length;
      final b = await state.fetchOnlineBill();
      final added = state.bills.length - before;
      return 'Fetched the ${Fmt.month(b.month)} bill: ${b.units} units, ${Fmt.rs(b.amount)}'
          '${b.dueDate == null ? '' : ', due ${Fmt.day(b.dueDate!)}'}. '
          '${added > 0 ? 'Added $added new month(s) to history.' : 'History was already up to date.'}';
    } on OnlineBillException catch (e) {
      return 'Could not fetch the bill: ${e.message}';
    }
  }

  Future<String> addReading(double value) async {
    final m = state.activeMeter;
    if (m == null) return 'Set up a meter first.';
    final today = DateTime.now();
    final before = state.readingBefore(today);
    if (before != null && value < before.value) {
      return 'Not saved: $value is lower than the last reading (${Fmt.whole(before.value)} on '
          '${Fmt.dayShort(before.date)}). Check the digits.';
    }
    await state.addReading(value, today);
    final s = state.summary;
    final tail = s != null && s.hasData
        ? ' This month: ${Fmt.whole(s.unitsUsed)} units so far, heading for ${Fmt.whole(s.projectedUnits)}.'
        : ' Add another reading in a few days to see this month\'s units.';
    return 'Saved reading ${Fmt.whole(value)} for today.$tail';
  }

  Future<String> switchMeter(String name) async {
    final q = name.toLowerCase().trim();
    final m = state.meters.where((x) => x.name.toLowerCase() == q).firstOrNull ??
        state.meters.where((x) => x.name.toLowerCase().contains(q) || q.contains(x.name.toLowerCase())).firstOrNull ??
        state.meters
            .where((x) => PowerCompanies.of(x.disco).shortCode.toLowerCase() == q)
            .firstOrNull;
    if (m?.id == null) {
      return 'No meter called "$name". Meters: ${state.meters.map((x) => x.name).join(', ')}.';
    }
    await state.setActiveMeter(m!.id!);
    AppNav.goTab(0);
    return 'Switched to ${m.name}.';
  }

  Future<String> addMeterByReference(String reference, {String? name}) async {
    if (!OnlineBillService.validReference(reference)) return 'A reference number has 14 digits.';
    try {
      final (c, b) = await state.findOnlineBill(reference);
      final already = state.meterWithReference(b.reference) != null;
      final meter = await state.addMeterFromOnlineBill(c, b, name: name ?? '{0} meter'.trf({'0': c.shortCode}));
      return already
          ? 'That meter was already added — switched to ${meter.name} and updated its bills.'
          : 'Added ${meter.name} (${c.shortCode}) with ${b.history.length + 1} months of bills. '
              'Latest bill ${Fmt.month(b.month)}: ${b.units} units, ${Fmt.rs(b.amount)}.';
    } on OnlineBillException catch (e) {
      return 'Could not add the meter: ${e.message}';
    }
  }

  Future<String> setLanguage(String code) async {
    await state.setLanguage(code == 'ur' ? 'ur' : 'en');
    return code == 'ur' ? 'Language changed to Urdu.' : 'Language changed to English.';
  }

  Future<String> setTheme(String mode) async {
    final m = switch (mode) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    await state.setThemeMode(m);
    return 'Theme set to $mode.';
  }

  /// Opens a screen. The assistant chat closes so the user sees it.
  String openScreen(String screen) {
    switch (screen) {
      case 'home':
        AppNav.goTab(0);
      case 'history':
        AppNav.goTab(1);
      case 'appliances':
        AppNav.goTab(2);
      case 'tools':
        AppNav.goTab(3);
      default:
        final w = _screen(screen);
        if (w == null) return 'Unknown screen "$screen".';
        AppNav.push(w);
    }
    return 'Opened $screen.';
  }

  Widget? _screen(String s) => switch (s) {
        'scan_bill' => const ScanBillScreen(),
        'bill_online' => state.company.billUrl == null
            ? null
            : OnlineBillScreen(company: state.company, referenceNo: state.activeMeter?.referenceNo ?? ''),
        'add_reading' => const AddReadingScreen(),
        'readings' => const ReadingsScreen(),
        'calculators' => const CalculatorsScreen(),
        'bill_calculator' => const BillCalculatorScreen(),
        'solar_calculator' => const SolarCalculatorScreen(),
        'reminders' => const RemindersScreen(),
        'rates' => const TariffScreen(),
        'backup' => const BackupScreen(),
        'meters' => const MetersScreen(),
        'add_meter' => const AddMeterScreen(),
        'tips' => const TipsScreen(),
        'help' => const HelpScreen(),
        'appliances_screen' => const AppliancesScreen(),
        _ => null,
      };

  /// Status words for a summary, for replies.
  static String statusWordEn(UsageStatus s) => switch (s) {
        UsageStatus.safe => 'on track',
        UsageStatus.warn => 'close to the limit',
        UsageStatus.danger => 'will cross the limit',
        UsageStatus.overLimits => 'in the highest slab',
        UsageStatus.noData => '',
      };
}
