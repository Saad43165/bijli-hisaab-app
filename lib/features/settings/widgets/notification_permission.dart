import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../services/notification_service.dart';
import '../../../shared/widgets/art.dart';

/// Explains why before Android's "Allow notifications?" dialog, which can be
/// shown only twice before Android stops asking.
class NotificationPermission {
  NotificationPermission._();

  /// True when notifications are allowed (asking first if they aren't).
  /// When Android won't show its dialog any more, opens the app's
  /// notification settings instead.
  static Future<bool> ensure(BuildContext context) async {
    final service = NotificationService.instance;
    if (await service.notificationsAllowed) return true;
    if (!context.mounted) return false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => const _ExplainSheet(),
    );
    if (ok != true) return false;
    if (await service.requestPermission()) return true;
    // Denied before: the system dialog doesn't appear again.
    await service.openNotificationSettings();
    return false;
  }
}

class _ExplainSheet extends StatelessWidget {
  const _ExplainSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget point(String art, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              ArtImage(art, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: ArtImage(Art.bell, size: 56)),
            const SizedBox(height: 12),
            Text('Allow notifications?'.tr, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Bijli Hisaab only notifies you when it matters:'.tr, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            point(Art.warning, 'Before you cross a slab and your bill jumps'.tr),
            point(Art.receipt, 'Before your bill is due'.tr),
            point(Art.calendar, 'Before your meter reading day'.tr),
            point(Art.battery, 'Before power cuts you add'.tr),
            const SizedBox(height: 4),
            Text('No ads, and nothing before 9 am or after 9:30 pm except power cuts.'.tr,
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('Allow'.tr)),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Not now'.tr)),
            ),
          ],
        ),
      ),
    );
  }
}
