import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/remote_config.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/meter.dart';
import '../../services/home_widget_sync.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/hero_style.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/app_state.dart';
import '../bills/scan_bill_screen.dart';
import '../home/bill_calculator_screen.dart';
import '../home/widgets/share_summary_sheet.dart';
import '../meters/meter_type_screen.dart';
import '../meters/meters_screen.dart';
import '../readings/add_reading_screen.dart';
import '../readings/readings_screen.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'export_screen.dart';
import 'reminders_screen.dart';
import 'tariff_screen.dart';
import 'tips_screen.dart';
import 'widgets/company_card.dart';
import '../../core/l10n/l10n.dart';

class _Tool {
  const _Tool(this.art, this.label, this.onTap, {this.badge});

  final String art;
  final String label;
  final VoidCallback onTap;

  /// Small status under the label, e.g. "Solar" or "On".
  final String? badge;
}

/// Every feature in one grid, settings below. Replaces the old "More" tab.
/// Settings flag: show tools as the big grid instead of slim rows.
const _gridKey = 'tools_grid';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key, required this.onOpenTab});

  /// Switches the bottom-navigation tab (1 = History, 2 = Appliances).
  final ValueChanged<int> onOpenTab;

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _reset(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await confirmDialog(
      context,
      title: 'Reset Bijli Hisaab?'.tr,
      message: 'This deletes all meters, readings, bills and appliances on this phone.\n\nTip: save a backup first (Tools → Backup). Weekly copies on this phone can also bring your data back from the welcome screen.'.tr,
      confirmLabel: 'Reset'.tr,
    );
    if (ok) await state.resetApp();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final h = HeroStyle.of(context);
    final type = state.activeMeter?.meterType ?? MeterType.standard;
    final hasData = state.summary?.hasData ?? false;

    final tools = <_Tool>[
      _Tool(Art.camera, 'Scan bill'.tr, () => _push(context, const ScanBillScreen())),
      _Tool(Art.stopwatch, 'Add reading'.tr, () => _push(context, const AddReadingScreen())),
      _Tool(Art.moneyBag, 'Bill calculator'.tr, () => _push(context, const BillCalculatorScreen())),
      _Tool(
        Art.sun,
        'Solar & TOU'.tr,
        () => _push(context, const MeterTypeScreen()),
        badge: switch (type) {
          MeterType.standard => 'Not set'.tr,
          MeterType.tou => 'TOU'.tr,
          _ => 'Solar'.tr,
        },
      ),
      _Tool(Art.plug, 'Appliances'.tr, () => onOpenTab(2)),
      _Tool(Art.barChart, 'Bill history'.tr, () => onOpenTab(1)),
      _Tool(Art.clipboard, 'Readings'.tr, () => _push(context, const ReadingsScreen()),
          badge: '${state.readings.length}'),
      _Tool(Art.bell, 'Reminders'.tr, () => _push(context, const RemindersScreen()),
          badge: state.remindersEnabled ? 'On' : 'Off'.tr),
      _Tool(Art.chartUp, 'Rates'.tr, () => _push(context, const TariffScreen())),
      _Tool(Art.lock, 'Backup'.tr, () => _push(context, const BackupScreen())),
      _Tool(Art.bulb, 'Saving tips'.tr, () => _push(context, const TipsScreen())),
      _Tool(Art.party, 'Share month'.tr, () {
        if (hasData) {
          ShareSummarySheet.show(context);
        } else {
          showSnack(context, 'Add two readings this month first'.tr);
        }
      }),
      _Tool(Art.house, 'Meters'.tr, () => _push(context, const MetersScreen()),
          badge: '${state.meters.length}'),
      _Tool(Art.clipboard, 'Export data'.tr, () => _push(context, const ExportScreen())),
      _Tool(Art.phone, 'Home widget'.tr, () async {
        final ok = await HomeWidgetSync.requestPin();
        if (!context.mounted) return;
        if (!ok) {
          showSnack(context, 'Long-press your home screen → Widgets → Bijli Hisaab'.tr);
        }
      }),
    ];

    final grid = state.uiFlag(_gridKey);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 20,
        titleTextStyle: theme.textTheme.headlineSmall,
        title: Text('Tools'.tr),
        actions: [
          IconButton(
            tooltip: grid ? 'Show as rows'.tr : 'Show as grid'.tr,
            onPressed: () => state.setUiFlag(_gridKey, !grid),
            icon: Icon(grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          FadeSlideIn(
            child: AppCard(
              gradient: h.gradient,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const ArtTile(Art.brandBolt, onNavy: true, size: 54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bijli Hisaab'.tr, style: theme.textTheme.titleLarge?.copyWith(color: h.fg)),
                        Text(
                          '${state.activeMeter?.name ?? ''} · ${state.company.shortCode} · ${type.label}',
                          style: theme.textTheme.bodySmall?.copyWith(color: h.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: h.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      state.protection?.consumerClass.label ?? '',
                      style: theme.textTheme.labelSmall?.copyWith(color: h.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionHeader('Everything in the app'.tr, padding: EdgeInsets.fromLTRB(4, 18, 4, 10)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            // Grid: big tiles. Rows (default): slim two-column tiles that take
            // about half the space.
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: grid ? 3 : 2,
              mainAxisSpacing: grid ? 10 : 8,
              crossAxisSpacing: grid ? 10 : 8,
              mainAxisExtent: grid ? 116 : 54,
            ),
            itemCount: tools.length,
            itemBuilder: (context, i) => FadeSlideIn(
              index: i + 1,
              child: grid ? _ToolTile(tool: tools[i]) : _ToolRow(tool: tools[i]),
            ),
          ),
          SectionHeader('Your electricity company'.tr),
          CompanyCard(company: state.company, referenceNo: state.activeMeter?.referenceNo ?? ''),
          SectionHeader('Appearance'.tr),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Language'.tr, style: theme.textTheme.labelSmall),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'ur', label: Text('اردو')),
                  ],
                  selected: {state.language},
                  onSelectionChanged: (s) => state.setLanguage(s.first),
                ),
                const SizedBox(height: 16),
                Text('Home screen'.tr, style: theme.textTheme.labelSmall),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: true, label: Text('Simple'.tr)),
                    ButtonSegment(value: false, label: Text('Detailed'.tr)),
                  ],
                  selected: {state.simpleHome},
                  onSelectionChanged: (s) => state.setSimpleHome(s.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                  label: Text('Phone'.tr),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                  label: Text('Light'.tr),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                  label: Text('Dark'.tr),
                ),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (s) => state.setThemeMode(s.first),
            ),
          ),
          SectionHeader('Settings'.tr),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.update_rounded),
                  title: Text('Electricity rates'.tr),
                  subtitle: Text(
                    '${state.tariffOrigin.label} · updated ${Fmt.isoLabel(state.tariff.updatedAt)}'
                    '${state.autoUpdateRates && RemoteConfig.isConfigured ? ' · auto'.tr : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const TariffScreen()),
                ),
                const Divider(indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.insights_rounded),
                  title: Text('Allow anonymous data export'.tr),
                  subtitle: Text('Needed for "Export data" (Power BI)'.tr),
                  value: state.analyticsConsent,
                  onChanged: state.setAnalyticsConsent,
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text('About & privacy'.tr),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const AboutScreen()),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: Icon(Icons.restart_alt_rounded, color: theme.colorScheme.error),
                  title: Text('Reset app'.tr, style: TextStyle(color: theme.colorScheme.error)),
                  subtitle: Text('Delete all data on this phone'.tr),
                  onTap: () => _reset(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim tool tile for the rows layout: small icon, name, status.
class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: tool.onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
      child: Row(
        children: [
          ArtTile(tool.art, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (tool.badge != null)
                  Text(tool.badge!, maxLines: 1, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: tool.onTap,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      child: Column(
        children: [
          ArtTile(tool.art, size: 44),
          const SizedBox(height: 8),
          Text(
            tool.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (tool.badge != null)
            Text(
              tool.badge!,
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}
