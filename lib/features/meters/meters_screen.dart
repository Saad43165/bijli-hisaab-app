import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/companies.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/company_badge.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/status_pill.dart';
import '../../state/app_state.dart';
import 'meter_edit_screen.dart';
import '../../core/l10n/l10n.dart';

class MetersScreen extends StatelessWidget {
  const MetersScreen({super.key});

  void _open(BuildContext context, {int? meterId}) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => MeterEditScreen(meterId: meterId)),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Meters'.tr)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        icon: const Icon(Icons.add_rounded),
        label: Text('Add meter'.tr),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          for (final m in state.meters) ...[
            AppCard(
              onTap: () => _open(context, meterId: m.id),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CompanyBadge(PowerCompanies.of(m.disco), size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '{0} · {1} · reading day {2}'.trf({'0': PowerCompanies.of(m.disco).shortCode, '1': m.city, '2': m.readingDay}),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (m.id == state.activeMeter?.id)
                    const TagBadge('Active', color: AppColors.amberDeep)
                  else
                    TextButton(
                      onPressed: () => state.setActiveMeter(m.id!),
                      child: Text('Use'.tr),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
