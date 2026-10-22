import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/companies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/app_state.dart';
import '../../meters/meters_screen.dart';
import '../../../shared/widgets/art.dart';
import '../../../shared/widgets/company_badge.dart';
import '../../../core/l10n/l10n.dart';

/// App-bar title showing the active meter; tap to switch meters.
class MeterSwitcher extends StatelessWidget {
  const MeterSwitcher({super.key});

  Future<void> _open(BuildContext context) async {
    final state = context.read<AppState>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Switch meter'.tr, style: theme.textTheme.titleMedium),
              ),
              for (final m in state.meters)
                ListTile(
                  leading: CompanyBadge(PowerCompanies.of(m.disco), size: 42),
                  title: Text(m.name),
                  subtitle: Text('${PowerCompanies.of(m.disco).shortCode} · ${m.city}'),
                  trailing: m.id == state.activeMeter?.id
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.amberDeep)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (m.id != null) state.setActiveMeter(m.id!);
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: Text('Manage meters'.tr),
                onTap: () {
                  final nav = Navigator.of(context);
                  Navigator.pop(ctx);
                  nav.push(
                    MaterialPageRoute<void>(builder: (_) => const MetersScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final meter = state.activeMeter;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            meter == null
                ? const ArtTile(Art.brandBolt, onNavy: true, size: 44)
                : CompanyBadge(PowerCompanies.of(meter.disco), size: 44),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meter?.name ?? 'Bijli Hisaab',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meter != null)
                    Text(
                      '${PowerCompanies.of(meter.disco).shortCode}${meter.city.isEmpty ? '' : ' · ${meter.city}'}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
