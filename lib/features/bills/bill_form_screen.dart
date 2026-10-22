import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/bill.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/loading_button.dart';
import '../../state/app_state.dart';
import '../../core/l10n/l10n.dart';

/// Add a bill by hand, or edit a saved one. (Scanned bills use
/// ScanReviewScreen.)
class BillFormScreen extends StatefulWidget {
  const BillFormScreen({super.key, this.existing});

  final Bill? existing;

  @override
  State<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _units;
  late final TextEditingController _amount;
  late final TextEditingController _present;
  late String _month;
  DateTime? _dueDate;
  bool _saveReading = true;
  bool _saving = false;

  late final List<String> _monthOptions;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    final now = DateTime.now();
    _monthOptions = [
      for (var i = 0; i < 24; i++) Fmt.monthKey(DateTime(now.year, now.month - i)),
    ];

    _month = e?.month ?? Fmt.monthKey(now);
    if (!_monthOptions.contains(_month)) _monthOptions.insert(0, _month);

    _units = TextEditingController(text: e?.units.toString() ?? '');
    final amount = e?.amount;
    _amount = TextEditingController(text: amount == null || amount == 0 ? '' : Fmt.whole(amount));
    final present = e?.presentReading;
    _present = TextEditingController(text: present == null ? '' : Fmt.whole(present).replaceAll(',', ''));
    _dueDate = e?.dueDate;
  }

  @override
  void dispose() {
    _units.dispose();
    _amount.dispose();
    _present.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Due date',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = context.read<AppState>();
    final meter = state.activeMeter;
    if (meter?.id == null) return;

    final bill = Bill(
      id: widget.existing?.id,
      meterId: meter!.id!,
      month: _month,
      units: Fmt.parseNumber(_units.text)!.round(),
      amount: Fmt.parseNumber(_amount.text) ?? 0,
      dueDate: _dueDate,
      presentReading: Fmt.parseNumber(_present.text),
      source: widget.existing?.source ?? 'manual',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    setState(() => _saving = true);
    try {
      await state.saveBill(bill, original: widget.existing, addReadingFromBill: _saveReading);
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Bill updated'.tr : 'Bill saved'.tr);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save bill: {0}'.trf({'0': e}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final bill = widget.existing;
    if (bill?.id == null) return;
    final state = context.read<AppState>();
    final ok = await confirmDialog(
      context,
      title: 'Delete bill?'.tr,
      message: '{0} ({1} units) will be removed.'.trf({'0': Fmt.monthKeyLabel(bill!.month), '1': bill.units}),
    );
    if (!ok) return;
    await state.deleteBill(bill.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final digits = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
    final readingDay = context.read<AppState>().activeMeter?.readingDay ?? 1;
    final m = Fmt.parseMonthKey(_month);
    final readingDate = DateX.clampedDay(m.year, m.month, readingDay);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit bill'.tr : 'Add bill'.tr),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete'.tr,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _FieldLabel('Bill month'),
              DropdownButtonFormField<String>(
                initialValue: _month,
                menuMaxHeight: 360,
                items: [
                  for (final k in _monthOptions)
                    DropdownMenuItem(value: k, child: Text(Fmt.monthKeyLabel(k))),
                ],
                onChanged: (v) => setState(() => _month = v ?? _month),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Units consumed'),
              TextFormField(
                controller: _units,
                keyboardType: TextInputType.number,
                inputFormatters: [digits],
                decoration: InputDecoration(hintText: 'e.g. 214', suffixText: 'units'.tr),
                validator: (v) {
                  final n = Fmt.parseNumber(v);
                  if (n == null || n < 0) return 'Enter units from the bill';
                  if (n > 99999) return 'Too large';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _FieldLabel('Payable within due date'),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [digits],
                decoration: InputDecoration(
                  hintText: 'Optional · e.g. 3,299'.tr,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Text('Rs'.tr, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Due date'),
              // Looks like the text fields around it, opens a date picker.
              InkWell(
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  isEmpty: _dueDate == null,
                  decoration: InputDecoration(
                    hintText: 'Optional · choose date'.tr,
                    prefixIcon: const Icon(Icons.event_rounded),
                    suffixIcon: _dueDate == null
                        ? null
                        : IconButton(
                            tooltip: 'Clear'.tr,
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => _dueDate = null),
                          ),
                  ),
                  child: Text(_dueDate == null ? '' : Fmt.day(_dueDate!),
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Present reading'),
              TextFormField(
                controller: _present,
                keyboardType: TextInputType.number,
                inputFormatters: [digits],
                decoration: InputDecoration(hintText: 'Optional · e.g. 12450'.tr),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _saveReading,
                onChanged: (v) => setState(() => _saveReading = v ?? true),
                title: Text('Also save it as a meter reading'.tr),
                subtitle: Text('Dated {0} (your reading day)'.trf({'0': Fmt.day(readingDate)})),
              ),
              const SizedBox(height: 20),
              LoadingButton(label: _isEdit ? 'Save changes'.tr : 'Save bill'.tr, loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Row(
        children: [
          Text(text, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
