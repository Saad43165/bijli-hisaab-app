import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/appliance.dart';
import '../../../shared/widgets/art.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../state/app_state.dart';
import '../../../core/l10n/l10n.dart';

/// Add / edit appliance: search the common ones, or type your own; hour
/// shortcuts; live units and rupees; delete when editing.
class ApplianceSheet extends StatefulWidget {
  const ApplianceSheet({super.key, this.existing});

  final Appliance? existing;

  static Future<void> show(BuildContext context, {Appliance? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ApplianceSheet(existing: existing),
    );
  }

  @override
  State<ApplianceSheet> createState() => _ApplianceSheetState();
}

class _ApplianceSheetState extends State<ApplianceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _watts;
  late String _category;
  late int _qty;
  late double _hours;
  bool _saving = false;

  /// New appliance: show the picker until one is chosen or "Other" is tapped.
  late bool _picking;
  String _query = '';

  static const _hourChips = [0.25, 1.0, 4.0, 8.0, 12.0, 24.0];

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _name = TextEditingController(text: a?.name ?? '');
    _watts = TextEditingController(text: a?.watts.toString() ?? '');
    _category = a?.category ?? 'other';
    _qty = a?.quantity ?? 1;
    _hours = a?.hoursPerDay ?? 4;
    _picking = a == null;
  }

  @override
  void dispose() {
    _name.dispose();
    _watts.dispose();
    super.dispose();
  }

  void _applyPreset(AppliancePreset p) {
    HapticFeedback.selectionClick();
    setState(() {
      _name.text = p.name;
      _watts.text = p.watts.toString();
      _category = p.category;
      _hours = p.hoursPerDay;
      _picking = false;
    });
  }

  double get _watt => Fmt.parseNumber(_watts.text) ?? 0;
  double get _dailyUnits => _watt * _qty * _hours / 1000;
  double get _monthlyUnits => _dailyUnits * 30;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = context.read<AppState>();
    final meterId = state.activeMeter?.id;
    if (meterId == null) return;
    final base = widget.existing;
    final appliance = Appliance(
      id: base?.id,
      meterId: base?.meterId ?? meterId,
      name: _name.text.trim(),
      category: _category,
      watts: _watt.round(),
      quantity: _qty,
      hoursPerDay: _hours,
      createdAt: base?.createdAt ?? DateTime.now(),
    );
    setState(() => _saving = true);
    try {
      await state.saveAppliance(appliance);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, base == null ? '{0} added'.trf({'0': appliance.name}) : 'Saved'.tr);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Could not save: {0}'.trf({'0': e}));
      }
    }
  }

  Future<void> _delete() async {
    final a = widget.existing;
    if (a == null) return;
    final state = context.read<AppState>();
    final ok = await confirmDialog(
      context,
      title: 'Remove {0}?'.trf({'0': a.name}),
      message: 'It will be removed from your estimate.'.tr,
      confirmLabel: 'Remove'.tr,
    );
    if (!ok) return;
    await state.deleteAppliance(a);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.topCenter,
        child: _picking ? _picker(context) : _form(context),
      ),
    );
  }

  // ------------------------------------------------------------ picker

  Widget _picker(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final matches = ApplianceCatalog.presets.where((p) => q.isEmpty || p.name.toLowerCase().contains(q)).toList();
    final byCategory = <String, List<AppliancePreset>>{};
    for (final p in matches) {
      byCategory.putIfAbsent(p.category, () => []).add(p);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add appliance'.tr, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search: fan, AC, motor…'.tr,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                for (final c in ApplianceCatalog.categories)
                  if (byCategory[c] case final list?) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 8),
                      child: Text(ApplianceCatalog.categoryLabels[c]!.tr.toUpperCase(), style: theme.textTheme.labelSmall),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in list)
                          ActionChip(
                            avatar: ArtImage(Art.forAppliance(p.name, p.category), size: 20),
                            label: Text(p.name.tr),
                            onPressed: () => _applyPreset(p),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Not in the list — add it yourself below.'.tr, style: theme.textTheme.bodyMedium),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _picking = false;
                    if (_query.trim().isNotEmpty) _name.text = _query.trim();
                  }),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(q.isEmpty ? 'Something else — type it in'.tr : 'Add "{0}" yourself'.trf({'0': _query.trim()})),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- form

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final rate = context.watch<AppState>().marginalRate;
    final units = _monthlyUnits;
    final isNew = widget.existing == null;
    final nonInverterAc = _name.text.toLowerCase().contains('non-inverter');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ArtTile(Art.forAppliance(_name.text, _category), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(isNew ? 'Add appliance'.tr : 'Edit appliance'.tr, style: theme.textTheme.titleLarge),
                ),
                if (isNew)
                  TextButton(onPressed: () => setState(() => _picking = true), child: Text('Change'.tr))
                else
                  IconButton(
                    tooltip: 'Remove'.tr,
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline_rounded, color: p.danger),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Name'.tr),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name'.tr : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _watts,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Power'.tr,
                      suffixText: 'W',
                      helperText: 'On the sticker. 1 kW = 1000 W'.tr,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = Fmt.parseNumber(v);
                      if (n == null || n <= 0 || n > 10000) return '1–10000 W';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _QtyStepper(value: _qty, onChanged: (v) => setState(() => _qty = v)),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 12),
                      child: Text('How many'.tr, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('USED PER DAY'.tr, style: theme.textTheme.labelSmall),
                const Spacer(),
                Text(_hoursLabel(_hours), style: theme.textTheme.titleMedium),
              ],
            ),
            Slider(
              value: _hours.clamp(0, 24).toDouble(),
              min: 0,
              max: 24,
              divisions: 96,
              label: _hoursLabel(_hours),
              onChanged: (v) => setState(() => _hours = v),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final h in _hourChips)
                  ChoiceChip(
                    label: Text(_hoursLabel(h)),
                    selected: (_hours - h).abs() < 0.01,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _hours = h),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(child: _Est(label: 'Per day'.tr, value: '${Fmt.oneDp(_dailyUnits)} units')),
                  Expanded(child: _Est(label: 'Per month'.tr, value: Fmt.units(units))),
                  Expanded(child: _Est(label: 'Costs about'.tr, value: '${Fmt.rs(units * rate)}/mo')),
                ],
              ),
            ),
            if (nonInverterAc && units > 0) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 18, color: p.safe),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'An inverter AC uses about half: roughly {0} less, {1} a month.'.trf({'0': Fmt.units(units * 0.47), '1': Fmt.rs(units * 0.47 * rate)}),
                      style: theme.textTheme.bodySmall?.copyWith(color: p.safe, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            LoadingButton(
              label: isNew ? 'Add appliance'.tr : 'Save changes'.tr,
              loading: _saving,
              onPressed: _save,
              icon: isNew ? Icons.add_rounded : Icons.check_rounded,
            ),
          ],
        ),
      ),
    );
  }

  static String _hoursLabel(double h) {
    if (h <= 0) return '0 h';
    if (h < 1) return '{0} min'.trf({'0': (h * 60).round()});
    final t = h == h.roundToDouble() ? h.toInt().toString() : h.toStringAsFixed(1);
    return '$t h';
  }
}

class _Est extends StatelessWidget {
  const _Est({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, style: theme.textTheme.titleSmall),
        ),
      ],
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 54,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 28,
            child: Text('$value', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          ),
          IconButton(
            onPressed: value < 50 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
