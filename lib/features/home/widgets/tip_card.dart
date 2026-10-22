import 'package:flutter/material.dart';

import '../../../core/constants/saving_tips.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/urdu_text.dart';
import '../../settings/tips_screen.dart';
import '../../../shared/widgets/art.dart';

/// Today's saving tip in English and Urdu; tap for all tips.
class TipCard extends StatelessWidget {
  const TipCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tip = SavingTips.ofTheDay();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const TipsScreen()),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ArtTile(Art.bulb, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tip.en, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.35)),
                const SizedBox(height: 6),
                UrduText(
                  tip.ur,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
