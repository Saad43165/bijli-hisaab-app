import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/bill.dart';
import '../../services/year_comparison.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/hero_style.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/app_state.dart';
import 'bill_form_screen.dart';
import 'past_bills_screen.dart';
import 'scan_bill_screen.dart';
import 'widgets/bill_tile.dart';
import 'widgets/monthly_units_chart.dart';
import 'widgets/protection_card.dart';
import 'widgets/year_compare_card.dart';
import '../../core/l10n/l10n.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _addMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text('Add a bill'.tr, style: Theme.of(ctx).textTheme.titleLarge),
              ),
              ..._addOptions(context, close: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _addOptions(BuildContext context, {VoidCallback? close}) {
    Widget option(String art, String title, String body, Widget screen) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () {
              close?.call();
              _push(context, screen);
            },
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ArtTile(art, size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(body, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );
    return [
      option(Art.camera, 'Scan a bill', 'Units, amount and due date read from a photo', const ScanBillScreen()),
      option(Art.calendar, 'Add past 12 months',
          'Copy the units table printed on your bill — the fastest way to fill a year', const PastBillsScreen()),
      option(Art.memo, 'Type a bill', 'Enter one month by hand', const BillFormScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final bills = state.bills; // newest first
    final chartBills = state.last12Bills;
    final comparisons = YearComparisons.build(bills: bills, summary: state.summary);
    final threshold = state.tariff.protectedThresholdUnits;

    // Bills grouped by year, newest first.
    final years = <int, List<Bill>>{};
    for (final b in bills) {
      years.putIfAbsent(b.monthDate.year, () => []).add(b);
    }

    final cards = <Widget>[
      _YearHero(bills: chartBills),
      MonthlyUnitsChart(bills: chartBills, threshold: threshold),
      ProtectionCard(bills: bills, months: state.tariff.protectedMonths, limit: threshold),
      if (comparisons.isNotEmpty) YearCompareCard(items: comparisons),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 20,
        titleTextStyle: theme.textTheme.headlineSmall,
        title: Text('Bill history'.tr),
        actions: [
          if (bills.isNotEmpty)
            TextButton.icon(
              onPressed: () => _addMenu(context),
              icon: const Icon(Icons.add_rounded),
              label: Text('Add bill'.tr),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: bills.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                FadeSlideIn(
                  child: AppCard(
                    gradient: HeroStyle.of(context).gradient,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const ArtImage(Art.receipt, size: 64),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('See your whole year'.tr,
                                  style: theme.textTheme.titleLarge?.copyWith(color: HeroStyle.of(context).fg)),
                              const SizedBox(height: 4),
                              Text(
                                'Add your bills to see monthly units, what you paid, and whether you qualify for cheaper protected rates.'.tr,
                                style: theme.textTheme.bodyMedium?.copyWith(color: HeroStyle.of(context).muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final (i, w) in _addOptions(context).indexed) FadeSlideIn(index: i + 1, child: w),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (var i = 0; i < cards.length; i++)
                  FadeSlideIn(
                    index: i,
                    child: Padding(padding: const EdgeInsets.only(bottom: 12), child: cards[i]),
                  ),
                for (final entry in years.entries) ...[
                  SectionHeader(
                    '${entry.key} · ${entry.value.length} ${entry.value.length == 1 ? 'bill' : 'bills'}'
                    '${_paid(entry.value)}',
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                  ),
                  for (final b in entry.value) ...[
                    BillTile(
                      bill: b,
                      threshold: threshold,
                      previousUnits: _previous(bills, b)?.units,
                      onTap: () => _push(context, BillFormScreen(existing: b)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
    );
  }

  static String _paid(List<Bill> list) {
    final total = list.fold<double>(0, (s, b) => s + b.amount);
    return total > 0 ? ' · ${Fmt.rs(total)} paid' : '';
  }

  /// The bill just before [b] (bills are newest first).
  static Bill? _previous(List<Bill> bills, Bill b) {
    final i = bills.indexOf(b);
    return i >= 0 && i + 1 < bills.length ? bills[i + 1] : null;
  }
}

/// Last 12 bills at a glance.
class _YearHero extends StatelessWidget {
  const _YearHero({required this.bills});

  final List<Bill> bills;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = HeroStyle.of(context);
    final units = bills.fold<int>(0, (s, b) => s + b.units);
    final paid = bills.fold<double>(0, (s, b) => s + b.amount);
    final avg = bills.isEmpty ? 0 : units / bills.length;
    final highest = bills.isEmpty ? null : bills.reduce((a, b) => b.units > a.units ? b : a);
    final lowest = bills.isEmpty ? null : bills.reduce((a, b) => b.units < a.units ? b : a);

    Widget stat(String label, String value, String caption) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: h.muted, fontSize: 10.5)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: theme.textTheme.titleMedium?.copyWith(color: h.fg)),
              ),
              Text(caption, style: theme.textTheme.bodySmall?.copyWith(color: h.muted, fontSize: 11.5)),
            ],
          ),
        );

    return AppCard(
      gradient: h.gradient,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('LAST ${bills.length} ${bills.length == 1 ? 'BILL'.tr : 'BILLS'}',
              style: theme.textTheme.labelSmall?.copyWith(color: h.muted)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.whole(units), style: theme.textTheme.displaySmall?.copyWith(color: h.fg, height: 1)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('units'.tr, style: theme.textTheme.titleMedium?.copyWith(color: h.muted)),
              ),
              const Spacer(),
              if (paid > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Fmt.rs(paid), style: theme.textTheme.titleLarge?.copyWith(color: h.fg)),
                    Text('paid'.tr, style: theme.textTheme.bodySmall?.copyWith(color: h.muted)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(color: h.faint, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                stat('AVERAGE', Fmt.whole(avg), 'units / bill'),
                if (highest != null) stat('HIGHEST', Fmt.whole(highest.units), Fmt.month(highest.monthDate)),
                if (lowest != null && bills.length > 1)
                  stat('LOWEST', Fmt.whole(math.min(lowest.units, highest?.units ?? lowest.units)),
                      Fmt.month(lowest.monthDate)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
