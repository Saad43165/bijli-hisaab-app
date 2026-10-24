import 'package:flutter/material.dart';

import '../../core/constants/faq.dart';
import '../../core/l10n/l10n.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/unofficial_notice.dart';
import '../assistant/assistant_avatar.dart';
import '../assistant/assistant_screen.dart';

/// How the app works in four steps, then common questions. The assistant
/// can answer anything else.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  /// Bottom sheet: where the reference number is printed on the bill.
  static Future<void> showReferenceHelp(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Where is the reference number?'.tr, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              // A small drawing of the top of a bill.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ELECTRICITY CONSUMER BILL', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade700, width: 2),
                      ),
                      child: Text(
                        'REFERENCE NO   06 14562 1211000 U',
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('BILL MONTH  ·  DUE DATE  ·  PAYABLE', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'It\'s near the top of every bill: 14 digits, often written in groups (2 + 5 + 7). Leave out the letter at the end. You can also find it on an old bill, an SMS from your company, or your bank\'s bill payment history.'
                    .tr,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget step(int n, String art, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArtTile(art, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('{0}. {1}'.trf({'0': n, '1': title}), style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text('Guide & help'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AssistantScreen())),
            child: Row(
              children: [
                const AssistantAvatar(size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ask the assistant'.tr, style: theme.textTheme.titleMedium),
                      Text(
                        'Ask anything, in English or Urdu — it can also do things for you.'.tr,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
          SectionHeader('How it works'.tr),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              children: [
                step(
                  1,
                  Art.receipt,
                  'Your bills come in by themselves'.tr,
                  'With your reference number, the app gets each new bill, saves it and reminds you before the due date.'
                      .tr,
                ),
                step(
                  2,
                  Art.chartUp,
                  'See where you stand'.tr,
                  'Home shows what you owe, when, and what the next bill will roughly be. History shows every month.'
                      .tr,
                ),
                step(
                  3,
                  Art.shield,
                  'Stay on cheap rates'.tr,
                  'Keep every bill at 200 units or less for 6 months to get protected rates. The app warns you before you cross.'
                      .tr,
                ),
                step(
                  4,
                  Art.stopwatch,
                  'Want live tracking? (optional)'.tr,
                  'Add your meter reading once a week, and you\'ll see this month\'s units and warnings before the bill comes.'
                      .tr,
                ),
              ],
            ),
          ),
          SectionHeader('Common questions'.tr),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, f) in Faq.all.indexed) ...[
                  ExpansionTile(
                    shape: const Border(),
                    title: Text(f.question.tr, style: theme.textTheme.titleSmall),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedAlignment: AlignmentDirectional.centerStart,
                    children: [Text(f.answer.tr, style: theme.textTheme.bodyMedium)],
                  ),
                  if (i < Faq.all.length - 1) const Divider(height: 1, indent: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const UnofficialNotice(),
        ],
      ),
    );
  }
}
