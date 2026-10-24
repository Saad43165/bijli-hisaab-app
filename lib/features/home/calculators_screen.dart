import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import 'bill_calculator_screen.dart';
import 'solar_calculator_screen.dart';

/// Tools → Calculators: bill for any number of units, and solar size/payback.
class CalculatorsScreen extends StatelessWidget {
  const CalculatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget item(String art, String title, String body, Widget screen) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)),
            child: Row(
              children: [
                ArtTile(art, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(body, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text('Calculators'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          item(
            Art.moneyBag,
            'Bill calculator'.tr,
            'What a bill of any number of units costs, with taxes.'.tr,
            const BillCalculatorScreen(),
          ),
          item(
            Art.sun,
            'Solar calculator'.tr,
            'How many panels you need and when they pay back.'.tr,
            const SolarCalculatorScreen(),
          ),
        ],
      ),
    );
  }
}
