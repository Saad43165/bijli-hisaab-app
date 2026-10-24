import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/tariff.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/loading_button.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/app_state.dart';
import '../../core/l10n/l10n.dart';

/// Hand-edit the rates. Saving turns off automatic rate updates.
class TariffEditScreen extends StatefulWidget {
  const TariffEditScreen({super.key});

  @override
  State<TariffEditScreen> createState() => _TariffEditScreenState();
}

class _TariffEditScreenState extends State<TariffEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late Tariff _original;
  late TextEditingController _fca;
  late TextEditingController _qta;
  late TextEditingController _gst;
  late TextEditingController _tv;
  late TextEditingController _duty;
  late TextEditingController _fcProtected;
  late TextEditingController _fcUnprotected;
  late List<TextEditingController> _protectedRates;
  late List<TextEditingController> _unprotectedRates;
  late TextEditingController _touPeak;
  late TextEditingController _touOffPeak;
  late TextEditingController _touFixed;
  late TextEditingController _netMetering;
  late TextEditingController _netBilling;
  late BillingMode _protectedMode;
  late BillingMode _unprotectedMode;
  late String _province;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _province = state.activeMeter?.province ?? 'Punjab';
    _load(state.tariff);
  }

  void _load(Tariff t) {
    _original = t;
    _fca = TextEditingController(text: _num(t.fcaPerUnit));
    _qta = TextEditingController(text: _num(t.qtaPerUnit));
    _gst = TextEditingController(text: _num(t.gstPercent));
    _tv = TextEditingController(text: _num(t.tvFee));
    _duty = TextEditingController(text: _num(t.dutyFor(_province)));
    _fcProtected = TextEditingController(text: _num(t.protectedCategory.fcSurchargePerUnit));
    _fcUnprotected = TextEditingController(text: _num(t.unprotectedCategory.fcSurchargePerUnit));
    _protectedRates = [for (final s in t.protectedCategory.slabs) TextEditingController(text: _num(s.rate))];
    _unprotectedRates = [for (final s in t.unprotectedCategory.slabs) TextEditingController(text: _num(s.rate))];
    _touPeak = TextEditingController(text: _num(t.tou.peakRate));
    _touOffPeak = TextEditingController(text: _num(t.tou.offPeakRate));
    _touFixed = TextEditingController(text: _num(t.tou.fixedPerKw));
    _netMetering = TextEditingController(text: _num(t.solar.netMeteringRate));
    _netBilling = TextEditingController(text: _num(t.solar.netBillingRate));
    _protectedMode = t.protectedCategory.billingMode;
    _unprotectedMode = t.unprotectedCategory.billingMode;
  }

  List<TextEditingController> get _controllers => [
        _fca, _qta, _gst, _tv, _duty, _fcProtected, _fcUnprotected,
        ..._protectedRates, ..._unprotectedRates,
        _touPeak, _touOffPeak, _touFixed, _netMetering, _netBilling,
      ];

  void _disposeControllers() {
    for (final c in _controllers) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  static String _num(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
  }

  double _read(TextEditingController c) => Fmt.parseNumber(c.text) ?? 0;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final t = _original;
    List<Slab> slabs(List<Slab> base, List<TextEditingController> rates) => [
          for (var i = 0; i < base.length; i++) base[i].copyWith(rate: _read(rates[i])),
        ];

    final updated = t.copyWith(
      fcaPerUnit: _read(_fca),
      qtaPerUnit: _read(_qta),
      gstPercent: _read(_gst),
      tvFee: _read(_tv),
      electricityDutyPercent: {...t.electricityDutyPercent, _province: _read(_duty)},
      protectedCategory: t.protectedCategory.copyWith(
        billingMode: _protectedMode,
        fcSurchargePerUnit: _read(_fcProtected),
        slabs: slabs(t.protectedCategory.slabs, _protectedRates),
      ),
      unprotectedCategory: t.unprotectedCategory.copyWith(
        billingMode: _unprotectedMode,
        fcSurchargePerUnit: _read(_fcUnprotected),
        slabs: slabs(t.unprotectedCategory.slabs, _unprotectedRates),
      ),
      tou: t.tou.copyWith(
        peakRate: _read(_touPeak),
        offPeakRate: _read(_touOffPeak),
        fixedPerKw: _read(_touFixed),
      ),
      solar: t.solar.copyWith(
        netMeteringRate: _read(_netMetering),
        netBillingRate: _read(_netBilling),
      ),
    );

    setState(() => _saving = true);
    await context.read<AppState>().updateTariff(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    showSnack(context, 'Your rates are saved — automatic updates are off'.tr);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = _original;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit rates'.tr),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Effective {0}'.trf({'0': t.effectiveFrom}), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text(t.sourceNote, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              SectionHeader('This month'.tr),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _NumberRow(
                      label: 'Fuel charges adjustment (FCA)'.tr,
                      helper: 'Rs per unit, from your latest bill. Can be negative.'.tr,
                      controller: _fca,
                      allowNegative: true,
                    ),
                    _NumberRow(
                      label: 'Quarterly adjustment (QTA)'.tr,
                      helper: 'Rs per unit. Can be negative.'.tr,
                      controller: _qta,
                      allowNegative: true,
                    ),
                    _NumberRow(label: 'GST'.tr, suffix: '%', controller: _gst),
                    _NumberRow(label: 'Electricity duty ({0})'.trf({'0': _province}), suffix: '%', controller: _duty),
                    _NumberRow(label: 'TV fee'.tr, prefix: 'Rs', controller: _tv),
                  ],
                ),
              ),
              SectionHeader('Protected consumers'.tr),
              _CategoryEditor(
                slabs: t.protectedCategory.slabs,
                rates: _protectedRates,
                fc: _fcProtected,
                mode: _protectedMode,
                onMode: (m) => setState(() => _protectedMode = m),
              ),
              SectionHeader('Normal (unprotected) consumers'.tr),
              _CategoryEditor(
                slabs: t.unprotectedCategory.slabs,
                rates: _unprotectedRates,
                fc: _fcUnprotected,
                mode: _unprotectedMode,
                onMode: (m) => setState(() => _unprotectedMode = m),
              ),
              SectionHeader('Time of use (5 kW and above)'.tr),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _NumberRow(label: 'Peak'.tr, helper: 'Rs per unit'.tr, prefix: 'Rs', controller: _touPeak),
                    _NumberRow(label: 'Off-peak'.tr, helper: 'Rs per unit'.tr, prefix: 'Rs', controller: _touOffPeak),
                    _NumberRow(
                      label: 'Fixed charge'.tr,
                      helper: 'Rs per kW, on {0}% of sanctioned load'.trf({'0': (t.tou.fixedLoadShare * 100).round()}),
                      prefix: 'Rs',
                      controller: _touFixed,
                    ),
                  ],
                ),
              ),
              SectionHeader('Solar'.tr),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _NumberRow(
                      label: 'Net billing buyback'.tr,
                      helper: 'Rs per exported unit (agreements from Feb 2026)'.tr,
                      prefix: 'Rs',
                      controller: _netBilling,
                    ),
                    _NumberRow(
                      label: 'Net metering surplus'.tr,
                      helper: 'Rs per surplus unit (older agreements)'.tr,
                      prefix: 'Rs',
                      controller: _netMetering,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LoadingButton(label: 'Save my rates'.tr, loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryEditor extends StatelessWidget {
  const _CategoryEditor({
    required this.slabs,
    required this.rates,
    required this.fc,
    required this.mode,
    required this.onMode,
  });

  final List<Slab> slabs;
  final List<TextEditingController> rates;
  final TextEditingController fc;
  final BillingMode mode;
  final ValueChanged<BillingMode> onMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < slabs.length; i++)
            _NumberRow(
              label: '{0} units'.trf({'0': slabs[i].label}),
              helper: slabs[i].fixedPerKw > 0 ? 'Fixed Rs {0}/kW'.trf({'0': slabs[i].fixedPerKw.toInt()}) : null,
              prefix: 'Rs',
              controller: rates[i],
            ),
          _NumberRow(label: 'FC surcharge'.tr, helper: 'Rs per unit'.tr, prefix: 'Rs', controller: fc),
          const SizedBox(height: 4),
          DropdownButtonFormField<BillingMode>(
            key: ValueKey(mode),
            initialValue: mode,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'How slabs are billed'.tr),
            items: [
              for (final m in BillingMode.values)
                DropdownMenuItem(value: m, child: Text(m.label, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (m) {
              if (m != null) onMode(m);
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Compare with a real bill: if estimates are off, try another billing method.'.tr,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.controller,
    this.helper,
    this.prefix,
    this.suffix,
    this.allowNegative = false,
  });

  final String label;
  final String? helper;
  final String? prefix;
  final String? suffix;
  final TextEditingController controller;
  final bool allowNegative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (helper != null) Text(helper!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.end,
              keyboardType: TextInputType.numberWithOptions(decimal: true, signed: allowNegative),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(allowNegative ? r'[0-9.\-]' : r'[0-9.]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                prefixText: prefix == null ? null : '$prefix ',
                suffixText: suffix,
              ),
              validator: (v) {
                final n = Fmt.parseNumber(v);
                if (n == null) return 'Required';
                if (!allowNegative && n < 0) return '≥ 0';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
