import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/meter.dart';
import '../../data/models/tariff.dart';
import '../../services/tariff_calculator.dart';
import '../../shared/widgets/animated_number.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/hero_style.dart';
import '../../state/app_state.dart';

/// One line of the bill: what it is and how much.
typedef BillLine = ({String label, String note, double amount});

/// Tools → Bill calculator: any number of units, any rate category and
/// load, with the bill worked out line by line by [TariffCalculator].
class BillCalculatorScreen extends StatefulWidget {
  const BillCalculatorScreen({super.key});

  static const maxUnits = 5000;
  static const maxLoadKw = 20.0;

  /// The bill line by line, for "How is this calculated?". Zero lines are left out.
  static List<BillLine> breakdown(BillEstimate e, Tariff t) {
    final lines = <BillLine>[
      (
        label: 'Energy charge'.tr,
        note: e.isTou
            ? '{0} peak + {1} off-peak units'.trf({'0': e.peakUnits, '1': e.offPeakUnits})
            : '{0} units, slab {1}'.trf({'0': e.units, '1': e.slab.label}),
        amount: e.energy,
      ),
      (label: 'Fixed charges'.tr, note: '', amount: e.fixed),
      (label: 'Financing surcharge'.tr, note: '', amount: e.fcSurcharge),
      (label: 'Fuel adjustment (FCA)'.tr, note: t.fcaLabel, amount: e.fca),
      (label: 'Quarterly adjustment (QTA)'.tr, note: t.qtaLabel, amount: e.qta),
      (label: 'Electricity duty'.tr, note: '', amount: e.electricityDuty),
      (label: 'GST'.tr, note: '{0}%'.trf({'0': Fmt.oneDp(t.gstPercent)}), amount: e.gst),
      (label: 'TV fee'.tr, note: '', amount: e.tvFee),
      if (e.exportCredit != 0) (label: 'Solar credit'.tr, note: '', amount: -e.exportCredit),
    ];
    return [for (final l in lines) if (l.amount.abs() >= 0.5 || l.label == 'Energy charge'.tr) l];
  }

  /// When [units] is just over a slab limit: the limit and what the extra
  /// units add to the whole bill. null when it doesn't apply.
  static (int, double)? overLimit(int units, List<int> limits, double Function(int) total, {int window = 40}) {
    final below = limits.where((l) => l < units).toList();
    if (below.isEmpty) return null;
    final l = below.last;
    if (units - l > window) return null;
    final extra = total(units) - total(l);
    return extra > 0 ? (l, extra) : null;
  }

  @override
  State<BillCalculatorScreen> createState() => _BillCalculatorScreenState();
}

class _BillCalculatorScreenState extends State<BillCalculatorScreen> {
  int? _units;

  /// null = the meter's own category.
  ConsumerClass? _class;
  double? _load;
  final _field = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setUnits(int v) {
    final u = v.clamp(0, BillCalculatorScreen.maxUnits);
    setState(() => _units = u);
    if (!_focus.hasFocus) _field.text = '$u';
  }

