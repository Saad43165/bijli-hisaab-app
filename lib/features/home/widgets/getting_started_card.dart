import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/meter.dart';
import '../../../data/models/meter_reading.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/hero_style.dart';
import '../../../state/app_state.dart';
import '../../../core/l10n/l10n.dart';

/// Navy "This month" card shown until this month's units can be worked out.
/// Lets the user type today's reading right here instead of a separate screen.
class GettingStartedCard extends StatefulWidget {
  const GettingStartedCard({
    super.key,
    required this.summary,
    required this.latest,
    required this.onAddReading,
    required this.onScanBill,
  });

  final CycleSummary summary;
  final MeterReading? latest;

  /// Opens the full Add reading screen (meter camera, other dates, TOU/solar).
  final VoidCallback onAddReading;
  final VoidCallback onScanBill;

  @override
  State<GettingStartedCard> createState() => _GettingStartedCardState();
}

class _GettingStartedCardState extends State<GettingStartedCard> {
  final _value = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final n = Fmt.parseNumber(_value.text);
    final last = widget.latest;
    String? error;
    if (n == null || n <= 0 || n > 9999999) {
      error = 'Enter the number on your meter';
    } else if (last != null && n < last.value) {
      error = 'Lower than your last reading (${Fmt.whole(last.value)})';
    }
    setState(() => _error = error);
    if (error != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await state.addReading(n!, DateX.today());
      _value.clear();
      HapticFeedback.mediumImpact();
      if (mounted) showSnack(context, 'Reading saved'.tr);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = HeroStyle.of(context);
    final muted = h.muted;
    // An amber button would vanish on the light (amber) card.
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: h.dark ? AppColors.amber : AppColors.navy,
      foregroundColor: h.dark ? AppColors.navy : Colors.white,
    );
    final s = widget.summary;
    final last = widget.latest;
    final meterType = context.select<AppState, MeterType>((a) => a.activeMeter?.meterType ?? MeterType.standard);
    final today = DateX.today();
    final readToday = last != null && DateUtils.isSameDay(last.date, today);
    // TOU and solar meters need two numbers: use the full screen for those.
    final inline = meterType == MeterType.standard && !readToday;

    final String title;
    final String body;
    if (last == null) {
      title = 'What does your meter say today?'.tr;
      body = 'Type the number on the meter display (kWh). We\'ll track your units from here.'.tr;
    } else if (readToday) {
      title = 'Today\'s reading is saved'.tr;
      body = 'Started at ${Fmt.whole(last.value)}. Come back in a day or two and add another reading — '
          'then you\'ll see your units, month-end forecast and slab warning here.';
    } else {
      final days = DateX.daysBetween(last.date, today);
      title = 'Add today\'s reading to see your units'.tr;
      body = 'Last reading ${Fmt.whole(last.value)}, $days ${days == 1 ? 'day' : 'days'} ago.';
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      gradient: h.gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'THIS MONTH · ${Fmt.dayShort(s.cycleStart)} – '
                  '${Fmt.dayShort(s.cycleEnd.subtract(const Duration(days: 1)))}',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: h.faint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${s.daysLeft} days left',
                  style: theme.textTheme.labelMedium?.copyWith(color: h.fg, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleLarge?.copyWith(color: h.fg, height: 1.2)),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
          const SizedBox(height: 16),
          if (inline) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _value,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    style: theme.textTheme.headlineSmall?.copyWith(color: h.fg, letterSpacing: 1.5),
                    cursorColor: h.accent,
                    decoration: InputDecoration(
                      hintText: last == null ? 'e.g. 12450' : 'more than ${Fmt.whole(last.value)}',
                      hintStyle: theme.textTheme.titleMedium?.copyWith(color: muted.withValues(alpha: 0.6)),
                      filled: true,
                      fillColor: h.dark ? h.faint : Colors.white.withValues(alpha: 0.75),
                      suffixText: 'kWh'.tr,
                      suffixStyle: TextStyle(color: muted),
                      errorText: _error,
                      errorStyle: TextStyle(color: h.dark ? const Color(0xFFFF9B9B) : AppColors.dangerLight),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: h.track),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 58,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: buttonStyle.copyWith(minimumSize: const WidgetStatePropertyAll(Size(88, 58))),
                    child: _saving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: h.dark ? AppColors.navy : Colors.white),
                          )
                        : Text('Save'.tr),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ] else if (!readToday) ...[
            FilledButton.icon(
              style: buttonStyle,
              onPressed: widget.onAddReading,
              icon: const Icon(Icons.add_rounded),
              label: Text('Add reading'.tr),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: _Link(
                  h: h,
                  icon: Icons.photo_camera_rounded,
                  label: readToday ? 'Change reading'.tr : 'Photo of meter'.tr,
                  onTap: widget.onAddReading,
                ),
              ),
              Expanded(
                child: _Link(
                  h: h,
                  icon: Icons.document_scanner_rounded,
                  label: 'Scan last bill'.tr,
                  onTap: widget.onScanBill,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.h, required this.icon, required this.label, required this.onTap});

  final HeroStyle h;

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: h.fg, alignment: Alignment.centerLeft),
      icon: Icon(icon, size: 18, color: h.dark ? AppColors.amber : AppColors.amberDeep),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}
