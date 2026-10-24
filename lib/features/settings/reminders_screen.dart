import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/meter.dart';
import '../../services/notification_service.dart';
import '../../services/reminders/reminder_planner.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/info_banner.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/app_state.dart';
import '../../core/l10n/l10n.dart';
import 'widgets/notification_permission.dart';

/// Tools → Reminders.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  static String art(ReminderType t) => switch (t) {
        ReminderType.readingDay => Art.calendar,
        ReminderType.closeToSlab => Art.bolt,
        ReminderType.billDue => Art.receipt,
        ReminderType.noReading => Art.stopwatch,
        ReminderType.weeklySummary => Art.barChart,
        ReminderType.peakHours => Art.hourglass,
      };

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> with WidgetsBindingObserver {
  NotificationHealth? _health;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkHealth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Android settings: show whether the fix worked.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkHealth();
  }

  Future<void> _checkHealth() async {
    final h = await NotificationService.instance.health();
    if (mounted) setState(() => _health = h);
  }

  /// Turning something on first makes sure notifications are allowed.
  Future<void> _turnOn(Future<void> Function() change) async {
    await change();
    if (mounted) await NotificationPermission.ensure(context);
    await _checkHealth();
  }

  Widget _healthBanner(NotificationHealth h) {
    final service = NotificationService.instance;
    if (!h.allowed) {
      return InfoBanner(
        icon: Icons.notifications_off_rounded,
        color: AppColors.dangerLight,
        title: 'Notifications are off'.tr,
        message: 'You won\'t get slab warnings or bill reminders.'.tr,
        actionLabel: 'Turn on'.tr,
        onAction: () async {
          await NotificationPermission.ensure(context);
          await _checkHealth();
        },
      );
    }
    if (!h.exactAlarms) {
      return InfoBanner(
        icon: Icons.alarm_rounded,
        title: 'Alerts may come late'.tr,
        message: 'Allow "Alarms & reminders" so alerts arrive on time.'.tr,
        actionLabel: 'Allow'.tr,
        onAction: service.openExactAlarmSettings,
      );
    }
    return InfoBanner(
      icon: Icons.battery_alert_rounded,
      title: 'Battery saver may block reminders'.tr,
      message: 'Some phones stop reminders when the app is closed. Set battery use to "Unrestricted".'.tr,
      actionLabel: 'Fix'.tr,
      onAction: service.openBatterySettings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final on = state.remindersEnabled;
    final upcoming = state.upcomingReminders;
    final isTou = state.activeMeter?.meterType == MeterType.tou;
    final types = [for (final t in ReminderType.values) if (t != ReminderType.peakHours || isTou) t];

    return Scaffold(
      appBar: AppBar(title: Text('Reminders & alerts'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (_health != null && !_health!.allGood) ...[
            _healthBanner(_health!),
            const SizedBox(height: 12),
          ],
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              secondary: const ArtTile(Art.bell, size: 44),
              title: Text('Smart reminders'.tr, style: theme.textTheme.titleMedium),
              subtitle: Text('Only when it matters — based on your readings, slab and bill'.tr),
              value: on,
              onChanged: (v) => v ? _turnOn(() => state.setRemindersEnabled(true)) : state.setRemindersEnabled(false),
            ),
          ),
          SectionHeader('Remind me about'.tr),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: on ? 1 : 0.5,
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, t) in types.indexed) ...[
                    SwitchListTile(
                        secondary: ArtTile(RemindersScreen.art(t), size: 40),
                        title: Text(t.label),
                        subtitle: Text(t.description),
                        value: state.reminderOn(t),
                        onChanged: on
                            ? (v) => v ? _turnOn(() => state.setReminder(t, true)) : state.setReminder(t, false)
                            : null,
                      ),
                    if (i < types.length - 1) const Divider(indent: 70),
                  ],
                ],
              ),
            ),
          ),
          SectionHeader('Instant alert'.tr),
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: const ArtTile(Art.warning, size: 40),
              title: Text('Slab warning'.tr),
              subtitle: Text('Right after a reading that puts you over a limit'.tr),
              value: state.slabAlertsEnabled,
              onChanged: (v) =>
                  v ? _turnOn(() => state.setSlabAlertsEnabled(true)) : state.setSlabAlertsEnabled(false),
            ),
          ),
          SectionHeader('Coming up'.tr),
          if (!on || upcoming.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ArtImage(Art.hourglass, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      !on
                          ? 'Smart reminders are off.'.tr
                          : 'Nothing scheduled right now. Reminders appear here as your reading day, slab limit or bill due date gets close.'.tr,
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
                  for (final (i, r) in upcoming.indexed) ...[
                    _UpcomingTile(reminder: r),
                    if (i < upcoming.length - 1) const Divider(indent: 70),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              'Reminders update every time you add a reading or bill. Nothing is sent before 9 am or after 9:30 pm.'.tr,
              style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.reminder});

  final PlannedReminder reminder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final w = reminder.when;
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(w.year, w.month, w.day).difference(today).inDays;
    final day = switch (days) {
      0 => 'Today'.tr,
      1 => 'Tomorrow'.tr,
      _ => DateFormat('EEE d MMM', L10n.language).format(w),
    };
    return ListTile(
      leading: ArtTile(RemindersScreen.art(reminder.type), size: 40),
      title: Text(reminder.title),
      subtitle: Text(reminder.body, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(day, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(DateFormat('h:mm a', L10n.language).format(w), style: theme.textTheme.labelSmall),
        ],
      ),
      isThreeLine: true,
    );
  }
}
