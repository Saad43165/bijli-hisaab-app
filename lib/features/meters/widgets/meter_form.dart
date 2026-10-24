import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/cities.dart';
import '../../../core/constants/companies.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/meter.dart';
import '../../../services/bill_ocr_service.dart';
import '../../../services/bill_scan_analyzer.dart';
import '../../../services/online_bill_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import '../../../state/app_state.dart';
import '../../bills/bill_site_fallback.dart';
import 'company_picker.dart';
import '../../../core/l10n/l10n.dart';

class MeterFormResult {
  const MeterFormResult({required this.meter, this.reading, this.readingDate, this.onlineBill});

  final Meter meter;

  /// Bill fetched online while filling the form; saved with the meter.
  final OnlineBill? onlineBill;
  final double? reading;
  final DateTime? readingDate;
}

/// Meter details form, shared by onboarding and the meter edit screen.
/// Call [MeterFormState.submit] through a GlobalKey to validate and read it.
class MeterForm extends StatefulWidget {
  const MeterForm({super.key, this.initial, this.askForReading = false});

  final Meter? initial;

  /// Show "current meter reading" fields (onboarding / new meter).
  final bool askForReading;

  @override
  State<MeterForm> createState() => MeterFormState();
}

class MeterFormState extends State<MeterForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _load;
  final TextEditingController _reading = TextEditingController();
  late final TextEditingController _reference;
  late MeterType _meterType;
  bool _scanning = false;
  bool _fetching = false;
  OnlineBill? _online;

  late String _disco;
  late String _province;
  final _cityFocus = FocusNode();

  late String _connectionType;
  late String _phase;
  late ProtectedSetting _protected;
  int? _readingDay;
  DateTime _readingDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _name = TextEditingController(text: m?.name ?? 'Home');
    _city = TextEditingController(text: m?.city ?? '');
    _reference = TextEditingController(text: m?.referenceNo ?? '');
    _meterType = m?.meterType ?? MeterType.standard;
    _load = TextEditingController(text: m == null ? '2' : _trim(m.sanctionedLoadKw));
    _disco = m?.disco ?? 'LESCO';
    // Province always fits the company (and the city when we know it). This
    // also fixes meters saved by older versions (IESCO → ICT for Chakwal).
    final allowed = Cities.provincesFor(_disco);
    final fromCity = Cities.provinceOf(m?.city ?? '');
    _province = fromCity != null && allowed.contains(fromCity)
        ? fromCity
        : (m != null && allowed.contains(m.province) ? m.province : allowed.first);
    _connectionType = m?.connectionType ?? 'home';
    _phase = m?.phase ?? 'single';
    _protected = m?.protectedSetting ?? ProtectedSetting.auto;
    // New meters: the user picks it from the bill (or from a scanned bill).
    _readingDay = m?.readingDay;
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// A known city sets the province (when it belongs to this company).
  void _onCity(String city) {
    final p = Cities.provinceOf(city);
    if (p != null && Cities.companyOf(city) == _disco && p != _province) setState(() => _province = p);
  }

  /// New company: keep the city only if it's in that company's area.
  void _setCompany(String code) {
    _disco = code;
    final cityCompany = Cities.companyOf(_city.text);
    if (cityCompany != null && cityCompany != code) _city.clear();
    _province = Cities.provinceFor(code, _city.text);
  }

  @override
  void dispose() {
    _cityFocus.dispose();
    _name.dispose();
    _city.dispose();
    _load.dispose();
    _reading.dispose();
    _reference.dispose();
    super.dispose();
  }

  /// Returns null if the form is invalid.
  MeterFormResult? submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      // The missing field may be scrolled out of view.
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Please check the fields marked in red'.tr)));
      return null;
    }
    final base = widget.initial;
    final meter = Meter(
      id: base?.id,
      name: _name.text.trim(),
      disco: _disco,
      city: _city.text.trim(),
      province: _province,
      connectionType: _connectionType,
      phase: _phase,
      sanctionedLoadKw: Fmt.parseNumber(_load.text) ?? 1,
      protectedSetting: _protected,
      readingDay: _readingDay!,
      createdAt: base?.createdAt ?? DateTime.now(),
      referenceNo: _reference.text.trim(),
      meterType: _meterType,
    );
    return MeterFormResult(
      meter: meter,
      reading: widget.askForReading ? Fmt.parseNumber(_reading.text) : null,
      readingDate: widget.askForReading ? _readingDate : null,
      onlineBill: _online,
    );
  }

  /// Fetches the latest bill from the company's website with the reference
  /// number and fills in load, reading day, protected status and reading.
  Future<void> _fetchOnline() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    FocusScope.of(context).unfocus();
    setState(() => _fetching = true);
    try {
      final b = await state.previewOnlineBill(PowerCompanies.of(_disco), _reference.text);
      if (!mounted) return;
      setState(() {
        _online = b;
        _reference.text = b.reference;
        if (b.sanctionedLoadKw != null && b.sanctionedLoadKw! > 0) _load.text = _trim(b.sanctionedLoadKw!);
        if (b.readingDate != null) _readingDay = b.readingDate!.day;
        if (b.protectedCategory != null) {
          _protected = b.protectedCategory! ? ProtectedSetting.protected : ProtectedSetting.unprotected;
        }
        if (widget.askForReading && b.presentReading != null) {
          _reading.text = b.presentReading!.round().toString();
          final read = b.readingDate;
          if (read != null && !read.isAfter(DateTime.now())) _readingDate = read;
        }
      });
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Found your {0} bill: {1} units, {2}. {3} months of history will be saved.'.trf({
            '0': Fmt.month(b.month),
            '1': b.units,
            '2': Fmt.rs(b.amount),
            '3': b.history.length + 1,
          })),
        ));
    } on OnlineBillException catch (e) {
      if (mounted) BillSiteFallback.snack(context, e, company: PowerCompanies.of(_disco), reference: _reference.text);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  /// Scans a bill and fills in what it can: company, reference number,
  /// sanctioned load, reading day and (for a new meter) the present reading.
  Future<void> _scanBill() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ocr = BillOcrService();
    setState(() => _scanning = true);
    try {
      List<String> images;
      try {
        images = await ocr.capture(state.smartScanner ? CaptureSource.smartScanner : CaptureSource.camera);
      } on SmartScannerUnavailable {
        images = await ocr.capture(CaptureSource.camera);
      }
      final result = await ocr.read(images, expectedCompany: widget.initial?.disco);
      if (!mounted) return;
      final filled = applyScan(result.analysis);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(filled.isEmpty
              ? 'Couldn\'t read the bill. Try again in good light, or fill it in yourself.'.tr
              : 'Filled in: {0}. Please check them.'.trf({'0': filled.join(', ')})),
        ));
    } on ScanCancelled {
      // Backed out — nothing to do.
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Couldn\'t read the bill: {0}'.trf({'0': e}))));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Copies what a scanned bill says into the form; returns what was filled.
  List<String> applyScan(BillScanAnalysis a) {
    final filled = <String>[];
    setState(() {
      final disco = a.disco;
      if (disco != null && PowerCompanies.all.any((c) => c.code == disco)) {
        _setCompany(disco);
        filled.add('company');
      }
      if (a.reference != null) {
        _reference.text = a.reference!;
        filled.add('reference number');
      }
      if (a.load != null) {
        _load.text = _trim(a.load!.value);
        filled.add('load');
      }
      final read = a.readingDate?.value;
      if (read != null) {
        _readingDay = read.day;
        filled.add('reading day');
      }
      final present = a.presentReading?.value;
      if (widget.askForReading && present != null) {
        _reading.text = present.round().toString();
        final today = DateTime.now();
        if (read != null && !read.isAfter(today)) _readingDate = read;
        filled.add('meter reading');
      }
    });
    return filled;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _readingDate,
      firstDate: _readingDate.isBefore(now.subtract(const Duration(days: 60)))
          ? _readingDate
          : now.subtract(const Duration(days: 60)),
      lastDate: now,
    );
    if (picked != null) setState(() => _readingDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: 14);
    final numberFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

    return Form(
      key: _formKey,
      // Clear an error as soon as the field is fixed, instead of on the next submit.
      autovalidateMode: AutovalidateMode.onUserInteractionIfError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            onTap: _scanning ? null : _scanBill,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const ArtTile(Art.receipt, size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fill in from your bill'.tr, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        _scanning
                            ? 'Reading your bill…'.tr
                            : 'Scan it and we\'ll fill in the company, reference number, load and reading day.'.tr,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _scanning
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Icon(Icons.document_scanner_rounded, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
          gap,
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Meter name'.tr,
              hintText: 'Home, Shop, Ammi ka ghar…'.tr,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Give this meter a name'.tr : null,
          ),
          gap,
          CompanyPickerField(
            value: _disco,
            onChanged: (c) => setState(() => _setCompany(c.code)),
          ),
          if (!PowerCompanies.of(_disco).usesNepraTariff) ...[
            const SizedBox(height: 8),
            Text(
              'Your area sets its own electricity tariff. Estimates use NEPRA rates until you enter your own in Tools → Rates.'.tr,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          gap,
          TextFormField(
            controller: _reference,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z ]'))],
            decoration: InputDecoration(
              labelText: 'Reference number (optional)'.tr,
              hintText: 'e.g. 06 14562 1211000 U',
              helperText: 'Printed at the top of your bill. Needed to view or pay the bill online.'.tr,
              helperMaxLines: 2,
            ),
            onChanged: (_) => setState(() => _online = null),
          ),
          if (OnlineBillService.supports(PowerCompanies.of(_disco))) ...[
            const SizedBox(height: 10),
            _online != null
                ? Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bill found — {0} months of history will be added'.trf({'0': _online!.history.length + 1}),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  )
                : FilledButton.tonalIcon(
                    onPressed: _fetching || !OnlineBillService.validReference(_reference.text) ? null : _fetchOnline,
                    icon: _fetching
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_download_rounded),
                    label: Text(_fetching ? 'Getting your bill…'.tr : 'Get my details from my bill online'.tr),
                  ),
          ],
          gap,
          Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => RawAutocomplete<String>(
                    textEditingController: _city,
                    focusNode: _cityFocus,
                    optionsBuilder: (v) => Cities.suggest(v.text, company: _disco)
                        .where((c) => c.toLowerCase() != v.text.trim().toLowerCase()),
                    onSelected: _onCity,
                    fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: 'City (optional)'.tr, errorMaxLines: 3),
                      // Say "that's LESCO's area" while typing, not only on Save.
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final owner = Cities.companyOf(v);
                        if (owner != null && owner != _disco) {
                          return '{0} is in {1}\'s area — change the company above'.trf({'0': v.trim(), '1': PowerCompanies.of(owner).shortCode});
                        }
                        return null;
                      },
                      onChanged: _onCity,
                      onFieldSubmitted: (_) => onSubmit(),
                    ),
                    optionsViewBuilder: (context, onSelected, options) => Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Material(
                        elevation: 6,
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 240, maxWidth: box.maxWidth + 60),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shrinkWrap: true,
                            children: [
                              for (final c in options)
                                ListTile(
                                  dense: true,
                                  title: Text(c),
                                  subtitle: Text(Cities.provinceOf(c) ?? ''),
                                  onTap: () => onSelected(c),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_province),
                  initialValue: _province,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Province'.tr),
                  items: [
                    for (final p in Cities.provincesFor(_disco)) DropdownMenuItem(value: p, child: Text(p)),
                  ],
                  // Locked when the company serves only one province.
                  onChanged: Cities.provincesFor(_disco).length < 2
                      ? null
                      : (v) => setState(() => _province = v ?? _province),
                ),
              ),
            ],
          ),
          gap,
          Text('Connection'.tr, style: theme.textTheme.labelSmall),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: [
              for (final t in AppConstants.connectionTypes)
                ButtonSegment(value: t, label: Text(AppConstants.connectionTypeLabels[t]!.tr)),
            ],
            selected: {_connectionType},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _connectionType = s.first),
          ),
          gap,
          Text('Meter type'.tr, style: theme.textTheme.labelSmall),
          const SizedBox(height: 6),
          SegmentedButton<MeterType>(
            segments: [
              ButtonSegment(value: MeterType.standard, label: Text('Normal'.tr)),
              ButtonSegment(value: MeterType.tou, label: Text('TOU'.tr)),
              ButtonSegment(value: MeterType.netBilling, label: Text('Solar'.tr)),
            ],
            // Both solar schemes show as "Solar"; the agreement picks which.
            selected: {_meterType.isSolar ? MeterType.netBilling : _meterType},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              if (!(s.first.isSolar && _meterType.isSolar)) _meterType = s.first;
            }),
          ),
          const SizedBox(height: 4),
          Text(
            switch (_meterType) {
              MeterType.standard => 'One number on the display.'.tr,
              MeterType.tou => 'Time of use: your bill shows peak and off-peak units (usually 5 kW and above).'.tr,
              MeterType.netMetering ||
              MeterType.netBilling =>
                'Solar: the meter counts units taken from the grid (import) and sent to it (export).'.tr,
            },
            style: theme.textTheme.bodySmall,
          ),
          if (_meterType.isSolar) ...[
            const SizedBox(height: 12),
            Text('When was your solar agreement signed?'.tr, style: theme.textTheme.labelSmall),
            const SizedBox(height: 6),
            SegmentedButton<MeterType>(
              segments: [
                ButtonSegment(value: MeterType.netMetering, label: Text('Before Feb 2026'.tr)),
                ButtonSegment(value: MeterType.netBilling, label: Text('Feb 2026 or later'.tr)),
              ],
              selected: {_meterType},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _meterType = s.first),
            ),
            const SizedBox(height: 4),
            Text(
              _meterType == MeterType.netMetering
                  ? 'Net metering: exported units cancel out imported units; you pay for the difference.'.tr
                  : 'Net billing: imported units are billed at normal rates and exported units are bought back at a lower rate.'.tr,
              style: theme.textTheme.bodySmall,
            ),
          ],
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Meter phase'.tr, style: theme.textTheme.labelSmall),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'single', label: Text('Single'.tr)),
                        ButtonSegment(value: 'three', label: Text('Three'.tr)),
                      ],
                      selected: {_phase},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _phase = s.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: TextFormField(
                    controller: _load,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [numberFormatter],
                    decoration: InputDecoration(labelText: 'Load (kW)'.tr),
                    validator: (v) {
                      final n = Fmt.parseNumber(v);
                      if (n == null || n <= 0 || n > 100) return '1–100';
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sanctioned load is printed on your bill (e.g. "LOAD 2 KW").'.tr,
            style: theme.textTheme.bodySmall,
          ),
          gap,
          Text('Is your bill marked "Protected"?'.tr, style: theme.textTheme.labelSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in [
                (ProtectedSetting.protected, 'Yes'),
                (ProtectedSetting.unprotected, 'No'),
                (ProtectedSetting.lifeline, 'Lifeline'),
                (ProtectedSetting.auto, 'Not sure'.tr),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _protected == value,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _protected = value),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            switch (_protected) {
              ProtectedSetting.protected => 'Protected = 200 units or less in each of the last 6 months.'.tr,
              ProtectedSetting.unprotected => 'Normal rates. Every unit is billed at the rate of the slab you reach.'.tr,
              ProtectedSetting.lifeline => 'Lifeline = single-phase, up to 1 kW load and 100 units or less. Lowest rates.'.tr,
              ProtectedSetting.auto => 'We\'ll work it out from your last 6 bills (add them in History).'.tr,
            },
            style: theme.textTheme.bodySmall,
          ),
          gap,
          DropdownButtonFormField<int>(
            key: ValueKey('reading-day-$_readingDay'),
            initialValue: _readingDay,
            menuMaxHeight: 360,
            hint: Text('Choose day'.tr),
            decoration: InputDecoration(
              labelText: 'Meter reading day'.tr,
              helperText: 'Look for "Reading date" on your bill — the meter reader comes on about the same day every month.'.tr,
              helperMaxLines: 3,
            ),
            items: [
              for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('Day {0}'.trf({'0': d}))),
            ],
            validator: (v) => v == null ? 'Choose the day from "Reading date" on your bill'.tr : null,
            onChanged: (v) => setState(() => _readingDay = v ?? _readingDay),
          ),
          if (_readingDay == null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _readingDay = DateTime.now().day),
                child: Text('Don\'t know? Use today for now'.tr),
              ),
            ),
          if (widget.askForReading) ...[
            const SizedBox(height: 20),
            Text('Current meter reading (optional)'.tr, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Read the number on your meter now, or use "Present reading" from your last bill.'.tr,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _reading,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [numberFormatter],
                    decoration: InputDecoration(labelText: 'Reading (kWh)'.tr, hintText: 'e.g. 12450'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = Fmt.parseNumber(v);
                      if (n == null || n < 0) return 'Enter a valid number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(Fmt.dayShort(_readingDate)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
