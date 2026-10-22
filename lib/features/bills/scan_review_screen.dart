import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/companies.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/bill.dart';
import '../../services/bill_ocr_service.dart';
import '../../services/bill_scan_analyzer.dart';
import '../../services/bill_values.dart';
import '../../services/image_rotation.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/info_banner.dart';
import '../../shared/widgets/loading_button.dart';
import '../../state/app_state.dart';
import 'widgets/scanned_page_viewer.dart';
import '../../core/l10n/l10n.dart';

/// Shows the scanned pages with boxes around what was read, each value with
/// how sure we are, warnings from cross-checks, and lets the user fix,
/// rescan (results are merged) and save.
class ScanReviewScreen extends StatefulWidget {
  const ScanReviewScreen({super.key, required this.initial});

  final BillScanResult initial;

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ocr = BillOcrService();
  final _units = TextEditingController();
  final _amount = TextEditingController();
  final _present = TextEditingController();

  late List<String> _images;
  late BillScanAnalysis _a;
  late String _month;
  late List<String> _monthOptions;
  DateTime? _due;
  BillField? _selected;
  int _page = 0;
  bool _saveReading = true;
  bool _saving = false;
  bool _rescanning = false;

  /// Fields the user typed into — never overwritten by a rescan.
  final Set<BillField> _edited = {};

  @override
  void initState() {
    super.initState();
    _images = [...widget.initial.imagePaths];
    _a = widget.initial.analysis;
    final now = DateTime.now();
    _monthOptions = [for (var i = 0; i < 24; i++) Fmt.monthKey(DateTime(now.year, now.month - i))];
    _month = Fmt.monthKey(now);
    _applyAnalysis();
    _units.addListener(() => _markEdited(BillField.units, _units));
    _amount.addListener(() => _markEdited(BillField.amount, _amount));
    _present.addListener(() => _markEdited(BillField.presentReading, _present));
  }

  String _lastUnits = '', _lastAmount = '', _lastPresent = '';

  void _markEdited(BillField f, TextEditingController c) {
    final last = switch (f) {
      BillField.units => _lastUnits,
      BillField.amount => _lastAmount,
      _ => _lastPresent,
    };
    if (c.text != last) _edited.add(f);
  }

  void _setText(TextEditingController c, String v, BillField f) {
    if (_edited.contains(f)) return;
    switch (f) {
      case BillField.units:
        _lastUnits = v;
      case BillField.amount:
        _lastAmount = v;
      default:
        _lastPresent = v;
    }
    c.text = v;
  }

  void _applyAnalysis() {
    final a = _a;
    if (a.units != null) _setText(_units, '${a.units!.value}', BillField.units);
    if (a.amount != null) _setText(_amount, Fmt.whole(a.amount!.value), BillField.amount);
    if (a.presentReading != null) {
      _setText(_present, a.presentReading!.value.round().toString(), BillField.presentReading);
    }
    if (a.month != null && !_edited.contains(BillField.month)) {
      _month = a.month!.value;
      if (!_monthOptions.contains(_month)) _monthOptions.insert(0, _month);
    }
    if (a.dueDate != null && !_edited.contains(BillField.dueDate)) _due = a.dueDate!.value;
  }

  @override
  void dispose() {
    _units.dispose();
    _amount.dispose();
    _present.dispose();
    super.dispose();
  }

  ScanField<Object>? _field(BillField f) => switch (f) {
        BillField.month => _a.month,
        BillField.units => _a.units,
        BillField.amount => _a.amount,
        BillField.dueDate => _a.dueDate,
        BillField.presentReading => _a.presentReading,
        BillField.previousReading => _a.previousReading,
        BillField.multiplier => _a.multiplier,
        BillField.load => _a.load,
        BillField.readingDate => _a.readingDate,
      };

  void _select(BillField f) {
    final src = _field(f)?.source;
    setState(() {
      _selected = f;
      if (src != null) _page = src.page;
    });
  }

  Color _colorFor(FieldConfidence c, AppPalette p) => switch (c) {
        FieldConfidence.high => p.safe,
        FieldConfidence.medium => AppColors.amberDeep,
        FieldConfidence.low => p.danger,
      };

