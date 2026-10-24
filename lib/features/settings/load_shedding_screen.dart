import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/load_shedding.dart';
import '../../services/reminders/reminder_planner.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/app_state.dart';
import 'widgets/notification_permission.dart';

/// Reminders → Power cuts: the daily load-shedding times to warn about.
class LoadSheddingScreen extends StatelessWidget {
  const LoadSheddingScreen({super.key});

  static const int maxSlots = 12;

  static String _clock(int minutes) => Fmt.clock(minutes ~/ 60 % 24, minutes % 60);

  static String label(LoadSheddingSlot s) => '${_clock(s.start)} – ${_clock(s.end)}';

  Future<void> _add(BuildContext context) async {
    final state = context.read<AppState>();
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 14, minute: 0),
      helpText: 'Power goes off at'.tr,
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 2) % 24, minute: start.minute),
      helpText: 'Power comes back at'.tr,
    );
    if (end == null || !context.mounted) return;
    final slot = LoadSheddingSlot(start: start.hour * 60 + start.minute, end: end.hour * 60 + end.minute);
    if (slot.start == slot.end) return;
    final slots = state.loadShedding;
    if (slots.contains(slot)) return;
    await state.setLoadShedding([...slots, slot]);
    if (!state.reminderOn(ReminderType.powerCut)) await state.setReminder(ReminderType.powerCut, true);
    if (context.mounted) await NotificationPermission.ensure(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final slots = state.loadShedding;
    final on = state.remindersEnabled && state.reminderOn(ReminderType.powerCut);

    return Scaffold(
      appBar: AppBar(title: Text('Power cuts'.tr)),
      floatingActionButton: slots.length >= maxSlots
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded),
              label: Text('Add time'.tr),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              secondary: const ArtTile(Art.battery, size: 44),
              title: Text('Power-cut alerts'.tr, style: theme.textTheme.titleMedium),
              subtitle: Text('15 minutes before your load-shedding time'.tr),
              value: on,
              onChanged: (v) async {
                if (v && !state.remindersEnabled) await state.setRemindersEnabled(true);
                await state.setReminder(ReminderType.powerCut, v);
                if (v && context.mounted) await NotificationPermission.ensure(context);
              },
            ),
          ),
          SectionHeader('Your load-shedding times'.tr),
          if (slots.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ArtImage(Art.hourglass, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No times yet. Add the times your area\'s power goes off — check your company\'s load-shedding schedule or ask a neighbour.'
                          .tr,
                      style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                    ),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, s) in slots.indexed) ...[
                    ListTile(
                      leading: const ArtTile(Art.battery, size: 40),
                      title: Text(label(s), textDirection: TextDirection.ltr),
                      subtitle: Text(
                        s.minutes % 60 == 0
                            ? (s.minutes == 60 ? '1 hour'.tr : '{0} hours'.trf({'0': s.minutes ~/ 60}))
                            : '{0} min'.trf({'0': s.minutes}),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove'.tr,
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => state.setLoadShedding([...slots]..removeAt(i)),
                      ),
                    ),
                    if (i < slots.length - 1) const Divider(indent: 70),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              'The alert repeats every day at these times, even if you don\'t open the app. Change them when your schedule changes.'
                  .tr,
              style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}
