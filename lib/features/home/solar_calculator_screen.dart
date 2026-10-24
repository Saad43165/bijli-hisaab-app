import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/animated_number.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/hero_style.dart';
import '../../state/app_state.dart';

/// How many kW of panels cover your usage and how fast they pay back.
/// Uses the average of your saved bills (or this month's projection).
class SolarCalculatorScreen extends StatefulWidget {
  const SolarCalculatorScreen({super.key});

  /// Units one kW of panels makes per day in Pakistan, averaged over the year.
  static const double unitsPerKwDay = 4.0;
  static const int panelWatts = 585;

  static const double minUnits = 50;
  static const double maxUnits = 3000;

  /// The system for [units] a month: kW (rounded up to 0.5), panels, units made a month.
  static (double kw, int panels, double made) size(double units) {
    final kw = ((units / (30 * unitsPerKwDay)) * 2).ceil() / 2;
    return (kw, (kw * 1000 / panelWatts).ceil(), kw * unitsPerKwDay * 30);
  }

  @override
  State<SolarCalculatorScreen> createState() => _SolarCalculatorScreenState();
}

class _SolarCalculatorScreenState extends State<SolarCalculatorScreen> {
  double? _units;
  static const double _defaultCost = 110000;
  double _costPerKw = _defaultCost;

  /// Net metering (old agreements) or net billing (new, since Feb 2026).
  bool _netBilling = true;

  /// Share of solar units used at home while the sun is up; the rest is exported.
  double _selfUse = 0.4;

  void _reset() {
    HapticFeedback.selectionClick();
    setState(() {
      _units = null;
      _costPerKw = _defaultCost;
      _netBilling = true;
      _selfUse = 0.4;
    });
  }

