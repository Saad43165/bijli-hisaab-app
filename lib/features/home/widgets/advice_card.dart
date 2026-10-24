import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/navigation/app_nav.dart';
import '../../../services/advice.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import '../../../state/app_state.dart';
import '../../assistant/assistant_screen.dart';
import '../../assistant/assistant_tools.dart';
import 'bill_overview_card.dart';

/// "What you can do": the most useful next steps from your own bills.
class AdviceCard extends StatelessWidget {
  const AdviceCard({super.key});

  static List<Advice> adviceFor(AppState state) => AdviceEngine(
        estimate: (u, p) => state.estimateAs(u, protectedRates: p),
        protectedLimit: state.tariff.protectedThresholdUnits,
        protectedMonths: state.tariff.protectedMonths,
      ).build(
        newestFirst: state.bills,
        today: DateTime.now(),
        isProtected: state.protection?.consumerClass.hasProtection ?? false,
        predictedNext: BillOverviewCard.nextUnits(state.bills),
        tracking: state.summary?.hasData ?? false,
        latestPaid: state.bills.isNotEmpty && state.isBillPaid(state.bills.first),
        receiptArt: Art.receipt,
        shieldArt: Art.shield,
        warnArt: Art.warning,
        sunArt: Art.sun,
        plugArt: Art.plug,
        meterArt: Art.stopwatch,
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = adviceFor(state);
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final tools = AssistantTools(state);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('WHAT YOU CAN DO'.tr, style: theme.textTheme.labelSmall),
          const SizedBox(height: 6),
          for (final (i, a) in items.indexed) ...[
            if (i > 0) const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArtTile(a.art, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(a.body, style: theme.textTheme.bodySmall),
                      Wrap(
                        spacing: 4,
                        children: [
                          if (a.screen != null)
                            TextButton(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                              onPressed: () => tools.openScreen(a.screen!),
                              child: Text(switch (a.screen) {
                                'bill_online' => 'View bill'.tr,
                                'appliances' => 'Open Appliances'.tr,
                                'add_reading' => 'Add reading'.tr,
                                _ => 'Open'.tr,
                              }),
                            ),
                          if (a.ask != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                              onPressed: () => AppNav.push(AssistantScreen(initialMessage: a.ask)),
                              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                              label: Text('Ask how'.tr),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
