import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/l10n.dart';
import '../../readings/readings_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/meter.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/hero_style.dart';
import '../../../state/app_state.dart';
import 'bill_breakdown_sheet.dart';

/// Simple Home: units this month, the bill, and one place to add a reading.
class SimpleHome extends StatelessWidget {
  const SimpleHome({super.key, required this.summary, required this.onAddReading});

  final CycleSummary summary;

  /// Opens the full Add reading screen (photo, other dates, TOU/solar).
  final VoidCallback onAddReading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UnitsCard(summary: summary),
        const SizedBox(height: 14),
        _BillCard(summary: summary),
        const SizedBox(height: 14),
        QuickReadingCard(onOpenFull: onAddReading),
      ],
    );
  }
}

class _UnitsCard extends StatelessWidget {
  const _UnitsCard({required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = HeroStyle.of(context);
    final p = AppPalette.of(context);
    final s = summary;
    final target = s.targetLimit;
    final budget = s.safeDailyBudget;

    final (String title, String body, Color color) = switch (s.status) {
      _ when s.isTou => (
          'Peak / off-peak meter'.tr,
          'About {n} units by month end.'.trf({'n': Fmt.whole(s.projectedUnits)}),
          h.accent,
        ),
      UsageStatus.safe => (
          'You\'re on track'.tr,
          'Up to {b} units a day keeps you under {t}.'.trf({'b': Fmt.oneDp(budget ?? 0), 't': target ?? 0}),
          p.safe,
        ),
      UsageStatus.warn => (
          'Close to {t} units'.trf({'t': target ?? 0}),
          'Keep it under {b} units a day to stay in this slab.'.trf({'b': Fmt.oneDp(budget ?? 0)}),
          p.warn,
        ),
      UsageStatus.danger => (
          'Slow down'.tr,
          'Use at most {b} units a day to stay under {t}.'.trf({'b': Fmt.oneDp(budget ?? 0), 't': target ?? 0}),
          p.danger,
        ),
      UsageStatus.overLimits => (
          'Highest slab'.tr,
          'Every extra unit costs more. Check your biggest appliances.'.tr,
          p.danger,
        ),
      UsageStatus.noData => ('', '', h.accent),
    };

    return AppCard(
      gradient: h.gradient,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('UNITS THIS MONTH'.tr, style: theme.textTheme.labelSmall?.copyWith(color: h.muted)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: h.faint, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '{n} days left'.trf({'n': s.daysLeft}),
                  style: theme.textTheme.labelMedium?.copyWith(color: h.fg, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.whole(s.unitsUsed),
                  style: theme.textTheme.displayMedium?.copyWith(color: h.fg, fontWeight: FontWeight.w800, height: 1)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  target == null ? 'units'.tr : 'of {t} units'.trf({'t': target}),
                  style: theme.textTheme.titleMedium?.copyWith(color: h.muted),
                ),
              ),
            ],
          ),
          if (target != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: s.progress,
                minHeight: 10,
                color: s.status == UsageStatus.safe ? (h.dark ? AppColors.amber : AppColors.amberDeep) : color,
                backgroundColor: h.track,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(color: h.dark ? Colors.white : color)),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: h.fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = summary.estimateNow.total;
    final end = summary.estimateProjected.total;
    String rs(double v) => v < 0 ? '−${Fmt.rs(-v)}' : Fmt.rs(v);

    return AppCard(
      onTap: () => BillBreakdownSheet.show(context, summary),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const ArtTile(Art.receipt, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR BILL SO FAR'.tr, style: theme.textTheme.labelSmall),
                Text(rs(now), style: theme.textTheme.headlineSmall),
                Text(
                  'About {rs} by month end'.trf({'rs': rs(end)}),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.amberDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// Type today's reading and save it right on Home. TOU and solar meters
/// need two numbers, so they get a button to the full screen instead.
class QuickReadingCard extends StatefulWidget {
  const QuickReadingCard({super.key, required this.onOpenFull});

  final VoidCallback onOpenFull;

  @override
  State<QuickReadingCard> createState() => _QuickReadingCardState();
}

class _QuickReadingCardState extends State<QuickReadingCard> {
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
    final last = state.latestReading;
    final n = Fmt.parseNumber(_value.text);
    String? error;
    if (n == null || n <= 0 || n > 9999999) {
      error = 'Enter the number on your meter'.tr;
    } else if (last != null && n < last.value) {
      error = 'Lower than your last reading ({n})'.trf({'n': Fmt.whole(last.value)});
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
      if (mounted) showSnack(context, '${'Could not save'.tr}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final last = state.latestReading;
    final readToday = last != null && DateUtils.isSameDay(last.date, DateX.today());
    final standard = (state.activeMeter?.meterType ?? MeterType.standard) == MeterType.standard;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ArtTile(Art.stopwatch, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(readToday ? 'Today\'s reading is saved'.tr : 'Add today\'s reading'.tr,
                        style: theme.textTheme.titleMedium),
                    if (last != null)
                      Text(
                        'Last: {v} on {d}'.trf({'v': Fmt.whole(last.value), 'd': Fmt.dayShort(last.date)}),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (last != null)
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const ReadingsScreen())),
                  child: Text('See all'.tr),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (readToday)
            OutlinedButton.icon(
              onPressed: widget.onOpenFull,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text('Change or add another'.tr),
            )
          else if (!standard)
            FilledButton.icon(
              onPressed: widget.onOpenFull,
              icon: const Icon(Icons.add_rounded),
              label: Text('Add reading'.tr),
            )
          else ...[
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
                    style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 1.5),
                    decoration: InputDecoration(
                      hintText: last == null ? 'e.g. 12450' : '> ${Fmt.whole(last.value)}',
                      suffixText: 'kWh'.tr,
                      errorText: _error,
                      errorMaxLines: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 58,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(minimumSize: const Size(92, 58)),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.navy),
                          )
                        : Text('Save'.tr),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: widget.onOpenFull,
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: Text('Take a photo of the meter instead'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