  int _averageUnits(AppState s) {
    final bills = s.last12Bills;
    if (bills.isNotEmpty) return (bills.fold<int>(0, (a, b) => a + b.units) / bills.length).round();
    return s.typicalMonthlyUnits;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final h = HeroStyle.of(context);
    final billsCount = state.last12Bills.length;
    final units = (_units ?? _averageUnits(state).toDouble())
        .clamp(SolarCalculatorScreen.minUnits, SolarCalculatorScreen.maxUnits)
        .toDouble();

    final (kw, panels, made) = SolarCalculatorScreen.size(units);
    final cost = kw * _costPerKw;

    final u = units.round();
    final before = state.estimateFor(u)?.total ?? 0;
    final double saving;
    if (_netBilling) {
      final self = (made * _selfUse).clamp(0.0, units);
      final exported = made - self;
      final after = state.estimateFor((units - self).round())?.total ?? before;
      saving = (before - after) + exported * state.effectiveTariff.solar.netBillingRate;
    } else {
      final net = (units - made).round();
      final after = net >= 0
          ? state.estimateFor(net)?.total ?? before
          : (state.estimateFor(0)?.total ?? 0) - (-net) * state.effectiveTariff.solar.netMeteringRate;
      saving = before - after;
    }
    final years = saving <= 0 ? null : cost / (saving * 12);
    final valueStyle = theme.textTheme.titleLarge?.copyWith(color: h.fg, fontWeight: FontWeight.w800);

    Widget stat(String label, Widget value) => Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: h.muted)),
                FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: value),
              ],
            ),
          ),
        );
    Widget money(double v) =>
        AnimatedNumber(value: v, format: Fmt.rs, duration: const Duration(milliseconds: 450), style: valueStyle);

    void setUnits(double v) => setState(
        () => _units = v.clamp(SolarCalculatorScreen.minUnits, SolarCalculatorScreen.maxUnits).toDouble());

    return Scaffold(
      appBar: AppBar(
        title: Text('Solar calculator'.tr),
        actions: [
          TextButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded), label: Text('Reset'.tr)),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            gradient: h.gradient,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ArtTile(Art.sun, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('{0} kW system'.trf({'0': Fmt.oneDp(kw)}),
                          style: theme.textTheme.headlineSmall?.copyWith(color: h.fg, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(children: [
                  stat('PANELS'.tr, Text('$panels × ${SolarCalculatorScreen.panelWatts} W', style: valueStyle)),
                  stat('COST'.tr, money(cost)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  stat('SAVES A MONTH'.tr, money(saving)),
                  stat(
                    'PAYS BACK IN'.tr,
                    Text(years == null ? '—' : '{0} years'.trf({'0': Fmt.oneDp(years)}), style: valueStyle),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Your usage'.tr, style: theme.textTheme.titleMedium),
                Text(
                  billsCount > 0
                      ? 'Average of your last {0} bills. Drag to try other amounts.'.trf({'0': billsCount})
                      : 'Add your bills for a better average. Drag to try other amounts.'.tr,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: '−50',
                      onPressed: units > SolarCalculatorScreen.minUnits ? () => setUnits(units - 50) : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '{0} units/month'.trf({'0': Fmt.whole(u)}),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: '+50',
                      onPressed: units < SolarCalculatorScreen.maxUnits ? () => setUnits(units + 50) : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                // The slider covers 50–1,500; the buttons go up to 3,000.
                Slider(
                  value: units.clamp(SolarCalculatorScreen.minUnits, 1500.0),
                  min: SolarCalculatorScreen.minUnits,
                  max: 1500,
                  divisions: 145,
                  onChanged: setUnits,
                ),
                const Divider(height: 24),
                Text('Agreement'.tr, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text('Net billing (new)'.tr)),
                    ButtonSegment(value: false, label: Text('Net metering (old)'.tr)),
                  ],
                  selected: {_netBilling},
                  onSelectionChanged: (v) => setState(() => _netBilling = v.first),
                ),
                if (_netBilling) ...[
                  const SizedBox(height: 12),
                  Text('Used at home while the sun is up: {0}%'.trf({'0': (_selfUse * 100).round()}),
                      style: theme.textTheme.bodyMedium),
                  Slider(
                    value: _selfUse,
                    min: 0.2,
                    max: 0.8,
                    divisions: 12,
                    onChanged: (v) => setState(() => _selfUse = v),
                  ),
                  Text('Run AC, motor and iron in the daytime to use more of your own solar — exported units earn only {0}.'
                      .trf({'0': Fmt.rate(state.effectiveTariff.solar.netBillingRate)}),
                      style: theme.textTheme.bodySmall),
                ],
                const Divider(height: 24),
                Text('Price per kW (installed)'.tr, style: theme.textTheme.titleMedium),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _costPerKw,
                        min: 70000,
                        max: 200000,
                        divisions: 26,
                        onChanged: (v) => setState(() => _costPerKw = v),
                      ),
                    ),
                    SizedBox(
                      width: 92,
                      child: Text(Fmt.rs(_costPerKw), textAlign: TextAlign.end, style: theme.textTheme.labelLarge),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: const Icon(Icons.calculate_outlined),
                title: Text('How is this calculated?'.tr, style: theme.textTheme.titleSmall),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in [
                    '{0} units a month ÷ (30 days × {1} units per kW a day) = {2} kW, rounded up to {3} kW.'.trf({
                      '0': Fmt.whole(u),
                      '1': Fmt.oneDp(SolarCalculatorScreen.unitsPerKwDay),
                      '2': Fmt.twoDp(u / (30 * SolarCalculatorScreen.unitsPerKwDay)),
                      '3': Fmt.oneDp(kw),
                    }),
                    '{0} kW makes about {1} units a month.'.trf({'0': Fmt.oneDp(kw), '1': Fmt.whole(made)}),
                    'Bill now for {0} units: {1}.'.trf({'0': Fmt.whole(u), '1': Fmt.rs(before)}),
                    _netBilling
                        ? 'Net billing: units you use yourself come off the bill; exported units earn {0} each.'
                            .trf({'0': Fmt.rate(state.effectiveTariff.solar.netBillingRate)})
                        : 'Net metering: units sent to the grid cancel units you take, and extra ones earn {0} each.'
                            .trf({'0': Fmt.rate(state.effectiveTariff.solar.netMeteringRate)}),
                    'Cost {0} ÷ savings of {1} a year = payback time.'.trf({'0': Fmt.rs(cost), '1': Fmt.rs(saving * 12)}),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $line', style: theme.textTheme.bodyMedium),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A rough guide: 1 kW of panels makes about {0} units a day on average in Pakistan (less in winter, more in summer). Get a quote from an installer before you buy.'
                .trf({'0': Fmt.oneDp(SolarCalculatorScreen.unitsPerKwDay)}),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
