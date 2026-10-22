import 'package:flutter/material.dart';

import '../../core/constants/saving_tips.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/urdu_text.dart';
import '../../shared/widgets/art.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  static String _art(String category) => switch (category) {
        'slab' => Art.barChart,
        'other' => Art.plug,
        _ => Art.forCategory(category),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Saving tips')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: SavingTips.all.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final tip = SavingTips.all[i];
          return AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArtTile(_art(tip.category), size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(tip.en, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      UrduText(
                        tip.ur,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