  List<PageHighlight> _highlights(AppPalette p) => [
        for (final f in [BillField.month, BillField.units, BillField.amount, BillField.dueDate, BillField.presentReading])
          if (_field(f)?.source != null)
            PageHighlight(
              box: _field(f)!.source!.box,
              page: _field(f)!.source!.page,
              color: _colorFor(_field(f)!.confidence, p),
              selected: _selected == f,
            ),
      ];

  Future<void> _rescan() async {
    final state = context.read<AppState>();
    setState(() => _rescanning = true);
    try {
      List<String> imgs;
      try {
        imgs = await _ocr.capture(state.smartScanner ? CaptureSource.smartScanner : CaptureSource.camera);
      } on SmartScannerUnavailable {
        imgs = await _ocr.capture(CaptureSource.camera);
      }
      final result = await _ocr.read(imgs, estimateAmount: state.estimateBillFor, expectedCompany: state.activeMeter?.disco);
      if (!mounted) return;
      // Re-number the new pages after the existing ones so highlights match.
      final offset = _images.length;
      final shifted = _shiftPages(result.analysis, offset);
      setState(() {
        _images = [..._images, ...result.imagePaths];
        _a = _a.mergeWith(shifted);
        _applyAnalysis();
      });
      HapticFeedback.lightImpact();
      showSnack(context, 'Added {0} — kept the best values'.trf({'0': result.imagePaths.length == 1 ? 'page'.tr : 'pages'.tr}));
    } on ScanCancelled {
      // nothing
    } catch (e) {
      if (mounted) showSnack(context, 'Couldn\'t read that scan: {0}'.trf({'0': e}));
    } finally {
      if (mounted) setState(() => _rescanning = false);
    }
  }

