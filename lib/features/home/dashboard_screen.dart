import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../state/app_state.dart';
import '../meters/meter_type_screen.dart';
import '../../shared/widgets/info_banner.dart';
import '../../shared/widgets/section_header.dart';
import '../bills/scan_bill_screen.dart';
import '../readings/add_reading_screen.dart';
import '../readings/readings_screen.dart';
import '../settings/reminders_screen.dart';
import '../settings/tariff_screen.dart';
import 'widgets/bill_calculator_card.dart';
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
import 'widgets/start_here_card.dart';
import 'widgets/slab_meter_card.dart';
import 'widgets/tip_card.dart';
import 'widgets/usage_ring_card.dart';

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

    final showStartHere = meter != null && StartHereCard.visible(state);

    // Each entry is one block on the screen, spaced 14 apart.
    Widget spaced(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w);
    final cards = <Widget>[
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
          title: '${state.company.shortCode} has its own tariff',
          message: 'Units and slab warnings are accurate. For the bill amount, enter your area\'s rates in Tools → Rates → edit.'.tr,
        )),
      if (showStartHere && hasData)
        spaced(StartHereCard(
          onReading: () => _push(context, const AddReadingScreen()),
          onBill: () => _push(context, const ScanBillScreen()),
          onAppliances: () => onOpenTab(2),
          onMeterType: () => _push(context, const MeterTypeScreen()),
        )),
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
        if (showStartHere)
          spaced(StartHereCard(
            onReading: () => _push(context, const AddReadingScreen()),
            onBill: () => _push(context, const ScanBillScreen()),
            onAppliances: () => onOpenTab(2),
            onMeterType: () => _push(context, const MeterTypeScreen()),
          )),
        spaced(const BillCalculatorCard()),
      ],
      if (hasData || state.bills.isNotEmpty)
        spaced(LastBillCard(
          bill: state.bills.firstOrNull,
          onOpen: () => onOpenTab(1),
          onScan: () => _push(context, const ScanBillScreen()),
        )),

      SectionHeader('Shortcuts'.tr, padding: EdgeInsets.fromLTRB(4, 8, 4, 10)),
      QuickActionsRow(
        actions: [
          QuickAction(art: Art.camera, label: 'Scan bill'.tr, onTap: () => _push(context, const ScanBillScreen())),
          if (hasData)
            QuickAction(art: Art.clipboard, label: 'Readings'.tr, onTap: () => _push(context, const ReadingsScreen()))
          else
            QuickAction(art: Art.bell, label: 'Reminders'.tr, onTap: () => _push(context, const RemindersScreen())),
          QuickAction(art: Art.plug, label: 'Appliances'.tr, onTap: () => onOpenTab(2)),
          QuickAction(art: Art.chartUp, label: 'Rates'.tr, onTap: () => _push(context, const TariffScreen())),
        ],
      ),
      SectionHeader('Tip of the day'.tr, padding: EdgeInsets.fromLTRB(4, 22, 4, 10)),
      const TipCard(),
    ];

    // Simple Home: just this month's units, the bill and adding a reading.
    final simple = state.simpleHome;
    final simpleCards = <Widget>[
      if (summary != null && hasData)
        spaced(SimpleHome(summary: summary, onAddReading: () => _push(context, const AddReadingScreen())))
      else if (summary != null)
        spaced(GettingStartedCard(
          summary: summary,
          latest: state.latestReading,
          onAddReading: () => _push(context, const AddReadingScreen()),
          onScanBill: () => _push(context, const ScanBillScreen()),
        )),
      if (showStartHere)
        spaced(StartHereCard(
          onReading: () => _push(context, const AddReadingScreen()),
          onBill: () => _push(context, const ScanBillScreen()),
          onAppliances: () => onOpenTab(2),
          onMeterType: () => _push(context, const MeterTypeScreen()),
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
          IconButton(
            tooltip: 'Reminders'.tr,
            onPressed: () => _push(context, const RemindersScreen()),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Until tracking starts, the hero card carries the "Add reading" button.
      floatingActionButton: hasData
          ? FloatingActionButton.extended(
              onPressed: () => _push(context, const AddReadingScreen()),
              icon: const Icon(Icons.add_rounded),
              label: Text('Add reading'.tr, style: TextStyle(fontWeight: FontWeight.w800)),
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
                padding: EdgeInsets.fromLTRB(16, 0, 16, hasData ? 104 : 28),
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
                            text: DateFormat('EEE, d MMM').format(now),
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
