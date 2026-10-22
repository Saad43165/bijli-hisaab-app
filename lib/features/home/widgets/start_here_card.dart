import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/meter.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import '../../../state/app_state.dart';
import '../../../core/l10n/l10n.dart';

/// "Start here" checklist: the five things that make the app useful, ticked
/// off automatically. Shows new users what the app is for and what to do next.
class StartHereCard extends StatelessWidget {
  const StartHereCard({
    super.key,
    required this.onReading,
    required this.onBill,
    required this.onAppliances,
    required this.onMeterType,
  });

  /// Settings flags.
  static const dismissedKey = 'start_here_dismissed';
  static const meterTypeKey = 'meter_type_checked';

  final VoidCallback onReading;
  final VoidCallback onBill;
  final VoidCallback onAppliances;
  final VoidCallback onMeterType;

  /// Whether the card should show at all.
  static bool visible(AppState s) => !s.uiFlag(dismissedKey) && _done(s).where((d) => d).length < 5;

  static List<bool> _done(AppState s) => [
        s.activeMeter != null,
        s.readings.isNotEmpty,
        s.bills.isNotEmpty,
        s.appliances.isNotEmpty,
        s.uiFlag(meterTypeKey) || (s.activeMeter?.meterType ?? MeterType.standard) != MeterType.standard,
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final state = context.watch<AppState>();
    final done = _done(state);
    final count = done.where((d) => d).length;

    final steps = [
      ('Add your meter'.tr, 'Company, load and reading day'.tr, null),
      ('Add a meter reading'.tr, 'Every few days — this drives the forecast'.tr, onReading),
      ('Scan or add your last bill'.tr, 'Fills your reading and shows protected-rate status'.tr, onBill),
      ('Count your appliances'.tr, 'See which ones cost you the most'.tr, onAppliances),
      ('Check your meter type'.tr, 'Normal, solar or peak/off-peak (TOU)'.tr, onMeterType),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ArtTile(Art.check, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('START HERE · {n} OF 5 DONE'.trf({'n': count}), style: theme.textTheme.labelSmall),
                    Text('Get the most from Bijli Hisaab'.tr, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hide'.tr,
                onPressed: () => state.setUiFlag(dismissedKey, true),
                icon: Icon(Icons.close_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 10, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: count / 5),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  color: AppColors.amber,
                  backgroundColor: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
          for (var i = 0; i < steps.length; i++)
            InkWell(
              onTap: done[i] ? null : steps[i].$3,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done[i] ? p.safe : Colors.transparent,
                        border: Border.all(color: done[i] ? p.safe : theme.colorScheme.outline, width: 2),
                      ),
                      child: done[i]
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : Text('${i + 1}', style: theme.textTheme.labelSmall),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].$1,
                            style: theme.textTheme.titleSmall?.copyWith(
                              decoration: done[i] ? TextDecoration.lineThrough : null,
                              color: done[i] ? theme.colorScheme.onSurfaceVariant : null,
                            ),
                          ),
                          if (!done[i]) Text(steps[i].$2, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (!done[i]) Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
