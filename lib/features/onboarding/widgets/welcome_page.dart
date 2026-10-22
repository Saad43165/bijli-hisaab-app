import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/tariff.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/hero_style.dart';
import '../../../shared/widgets/urdu_text.dart';
import '../../../state/app_state.dart';
import '../../../core/l10n/l10n.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = HeroStyle.of(context);
    final state = context.watch<AppState>();

    // A real number from today's rates: what one unit over 200 costs.
    String? slabFact;
    if (state.hasTariff) {
      double bill(int units) => state.calculator
          .estimate(units, consumerClass: ConsumerClass.unprotected, sanctionedLoadKw: 2, province: 'Punjab')
          .total;
      final jump = bill(201) - bill(200);
      if (jump > 100) slabFact = Fmt.rs(jump);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: h.gradient),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                  child: const ArtImage(Art.brandBolt, size: 76),
                ),
                const SizedBox(height: 16),
                Text(AppConstants.appName,
                    style: theme.textTheme.headlineMedium?.copyWith(color: h.fg, letterSpacing: -0.6)),
                UrduText(
                  AppConstants.appNameUrdu,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: h.dark ? AppColors.amber : AppColors.amberDeep),
                ),
                const SizedBox(height: 10),
                Text(
                  'Know your units before the bill comes'.tr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: h.fg),
                ),
                UrduText(
                  'بل آنے سے پہلے اپنے یونٹ جانیں',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: h.muted),
                ),
              ],
            ),
          ),
        ),
        if (slabFact != null) ...[
          const SizedBox(height: 14),
          FadeSlideIn(
            index: 1,
            child: AppCard(
              elevated: false,
              color: AppPalette.of(context).danger.withValues(alpha: 0.08),
              borderColor: AppPalette.of(context).danger.withValues(alpha: 0.25),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const ArtTile(Art.warning, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          TextSpan(text: 'Did you know? '.tr),
                          TextSpan(
                            text: '201 units costs {0} more than 200'.trf({'0': slabFact}),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: ' — one unit can change your whole bill. We warn you in time.'.tr),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FadeSlideIn(
          index: 2,
          child: _Point(
            art: Art.stopwatch,
            title: 'Track units every few days'.tr,
            text: 'Type or photograph your meter. See units used and the month-end forecast.'.tr,
          ),
        ),
        FadeSlideIn(
          index: 3,
          child: _Point(
            art: Art.bell,
            title: 'Stay under your slab'.tr,
            text: 'A safe daily budget and reminders before you cross 200, 300…'.tr,
          ),
        ),
        FadeSlideIn(
          index: 4,
          child: _Point(
            art: Art.camera,
            title: 'Scan your bill'.tr,
            text: 'Units, amount, due date and reading day — read on your phone.'.tr,
          ),
        ),
        FadeSlideIn(
          index: 5,
          child: _Point(
            art: Art.sun,
            title: 'Solar and TOU meters too'.tr,
            text: 'Export credit, peak/off-peak bills and current NEPRA rates for all 14 companies.'.tr,
          ),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.art, required this.title, required this.text});

  final String art;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          ArtTile(art, size: 50),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(text, style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
