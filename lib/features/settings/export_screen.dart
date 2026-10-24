import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/export_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/loading_button.dart';
import '../../state/app_state.dart';
import '../../shared/widgets/art.dart';
import '../../core/l10n/l10n.dart';

/// Explains what is exported, then shares 5 CSV files for Power BI.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _busy = false;
  ExportResult? _last;

  Future<void> _export() async {
    final state = context.read<AppState>();
    if (!state.analyticsConsent) {
      final ok = await confirmDialog(
        context,
        title: 'Allow anonymous export?'.tr,
        message: 'The files contain city, DISCO, units, bills and app events — no names, phone numbers, reference numbers or addresses.'.tr,
        confirmLabel: 'Allow'.tr,
        destructive: false,
      );
      if (!ok) return;
      await state.setAnalyticsConsent(true);
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final result = await state.exportForPowerBi();
      if (mounted) setState(() => _last = result);
    } catch (e) {
      if (mounted) showSnack(context, 'Export failed: {0}'.trf({'0': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final files = [
      ('meters.csv', 'DISCO, city, province, connection, load, protected setting'.tr),
      ('readings.csv', 'Meter readings with dates'.tr),
      ('bills.csv', 'Monthly units, amount, due date, slab band'.tr),
      ('appliances.csv', 'Appliances with estimated monthly units'.tr),
      ('events.csv', 'App usage: opens, readings added, slab warnings'.tr),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Export for Power BI'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              'Share these files with your Power BI dashboard developer. Columns match docs/POWER_BI_DATA_SCHEMA.md in the project.'.tr,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (name, desc) in files)
                    ListTile(
                      leading: const ArtTile(Art.clipboard, size: 40),
                      title: Text(name),
                      subtitle: Text(desc),
                      trailing: _last == null
                          ? null
                          : Text(
                              '{0} rows'.trf({'0': _last!.rowCounts[name.replaceAll('.csv', '')] ?? 0}),
                              style: theme.textTheme.bodySmall,
                            ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ArtTile(Art.lock, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Anonymous ID: {0}\nNo names, phone numbers, bill reference numbers or addresses are included.'.trf({'0': state.installId}),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            LoadingButton(
              label: 'Create & share files'.tr,
              icon: Icons.ios_share_rounded,
              loading: _busy,
              onPressed: _export,
            ),
          ],
        ),
      ),
    );
  }
}
