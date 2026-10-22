import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/appliance.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/hero_style.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/app_state.dart';
import '../../shared/widgets/art.dart';
import 'widgets/appliance_pie_chart.dart';
import 'widgets/appliance_sheet.dart';
import 'widgets/appliance_tile.dart';
import 'widgets/quick_setup.dart';
import 'widgets/what_if_card.dart';

class AppliancesScreen extends StatelessWidget {
  const AppliancesScreen({super.key});

  Future<void> _edit(BuildContext context, [Appliance? a]) => ApplianceSheet.show(context, existing: a);

  Future<void> _delete(BuildContext context, Appliance a) async {
    final state = context.read<AppState>();
    final ok = await confirmDialog(
      context,
      title: 'Remove ${a.name}?',
      message: 'It will be removed from your estimate.',
      confirmLabel: 'Remove',
    );
    if (ok) await state.deleteAppliance(a);
  }

  Future<void> _duplicate(BuildContext context, Appliance a) async {
    final state = context.read<AppState>();
    await state.saveAppliance(Appliance(
      meterId: a.meterId,
      name: '${a.name} (2)',
      category: a.category,
      watts: a.watts,
      quantity: a.quantity,
      hoursPerDay: a.hoursPerDay,
      createdAt: DateTime.now(),
    ));
    if (context.mounted) showSnack(context, 'Copied — tap it to change hours or name');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final items = [...state.appliances]..sort((a, b) => b.monthlyUnits.compareTo(a.monthlyUnits));
    final total = state.applianceMonthlyUnits;
    final rate = state.marginalRate;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 20,
        titleTextStyle: theme.textTheme.headlineSmall,
        title: const Text('Appliances'),
        actions: [
          if (items.isNotEmpty)
            TextButton.icon(
              onPressed: () => QuickSetup.show(context),
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Quick add'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: items.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
      body: items.isEmpty
          ? QuickSetup(onCustom: () => _edit(context))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                _SummaryCard(total: total, rate: rate),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WHERE YOUR UNITS GO', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 12),
                      ApplianceDonut(appliances: items, totalUnits: total),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _InsightCard(top: items.first, total: total, rate: rate),
                if (items.any((a) => a.hoursPerDay >= 0.5 && a.id != null)) ...[
                  const SizedBox(height: 12),
                  WhatIfCard(appliances: [for (final a in items) if (a.hoursPerDay >= 0.5 && a.id != null) a]),
                ],
                SectionHeader(
                  'Your appliances (${items.length})',
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                ),
                for (var i = 0; i < items.length; i++) ...[
                  ApplianceTile(
                    appliance: items[i],
                    share: total == 0 ? 0 : items[i].monthlyUnits / total,
                    monthlyCost: items[i].monthlyUnits * rate,
                    color: i < 6 ? ApplianceDonut.colorAt(i) : AppColors.chart.last,
                    onTap: () => _edit(context, items[i]),
                    onDuplicate: () => _duplicate(context, items[i]),
                    onDelete: () => _delete(context, items[i]),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
                Text(
                  'Costs use ${Fmt.rate(rate)} per unit — the rate of your slab, before taxes.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

/// Total units and cost, checked against what the meter or bill says.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.rate});

  final double total;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final h = HeroStyle.of(context);
    final muted = h.muted;
    final bill = state.estimateFor(total.round());

    // What the meter says: this month's projection, else the last bill.
    final s = state.summary;
    final double? metered = s != null && s.hasData
        ? s.projectedUnits
        : (state.bills.isNotEmpty ? state.bills.first.units.toDouble() : null);
    final source = s != null && s.hasData ? 'this month\'s forecast' : 'your last bill';
    final coverage = metered == null || metered <= 0 ? null : total / metered;

    String? advice;
    if (coverage != null && metered != null) {
      if (coverage < 0.75) {
        advice = 'About ${Fmt.whole(metered - total)} units are missing — add things you forgot '
            '(motor, iron, geyser) or raise the hours.';
      } else if (coverage > 1.3) {
        advice = 'That\'s more than your meter shows — some hours are probably too high.';
      } else {
        advice = 'Close to your meter — this estimate is good.';
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      gradient: h.gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('YOUR APPLIANCES USE ABOUT', style: theme.textTheme.labelSmall?.copyWith(color: muted)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.whole(total),
                  style: theme.textTheme.displaySmall?.copyWith(color: h.fg, height: 1)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('units a month', style: theme.textTheme.titleMedium?.copyWith(color: muted)),
              ),
            ],
          ),
          if (bill != null) ...[
            const SizedBox(height: 4),
            Text(
              'A bill of about ${Fmt.rs(bill.total)} with taxes',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: h.dark ? AppColors.amber : AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (coverage != null && metered != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Your meter: ~${Fmt.whole(metered)} units ($source)',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                ),
                Text('${(coverage * 100).round()}% explained',
                    style: theme.textTheme.labelLarge?.copyWith(color: h.fg)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: coverage.clamp(0, 1).toDouble(),
                minHeight: 8,
                color: coverage < 0.75 || coverage > 1.3
                    ? (h.dark ? AppColors.warnDark : AppColors.warnLight)
                    : (h.dark ? AppColors.safeDark : AppColors.safeLight),
                backgroundColor: h.track,
              ),
            ),
            const SizedBox(height: 8),
            Text(advice!, style: theme.textTheme.bodySmall?.copyWith(color: h.fg)),
          ],
        ],
      ),
    );
  }
}

/// "Your AC is 62% of your use — 1 hour less a day saves Rs 1,200."
class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.top, required this.total, required this.rate});

  final Appliance top;
  final double total;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (total <= 0) return const SizedBox.shrink();
    final share = (top.monthlyUnits / total * 100).round();
    final hourUnits = top.watts * top.quantity * 30 / 1000;
    final canSave = top.hoursPerDay >= 1.5;
    return AppCard(
      elevated: false,
      color: theme.colorScheme.secondary.withValues(alpha: 0.10),
      borderColor: theme.colorScheme.secondary.withValues(alpha: 0.30),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArtTile(Art.forAppliance(top.name, top.category), size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${top.name} is $share% of your use', style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  canSave
                      ? 'Using it 1 hour less a day saves about ${Fmt.units(hourUnits)} '
                          'and ${Fmt.rs(hourUnits * rate)} a month.'
                      : 'It\'s your biggest user — check its hours per day are right.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