  void _reset() {
    HapticFeedback.selectionClick();
    _focus.unfocus();
    setState(() {
      _units = null;
      _class = null;
      _load = null;
      _field.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final h = HeroStyle.of(context);

    if (!state.hasTariff) {
      return Scaffold(
        appBar: AppBar(title: Text('Bill calculator'.tr)),
        body: Center(child: Text('Rates are still loading. Try again in a moment.'.tr)),
      );
    }

    final meter = state.activeMeter;
    final tariff = state.effectiveTariff;
    final calc = state.calculator;
    final own = state.protection?.consumerClass ?? ConsumerClass.unprotected;
    final cls = _class ?? own;
    final tou = meter?.meterType == MeterType.tou && _class == null;
    final load = (_load ?? meter?.sanctionedLoadKw ?? 1).clamp(0.5, BillCalculatorScreen.maxLoadKw).toDouble();
    final province = meter?.province ?? 'Punjab';
    final typical = state.typicalMonthlyUnits;
    final units = _units ?? (typical > 0 ? typical : 200);
    if (_field.text.isEmpty && !_focus.hasFocus) _field.text = '$units';

    BillEstimate estimate(int u) => tou
        ? (state.estimateFor(u) ?? BillEstimate.zero)
        : calc.estimate(u, consumerClass: cls, sanctionedLoadKw: load, province: province);
    final e = estimate(units);
    final lines = BillScreenText.lines(e, tariff);
    final jump = tou ? null : BillCalculatorScreen.overLimit(units, calc.limitsFor(cls), (u) => estimate(u).total);
    final movedUp = cls.hasProtection && e.appliedClass == ConsumerClass.unprotected;

    Widget section(String title, Widget child, {String? hint}) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: p.muted)),
                ],
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        );

    Widget stepButton(IconData icon, VoidCallback? onTap, String tip) => IconButton.filledTonal(
          tooltip: tip,
          onPressed: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          icon: Icon(icon),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('Bill calculator'.tr),
        actions: [
          TextButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded), label: Text('Reset'.tr)),
          const SizedBox(width: 4),
        ],
      ),
      body: GestureDetector(
        onTap: _focus.unfocus,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            // ---------------------------------------------------- result
            AppCard(
              gradient: h.gradient,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bill for {0} units'.trf({'0': Fmt.whole(units)}),
                          style: theme.textTheme.labelLarge?.copyWith(color: h.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _Badge(e.isTou ? 'TOU' : 'Slab {0}'.trf({'0': e.slabLabel}), AppColors.amber),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: AnimatedNumber(
                      value: e.total,
                      format: Fmt.rs,
                      duration: const Duration(milliseconds: 450),
                      style: theme.textTheme.displaySmall?.copyWith(color: h.fg, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Badge('{0}/unit all-in'.trf({'0': Fmt.rate(e.effectiveRate)}), h.fg.withValues(alpha: 0.85)),
                      _Badge(e.appliedClass.label, e.appliedClass.hasProtection ? p.safe : AppColors.amber),
                    ],
                  ),
                  if (movedUp) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Above {0} units, protected rates don\'t apply — the whole bill is at unprotected rates.'
                          .trf({'0': tariff.protectedThresholdUnits}),
                      style: theme.textTheme.bodySmall?.copyWith(color: h.fg),
                    ),
                  ],
                ],
              ),
            ),
            if (jump != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: p.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '{0} units over {1} add {2}. Staying at {1} saves that much.'
                              .trf({'0': units - jump.$1, '1': jump.$1, '2': Fmt.rs(jump.$2)}),
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ---------------------------------------------------- units
            section(
              'Units'.tr,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      stepButton(Icons.remove_rounded, units > 0 ? () => _setUnits(units - 10) : null, '−10'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _field,
                          focusNode: _focus,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          decoration: InputDecoration(
                            suffixText: 'units'.tr,
                            isDense: true,
                            helperText: 'Up to {0}'.trf({'0': Fmt.whole(BillCalculatorScreen.maxUnits)}),
                          ),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null) setState(() => _units = n.clamp(0, BillCalculatorScreen.maxUnits));
                          },
                          onSubmitted: (_) => _field.text = '$units',
                        ),
                      ),
                      const SizedBox(width: 10),
                      stepButton(Icons.add_rounded, units < BillCalculatorScreen.maxUnits ? () => _setUnits(units + 10) : null, '+10'),
                    ],
                  ),
                  Slider(
                    value: units.clamp(0, 1000).toDouble(),
                    max: 1000,
                    divisions: 200,
                    label: '${units.clamp(0, 1000)}',
                    onChanged: (v) {
                      _focus.unfocus();
                      _setUnits(v.round());
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final preset in const [100, 200, 300, 400, 500])
                        ChoiceChip(
                          label: Text('$preset'),
                          selected: units == preset,
                          onSelected: (_) {
                            _focus.unfocus();
                            _setUnits(preset);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ---------------------------------------------------- category
            section(
              'Rate category'.tr,
              hint: 'Protected: each of your last {0} bills was {1} units or less.'
                  .trf({'0': tariff.protectedMonths, '1': tariff.protectedThresholdUnits}),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ConsumerClass?>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: null, label: Text('Mine'.tr, maxLines: 1)),
                    ButtonSegment(value: ConsumerClass.protected, label: Text('Protected'.tr, maxLines: 1)),
                    ButtonSegment(value: ConsumerClass.unprotected, label: Text('Unprotected'.tr, maxLines: 1)),
                  ],
                  selected: {_class},
                  onSelectionChanged: (v) => setState(() => _class = v.first),
                ),
              ),
            ),

            // ---------------------------------------------------- load
            if (!tou)
              section(
                'Sanctioned load'.tr,
                hint: 'Printed on your bill. Fixed charges depend on it.'.tr,
                Row(
                  children: [
                    stepButton(Icons.remove_rounded, load > 0.5 ? () => setState(() => _load = load - 0.5) : null, '−0.5'),
                    Expanded(
                      child: Text(
                        '{0} kW'.trf({'0': Fmt.oneDp(load)}),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    stepButton(
                      Icons.add_rounded,
                      load < BillCalculatorScreen.maxLoadKw ? () => setState(() => _load = load + 0.5) : null,
                      '+0.5',
                    ),
                  ],
                ),
              ),

            // ---------------------------------------------------- breakdown
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    leading: const Icon(Icons.receipt_long_rounded),
                    title: Text('How is this calculated?'.tr, style: theme.textTheme.titleSmall),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    children: [
                      for (final l in lines) _LineRow(l),
                      const Divider(height: 18),
                      Row(
                        children: [
                          Expanded(child: Text('Total'.tr, style: theme.textTheme.titleMedium)),
                          Text(Fmt.rs(e.total), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        BillScreenText.howBilled(e, tariff),
                        style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '{0} · {1}. NEPRA rates as in the app; your real bill may differ slightly.'
                  .trf({'0': state.company.shortCode, '1': tariff.name}),
              style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Localised text for the calculator, kept apart so it's easy to test.
class BillScreenText {
  BillScreenText._();

  static List<BillLine> lines(BillEstimate e, Tariff t) => BillCalculatorScreen.breakdown(e, t);

  /// One sentence on how the energy charge was worked out.
  static String howBilled(BillEstimate e, Tariff t) {
    if (e.isTou) return 'Time-of-use meter: peak and off-peak units at their own rates, no slabs.'.tr;
    final cat = t.categoryOf(e.appliedClass);
    return switch (cat.billingMode) {
      BillingMode.whole => 'All units are charged at the rate of the slab you end up in, so one unit over a limit raises the whole bill.'.tr,
      BillingMode.previousSlab => 'Protected rates: units up to the previous slab at its rate, the rest at your slab\'s rate.'.tr,
      BillingMode.incremental => 'Each slab\'s units are charged at that slab\'s rate.'.tr,
    };
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow(this.line);

  final BillLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.label, style: theme.textTheme.bodyMedium),
                if (line.note.isNotEmpty)
                  Text(line.note, style: theme.textTheme.bodySmall?.copyWith(color: p.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            line.amount < 0 ? '− ${Fmt.rs(-line.amount)}' : Fmt.rs(line.amount),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
        child: Text(
          text,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      );
}
