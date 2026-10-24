import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../state/app_state.dart';
import '../../shared/widgets/info_banner.dart';
import '../../shared/widgets/section_header.dart';
import '../bills/scan_bill_screen.dart';
import '../readings/add_reading_screen.dart';
import '../readings/readings_screen.dart';
import '../settings/reminders_screen.dart';
import 'widgets/bill_estimate_card.dart';
import '../../shared/widgets/art.dart';
import 'widgets/daily_usage_chart.dart';
import 'widgets/getting_started_card.dart';
import 'widgets/last_bill_card.dart';
import 'widgets/meter_switcher.dart';
import 'widgets/meter_type_cards.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/share_summary_sheet.dart';
import 'widgets/simple_home.dart';
import 'widgets/slab_alert_card.dart';
import 'widgets/slab_meter_card.dart';
import 'widgets/tip_card.dart';
import 'widgets/usage_ring_card.dart';
import '../bills/online_bill_screen.dart';
import 'calculators_screen.dart';
import 'widgets/advice_card.dart';
import 'widgets/bill_overview_card.dart';
import 'widgets/rate_news_card.dart';
import '../bills/widgets/protection_card.dart';
import '../assistant/assistant_button.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenTab});

  /// Switches the bottom-navigation tab (2 = Appliances).
  final ValueChanged<int> onOpenTab;

  static void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  static String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning'.tr;
    if (h < 17) return 'Good afternoon'.tr;
    return 'Good evening'.tr;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final meter = state.activeMeter;
    final summary = state.summary;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final hasData = summary?.hasData ?? false;


    void openBill() => OnlineBillScreen.open(context, state.company, meter?.referenceNo ?? '');
    final overview = BillOverviewCard(
      onOpenHistory: () => onOpenTab(1),
      onViewBill: state.company.billUrl == null ? null : openBill,
    );

    // Each entry is one block on the screen, spaced 14 apart.
    Widget spaced(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w);
    final billBanner = state.billNotice == null
        ? null
        : InfoBanner(
            icon: Icons.receipt_long_rounded,
            leadingArt: Art.receipt,
            title: 'Your new bill is out'.tr,
            message: state.billNotice!,
            onClose: state.dismissBillNotice,
          );
    final cards = <Widget>[
      if (billBanner != null) spaced(billBanner),
      if (state.ratesNotice != null)
        spaced(InfoBanner(
          icon: Icons.auto_awesome_rounded,
          leadingArt: Art.sparkles,
          title: 'New electricity rates'.tr,
          message: state.ratesNotice!,
          onClose: state.dismissRatesNotice,
        )),
      if (!state.company.usesNepraTariff)
        spaced(InfoBanner(
          icon: Icons.info_outline_rounded,
          title: '{0} has its own tariff'.trf({'0': state.company.shortCode}),
          message: 'Units and slab warnings are accurate. For the bill amount, enter your area\'s rates in Tools → Rates → edit.'.tr,
        )),
      if (state.bills.isNotEmpty) spaced(overview),
      if (state.bills.isNotEmpty) spaced(const AdviceCard()),
      if (summary != null && hasData) ...[
        spaced(UsageRingCard(summary: summary)),
        spaced(summary.isTou
            ? TouSplitCard(summary: summary, rates: state.effectiveTariff.tou)
            : SlabAlertCard(summary: summary)),
        spaced(BillEstimateCard(summary: summary, ratesDate: state.tariff.updatedAt)),
        if (summary.isSolar) spaced(SolarCard(summary: summary, rates: state.effectiveTariff.solar)),
        if (!summary.isTou) spaced(SlabMeterCard(summary: summary, calculator: state.calculator)),
        if (summary.points.length >= 2) spaced(DailyUsageChart(points: summary.points)),
      ] else if (summary != null) ...[
        spaced(GettingStartedCard(
          summary: summary,
          latest: state.latestReading,
          onAddReading: () => _push(context, const AddReadingScreen()),
          onScanBill: () => _push(context, const ScanBillScreen()),
        )),
        if (state.bills.isNotEmpty)
          spaced(ProtectionCard(
            bills: state.bills,
            months: state.tariff.protectedMonths,
            limit: state.tariff.protectedThresholdUnits,
          )),
      ],
      if (RateNewsCard.hasContent(state.effectiveTariff))
        spaced(RateNewsCard(tariff: state.effectiveTariff, summary: summary)),
      if (state.bills.isEmpty)
        spaced(LastBillCard(
          bill: state.bills.firstOrNull,
          onOpen: () => onOpenTab(1),
          onScan: () => _push(context, const ScanBillScreen()),
        )),

      SectionHeader('Shortcuts'.tr, padding: const EdgeInsets.fromLTRB(4, 8, 4, 10)),
      QuickActionsRow(
        actions: [
          QuickAction(art: Art.camera, label: 'Scan bill'.tr, onTap: () => _push(context, const ScanBillScreen())),
          if (state.company.billUrl != null)
            QuickAction(art: Art.receipt, label: 'Bill online'.tr, onTap: openBill)
          else if (hasData)
            QuickAction(art: Art.clipboard, label: 'Readings'.tr, onTap: () => _push(context, const ReadingsScreen()))
          else
            QuickAction(art: Art.bell, label: 'Reminders'.tr, onTap: () => _push(context, const RemindersScreen())),
          QuickAction(art: Art.moneyBag, label: 'Calculators'.tr, onTap: () => _push(context, const CalculatorsScreen())),
          QuickAction(art: Art.plug, label: 'Appliances'.tr, onTap: () => onOpenTab(2)),
        ],
      ),
      SectionHeader('Tip of the day'.tr, padding: const EdgeInsets.fromLTRB(4, 22, 4, 10)),
      const TipCard(),
    ];

    // Simple Home: just this month's units, the bill and adding a reading.
    final simple = state.simpleHome;
    final simpleCards = <Widget>[
      if (billBanner != null) spaced(billBanner),
      if (state.bills.isNotEmpty) spaced(overview),
      if (state.bills.isNotEmpty) spaced(const AdviceCard()),
      if (summary != null && hasData)
        spaced(SimpleHome(summary: summary, onAddReading: () => _push(context, const AddReadingScreen())))
      else if (summary != null)
        spaced(GettingStartedCard(
          summary: summary,
          latest: state.latestReading,
          onAddReading: () => _push(context, const AddReadingScreen()),
          onScanBill: () => _push(context, const ScanBillScreen()),
        )),
      if (state.bills.isEmpty)
        spaced(LastBillCard(
          bill: state.bills.firstOrNull,
          onOpen: () => onOpenTab(1),
          onScan: () => _push(context, const ScanBillScreen()),
        )),
      if (state.company.billUrl != null && state.bills.isEmpty)
        spaced(OutlinedButton.icon(
          onPressed: openBill,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.receipt_long_rounded),
          label: Text('Check your {0} bill online'.trf({'0': state.company.shortCode})),
        )),
      Center(
        child: TextButton.icon(
          onPressed: () => state.setSimpleHome(false),
          icon: const Icon(Icons.expand_more_rounded),
          label: Text('Show details'.tr),
        ),
      ),
    ];
    final shown = simple ? simpleCards : cards;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 16,
        title: const MeterSwitcher(),
        actions: [
          IconButton(
            tooltip: state.simpleHome ? 'Detailed view'.tr : 'Simple view'.tr,
            onPressed: () => state.setSimpleHome(!state.simpleHome),
            icon: Icon(state.simpleHome ? Icons.dashboard_outlined : Icons.view_agenda_outlined),
          ),
          if (hasData)
            IconButton(
              tooltip: 'Share this month'.tr,
              onPressed: () => ShareSummarySheet.show(context),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          const AssistantButton(),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: hasData
          ? FloatingActionButton.extended(
              onPressed: () => _push(context, const AddReadingScreen()),
              icon: const Icon(Icons.add_rounded),
              label: Text('Add reading'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      body: meter == null || summary == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.navy,
              backgroundColor: AppColors.amber,
              onRefresh: () async {
                await state.refresh();
                await state.checkForRateUpdates(force: true);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 14),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${_greeting(now)}  ',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text: DateFormat('EEE, d MMM', L10n.language).format(now),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Cards slide in one after another.
                  for (var i = 0; i < shown.length; i++) FadeSlideIn(index: i, child: shown[i]),
                ],
              ),
            ),
    );
  }
}
