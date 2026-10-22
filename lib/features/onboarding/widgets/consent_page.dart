import 'package:flutter/material.dart';

import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import '../../../core/l10n/l10n.dart';

class ConsentPage extends StatelessWidget {
  const ConsentPage({super.key, required this.consent, required this.onChanged});

  final bool consent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        const Align(alignment: Alignment.centerLeft, child: ArtTile(Art.shield, size: 72)),
        const SizedBox(height: 18),
        Text('Your data stays on your phone'.tr, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Readings, bills and appliances are saved only on this device. No account, no login, works offline.'.tr,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            children: [
              _Row(art: Art.lock, text: 'Your reference number is kept on this phone only — never sent anywhere.'.tr),
              _Row(art: Art.camera, text: 'Bill photos are read on your phone, never uploaded.'.tr),
              _Row(art: Art.chartUp, text: 'Only electricity rates are downloaded — nothing about you is sent.'.tr),
              _Row(art: Art.globe, text: 'Android can back up your data to your own Google account.'.tr),
              _Row(art: Art.check, text: 'Delete everything any time from Tools → Reset app.'.tr),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: consent,
            onChanged: onChanged,
            title: Text('Help improve Bijli Hisaab'.tr, style: theme.textTheme.titleSmall),
            subtitle: Text(
              'Allow exporting anonymous usage data (city, DISCO, units, events). You choose when to share it. Optional.'.tr,
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.art, required this.text});

  final String art;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          ArtTile(art, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