  /// Turns one page a quarter clockwise and reads all pages again in the
  /// orientation the user chose. Values the user typed are kept.
  Future<void> _rotatePage(int index) async {
    if (_rescanning) return;
    final state = context.read<AppState>();
    setState(() => _rescanning = true);
    try {
      final rotated = await rotateImageFile(_images[index], 1);
      final images = [..._images]..[index] = rotated;
      final result = await _ocr.read(images, estimateAmount: state.estimateBillFor, autoRotate: false, expectedCompany: state.activeMeter?.disco);
      if (!mounted) return;
      setState(() {
        _images = result.imagePaths;
        _a = result.analysis;
        _page = index;
        _applyAnalysis();
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Couldn\'t rotate the page: {0}'.trf({'0': e}));
    } finally {
      if (mounted) setState(() => _rescanning = false);
    }
  }

  static BillScanAnalysis _shiftPages(BillScanAnalysis a, int offset) {
    ScanField<T>? s<T>(ScanField<T>? f) {
      final src = f?.source;
      if (f == null || src == null) return f;
      return ScanField(f.value, f.confidence,
          source: OcrLine(src.text, src.box, page: src.page + offset), note: f.note);
    }

    return BillScanAnalysis(
      month: s(a.month),
      units: s(a.units),
      amount: s(a.amount),
      dueDate: s(a.dueDate),
      presentReading: s(a.presentReading),
      previousReading: s(a.previousReading),
      multiplier: s(a.multiplier),
      disco: a.disco,
      load: s(a.load),
      readingDate: s(a.readingDate),
      reference: a.reference,
      warnings: a.warnings,
      rawText: a.rawText,
      pageCount: a.pageCount,
    );
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Due date',
    );
    if (picked != null) {
      setState(() {
        _due = picked;
        _edited.add(BillField.dueDate);
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = context.read<AppState>();
    final meter = state.activeMeter;
    if (meter?.id == null) return;
    setState(() => _saving = true);
    try {
      await state.saveBill(
        Bill(
          meterId: meter!.id!,
          month: _month,
          units: Fmt.parseNumber(_units.text)!.round(),
          amount: Fmt.parseNumber(_amount.text) ?? 0,
          dueDate: _due,
          presentReading: Fmt.parseNumber(_present.text),
          source: 'scan',
          createdAt: DateTime.now(),
        ),
        addReadingFromBill: _saveReading,
      );
      // Remember the reference number the first time we read it.
      final ref = _a.reference;
      final sameCompany = _a.disco == null || _a.disco == meter.disco;
      if (ref != null && meter.referenceNo.isEmpty && sameCompany) {
        await state.updateMeter(meter.copyWith(referenceNo: ref));
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showSnack(context, 'Bill saved'.tr);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save bill: {0}'.trf({'0': e}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final state = context.watch<AppState>();
    final meter = state.activeMeter;
    final digits = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
    final m = Fmt.parseMonthKey(_month);
    final readingDate = DateX.clampedDay(m.year, m.month, meter?.readingDay ?? 1);
    final otherCompany = _a.disco != null && meter != null && _a.disco != meter.disco;

    return Scaffold(
      appBar: AppBar(
        title: Text('Check scanned bill'.tr),
        actions: [
          TextButton.icon(
            onPressed: _rescanning || _saving ? null : _rescan,
            icon: _rescanning
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_a_photo_outlined, size: 20),
            label: Text('Scan again'.tr),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              ScannedPageViewer(
                imagePaths: _images,
                highlights: _highlights(p),
                page: _page,
                onPageChanged: (i) => setState(() => _page = i),
                onRotate: _rescanning || _saving ? null : _rotatePage,
              ),
              if (_rescanning) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 3),
              ],
              const SizedBox(height: 12),
              _SummaryRow(analysis: _a),
              if (otherCompany) ...[
                const SizedBox(height: 10),
                InfoBanner(
                  icon: Icons.swap_horiz_rounded,
                  color: p.danger,
                  title: 'This looks like a {0} bill'.trf({'0': PowerCompanies.of(_a.disco!).shortCode}),
                  message: '"{0}" is set to {1}. Switch meter first if this bill is for another connection.'.trf({'0': meter.name, '1': PowerCompanies.of(meter.disco).shortCode}),
                ),
              ],
              for (final w in _a.warnings) ...[
                const SizedBox(height: 10),
                InfoBanner(icon: Icons.error_outline_rounded, color: p.warn, message: w),
              ],
              const SizedBox(height: 16),
              _FieldCard(
                label: 'Bill month'.tr,
                field: _a.month,
                selected: _selected == BillField.month,
                onTap: () => _select(BillField.month),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('month-$_month'),
                  initialValue: _month,
                  isExpanded: true,
                  menuMaxHeight: 360,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final k in _monthOptions) DropdownMenuItem(value: k, child: Text(Fmt.monthKeyLabel(k))),
                  ],
                  onTap: () => _select(BillField.month),
                  onChanged: (v) => setState(() {
                    _month = v ?? _month;
                    _edited.add(BillField.month);
                  }),
                ),
              ),
              _FieldCard(
                label: 'Units consumed'.tr,
                field: _a.units,
                selected: _selected == BillField.units,
                onTap: () => _select(BillField.units),
                child: TextFormField(
                  controller: _units,
                  keyboardType: TextInputType.number,
                  inputFormatters: [digits],
                  onTap: () => _select(BillField.units),
                  decoration: InputDecoration(isDense: true, suffixText: 'units'.tr, hintText: 'e.g. 214'),
                  validator: (v) {
                    final n = Fmt.parseNumber(v);
                    if (n == null || n < 0) return 'Enter units from the bill';
                    if (n > 99999) return 'Too large';
                    return null;
                  },
                ),
              ),
              _FieldCard(
                label: 'Payable within due date'.tr,
                field: _a.amount,
                selected: _selected == BillField.amount,
                onTap: () => _select(BillField.amount),
                child: TextFormField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [digits],
                  onTap: () => _select(BillField.amount),
                  decoration: InputDecoration(isDense: true, prefixText: 'Rs  ', hintText: 'Optional'.tr),
                ),
              ),
              _FieldCard(
                label: 'Due date'.tr,
                field: _a.dueDate,
                selected: _selected == BillField.dueDate,
                onTap: () => _select(BillField.dueDate),
                child: OutlinedButton.icon(
                  onPressed: () {
                    _select(BillField.dueDate);
                    _pickDue();
                  },
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(_due == null ? 'Optional'.tr : Fmt.day(_due!)),
                ),
              ),
              _FieldCard(
                label: 'Present reading'.tr,
                field: _a.presentReading,
                selected: _selected == BillField.presentReading,
                onTap: () => _select(BillField.presentReading),
                extra: _a.previousReading == null
                    ? null
                    : 'Previous reading {0}{1}'.trf({'0': _a.previousReading!.value.round(), '1': _a.multiplier != null && _a.multiplier!.value != 1 ? ' · MF ${_a.multiplier!.value.round()}' : ''}),
                child: TextFormField(
                  controller: _present,
                  keyboardType: TextInputType.number,
                  inputFormatters: [digits],
                  onTap: () => _select(BillField.presentReading),
                  decoration: InputDecoration(isDense: true, hintText: 'Optional · e.g. 12450'.tr),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _saveReading,
                onChanged: (v) => setState(() => _saveReading = v ?? true),
                title: Text('Also save present reading as a meter reading'.tr),
                subtitle: Text('Dated {0} (your reading day)'.trf({'0': Fmt.day(readingDate)})),
              ),
              const SizedBox(height: 8),
              LoadingButton(label: 'Save bill'.tr, icon: Icons.check_rounded, loading: _saving, onPressed: _save),
              const SizedBox(height: 12),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const ArtImage(Art.search, size: 26),
                  title: Text('What the scanner read'.tr, style: theme.textTheme.titleSmall),
                  subtitle: Text('{0} {1} · tap to see raw text'.trf({'0': _a.pageCount, '1': _a.pageCount == 1 ? 'page'.tr : 'pages'.tr}),
                      style: theme.textTheme.bodySmall),
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(12),
                      elevated: false,
                      child: SelectableText(
                        _a.rawText.trim().isEmpty ? 'No text found.'.tr : _a.rawText.trim(),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _a.rawText));
                          showSnack(context, 'Copied — paste it to report a misread bill'.tr);
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: Text('Copy text'.tr),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.analysis});

  final BillScanAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final found = analysis.foundCount;
    final check = analysis.needsCheckCount;
    final String art;
    final String title;
    if (found == 0) {
      art = Art.warning;
      title = 'Couldn\'t read values — please type them'.tr;
    } else if (check > 0) {
      art = Art.search;
      title = 'Found {0} of 5 · {1} to check'.trf({'0': found, '1': check});
    } else {
      art = Art.check;
      title = 'Found {0} of 5 values'.trf({'0': found});
    }
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ArtTile(art, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _Legend(color: p.safe, text: 'Sure'.tr),
                    _Legend(color: AppColors.amberDeep, text: 'Likely'.tr),
                    _Legend(color: p.danger, text: 'Check'.tr),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color, width: 2),
              color: color.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 5),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

/// One value with its confidence badge; highlighted on the photo when tapped.
class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.label,
    required this.field,
    required this.selected,
    required this.onTap,
    required this.child,
    this.extra,
  });

  final String label;
  final ScanField<Object>? field;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final f = field;
    final (Color color, String badge, IconData icon) = switch (f?.confidence) {
      FieldConfidence.high => (p.safe, 'Sure', Icons.check_circle_rounded),
      FieldConfidence.medium => (AppColors.amberDeep, 'Likely', Icons.adjust_rounded),
      FieldConfidence.low => (p.danger, 'Check this', Icons.error_rounded),
      null => (p.muted, 'Not found', Icons.remove_circle_outline_rounded),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : Colors.transparent, width: 2),
        ),
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
                  const Spacer(),
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(badge,
                      style: theme.textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0.2)),
                ],
              ),
              const SizedBox(height: 8),
              child,
              if (f?.note != null || extra != null) ...[
                const SizedBox(height: 6),
                Text(
                  [if (f?.note != null) f!.note!, if (extra != null) extra!].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
