import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/meter.dart';
import '../../data/models/meter_reading.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/loading_button.dart';
import '../../services/bill_scan_analyzer.dart' show FieldConfidence;
import '../../services/meter_reading_extractor.dart';
import '../../shared/widgets/art.dart';
import '../../state/app_state.dart';
import 'meter_camera_screen.dart';
import 'readings_screen.dart';
import '../../core/l10n/l10n.dart';

class AddReadingScreen extends StatefulWidget {
  const AddReadingScreen({super.key});

  @override
  State<AddReadingScreen> createState() => _AddReadingScreenState();
}

class _AddReadingScreenState extends State<AddReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();

  /// TOU: peak register. Solar: export register. Unused on normal meters.
  final _second = TextEditingController();
  DateTime _date = DateX.today();
  bool _saving = false;

  /// Last meter photo and what was read from it.
  String? _photoPath;
  MeterReadResult? _scan;

  @override
  void dispose() {
    _value.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateX.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 120)),
      lastDate: today,
      helpText: 'Reading date',
    );
    if (picked != null) {
      setState(() => _date = picked);
      _formKey.currentState?.validate();
    }
  }

  Future<void> _scanMeter() async {
    final state = context.read<AppState>();
    final before = state.readingBefore(_date);
    final days = before == null ? 30 : DateX.daysBetween(before.date, _date);
    FocusScope.of(context).unfocus();
    final outcome = await Navigator.of(context).push<MeterScanOutcome>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MeterCameraScreen(
          lastReading: before == null ? null : _mainOf(before, _type(state)),
          daysSinceLast: days < 1 ? 1 : days,
        ),
      ),
    );
    if (outcome == null || !mounted) return;
    final best = outcome.result.best;
    setState(() {
      _photoPath = outcome.imagePath;
      _scan = outcome.result;
      if (best != null) _value.text = best.value.round().toString();
    });
    _formKey.currentState?.validate();
  }

  void _useCandidate(MeterCandidate c) {
    HapticFeedback.selectionClick();
    setState(() => _value.text = c.value.round().toString());
    _formKey.currentState?.validate();
  }

  /// 'photo' when the saved number is one the scan suggested.
  String _sourceFor(double value) {
    final scan = _scan;
    if (scan == null) return 'manual';
    return scan.candidates.any((c) => c.value.round() == value.round()) ? 'photo' : 'manual';
  }

  MeterType _type(AppState state) => state.activeMeter?.meterType ?? MeterType.standard;

  /// The value saved as the reading: off-peak + peak on TOU meters, the
  /// import register on solar meters, the display on normal meters.
  double? _total(AppState state) {
    final main = Fmt.parseNumber(_value.text);
    if (main == null) return null;
    if (_type(state) != MeterType.tou) return main;
    final peak = Fmt.parseNumber(_second.text);
    return peak == null ? null : main + peak;
  }

  /// The previous reading's value for the register in the main field.
  static double? _mainOf(MeterReading r, MeterType t) => t == MeterType.tou ? r.offPeakValue : r.value;

  /// The previous reading's value for the register in the second field.
  static double? _secondOf(MeterReading r, MeterType t) => switch (t) {
        MeterType.tou => r.peakValue,
        MeterType.netMetering || MeterType.netBilling => r.exportValue,
        MeterType.standard => null,
      };

  String? _validate(String? v, AppState state, {bool second = false}) {
    final t = _type(state);
    final n = Fmt.parseNumber(v);
    if (n == null) {
      if (!second) return 'Enter the number shown on your meter';
      return t == MeterType.tou ? 'Enter the peak reading'.tr : 'Enter the export reading'.tr;
    }
    if (n < 0 || n > 9999999) return 'That doesn\'t look like a meter reading';
    final before = state.readingBefore(_date);
    if (before != null && DateX.dateOnly(before.date) != DateX.dateOnly(_date)) {
      final prev = second ? _secondOf(before, t) : _mainOf(before, t);
      if (prev != null && n < prev) {
        return 'Lower than {0} on {1}. Check the digits.'.trf({'0': Fmt.whole(prev), '1': Fmt.dayShort(before.date)});
      }
    }
    return null;
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final type = _type(state);
    final value = _total(state)!;
    final second = Fmt.parseNumber(_second.text);

    final before = state.readingBefore(_date);
    if (before != null && DateX.dateOnly(before.date) != DateX.dateOnly(_date)) {
      final days = DateX.daysBetween(before.date, _date);
      final perDay = days > 0 ? (value - before.value) / days : 0;
      if (perDay > 150) {
        final ok = await confirmDialog(
          context,
          title: 'Check this reading'.tr,
          message: 'That is {0} units a day since your last reading, which is unusually high. Save anyway?'.trf({'0': Fmt.whole(perDay)}),
          confirmLabel: 'Save'.tr,
          destructive: false,
        );
        if (!ok) return;
      }
    }

    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await state.addReading(
        value,
        _date,
        source: _sourceFor(Fmt.parseNumber(_value.text)!),
        peakValue: type == MeterType.tou ? second : null,
        exportValue: type.isSolar ? second : null,
      );
      if (!mounted) return;
      showSnack(context, 'Reading saved'.tr);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save reading: {0}'.trf({'0': e}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final last = state.latestReading;
    final type = _type(state);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add reading'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReadingsScreen()),
            ),
            child: Text('All readings'.tr),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ScanMeterButton(onPressed: _scanMeter),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or type it'.tr, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: 'e.g. 12450',
                  hintStyle: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                  labelText: switch (type) {
                    MeterType.standard => null,
                    MeterType.tou => 'Off-peak (kWh)'.tr,
                    MeterType.netMetering || MeterType.netBilling => 'Import · from grid (kWh)'.tr,
                  },
                  helperText: switch (type) {
                    MeterType.standard =>
                      'Number on the meter display (kWh). Skip digits in red or after a decimal point.'.tr,
                    MeterType.tou => 'Your meter shows each register in turn — note off-peak and peak.'.tr,
                    MeterType.netMetering ||
                    MeterType.netBilling =>
                      'Your meter shows import and export in turn — often marked 1.8.0 and 2.8.0.'.tr,
                  },
                  helperMaxLines: 2,
                  suffixIcon: IconButton(
                    tooltip: 'Scan meter'.tr,
                    icon: const Icon(Icons.photo_camera_rounded),
                    onPressed: _scanMeter,
                  ),
                ),
                validator: (v) => _validate(v, state),
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => _save(),
              ),
              if (type != MeterType.standard) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _second,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 2),
                  decoration: InputDecoration(
                    labelText: type == MeterType.tou ? 'Peak (kWh)'.tr : 'Export · to grid (kWh)'.tr,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  ),
                  validator: (v) => _validate(v, state, second: true),
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _save(),
                ),
              ],
              if (_scan != null && _photoPath != null) ...[
                const SizedBox(height: 12),
                _ScanResultCard(
                  imagePath: _photoPath!,
                  result: _scan!,
                  current: Fmt.parseNumber(_value.text),
                  onPick: _useCandidate,
                  onRetake: _scanMeter,
                ),
              ],
              _DeltaPreview(value: _total(state), date: _date),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_rounded),
                label: Text(_date == DateX.today() ? 'Today, {0}'.trf({'0': Fmt.day(_date)}) : Fmt.day(_date)),
              ),
              if (last != null) ...[
                const SizedBox(height: 20),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const ArtTile(Art.stopwatch, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Last reading: {0} on {1}'.trf({'0': Fmt.whole(last.value), '1': Fmt.day(last.date)}),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              LoadingButton(label: 'Save reading'.tr, loading: _saving, onPressed: _save, icon: Icons.check_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live "+42 units in 4 days (10.5/day)" under the reading field.
class _DeltaPreview extends StatelessWidget {
  const _DeltaPreview({required this.value, required this.date});

  final double? value;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final before = context.read<AppState>().readingBefore(date);
    final v = value;
    String? text;
    if (v != null && before != null && DateX.dateOnly(before.date) != DateX.dateOnly(date)) {
      final days = DateX.daysBetween(before.date, date);
      final units = v - before.value;
      if (units >= 0 && days > 0) {
        text = '+{0} units in {1} {2} · {3} a day'.trf({'0': Fmt.whole(units), '1': days, '2': days == 1 ? 'day'.tr : 'days'.tr, '3': Fmt.oneDp(units / days)});
      }
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(text, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
    );
  }
}

/// Big "Scan meter" call to action at the top of Add reading.
class _ScanMeterButton extends StatelessWidget {
  const _ScanMeterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const ArtTile(Art.camera, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scan meter'.tr, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      'Point your camera at the meter display'.tr,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Photo thumbnail, how sure the scan is, and "Did you mean" chips.
class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({
    required this.imagePath,
    required this.result,
    required this.current,
    required this.onPick,
    required this.onRetake,
  });

  final String imagePath;
  final MeterReadResult result;
  final double? current;
  final ValueChanged<MeterCandidate> onPick;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final (label, color, icon) = switch (result.confidence) {
      FieldConfidence.high => ('Read from photo', p.safe, Icons.check_circle_rounded),
      FieldConfidence.medium => ('Check it matches your meter', p.warn, Icons.visibility_rounded),
      FieldConfidence.low => ('Not sure — please check the digits', p.danger, Icons.error_outline_rounded),
    };
    final others = result.candidates.where((c) => current == null || c.value.round() != current!.round()).toList();

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showPhoto(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(imagePath),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    cacheWidth: 192,
                    errorBuilder: (_, _, _) => const SizedBox(width: 64, height: 64),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onRetake, child: Text('Retake'.tr)),
            ],
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Did you mean'.tr, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in others)
                  ActionChip(
                    label: Text(c.value.round().toString(), style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                    onPressed: () => onPick(c),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showPhoto(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(File(imagePath), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
