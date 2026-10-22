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

class _Tool {
  const _Tool(this.art, this.label, this.onTap, {this.badge});

  final String art;
  final String label;
  final VoidCallback onTap;

  /// Small status under the label, e.g. "Solar" or "On".
  final String? badge;
}

/// Every feature in one grid, settings below. Replaces the old "More" tab.
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
      title: 'Reset Bijli Hisaab?',
      message: 'This deletes all meters, readings, bills and appliances on this phone.\n\n'
          'Tip: save a backup first (Tools → Backup). Weekly copies on this phone '
          'can also bring your data back from the welcome screen.',
      confirmLabel: 'Reset',
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
      _Tool(Art.camera, 'Scan bill', () => _push(context, const ScanBillScreen())),
      _Tool(Art.stopwatch, 'Add reading', () => _push(context, const AddReadingScreen())),
      _Tool(Art.moneyBag, 'Bill calculator', () => _push(context, const BillCalculatorScreen())),
      _Tool(
        Art.sun,
        'Solar & TOU',
        () => _push(context, const MeterTypeScreen()),
        badge: switch (type) {
          MeterType.standard => 'Not set',
          MeterType.tou => 'TOU',
          _ => 'Solar',
        },
      ),
      _Tool(Art.plug, 'Appliances', () => onOpenTab(2)),
      _Tool(Art.barChart, 'Bill history', () => onOpenTab(1)),
      _Tool(Art.clipboard, 'Readings', () => _push(context, const ReadingsScreen()),
          badge: '${state.readings.length}'),
      _Tool(Art.bell, 'Reminders', () => _push(context, const RemindersScreen()),
          badge: state.remindersEnabled ? 'On' : 'Off'),
      _Tool(Art.chartUp, 'Rates', () => _push(context, const TariffScreen())),
      _Tool(Art.lock, 'Backup', () => _push(context, const BackupScreen())),
      _Tool(Art.bulb, 'Saving tips', () => _push(context, const TipsScreen())),
      _Tool(Art.party, 'Share month', () {
        if (hasData) {
          ShareSummarySheet.show(context);
        } else {
          showSnack(context, 'Add two readings this month first');
        }
      }),
      _Tool(Art.house, 'Meters', () => _push(context, const MetersScreen()),
          badge: '${state.meters.length}'),
      _Tool(Art.clipboard, 'Export data', () => _push(context, const ExportScreen())),
      _Tool(Art.phone, 'Home widget', () async {
        final ok = await HomeWidgetSync.requestPin();
        if (!context.mounted) return;
        if (!ok) {
          showSnack(context, 'Long-press your home screen → Widgets → Bijli Hisaab');
        }
      }),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 20,
        titleTextStyle: theme.textTheme.headlineSmall,
        title: const Text('Tools'),
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
                        Text('Bijli Hisaab', style: theme.textTheme.titleLarge?.copyWith(color: h.fg)),
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
          const SectionHeader('Everything in the app', padding: EdgeInsets.fromLTRB(4, 18, 4, 10)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 112,
            ),
            itemCount: tools.length,
            itemBuilder: (context, i) => FadeSlideIn(index: i + 1, child: _ToolTile(tool: tools[i])),
          ),
          const SectionHeader('Your electricity company'),
          CompanyCard(company: state.company, referenceNo: state.activeMeter?.referenceNo ?? ''),
          const SectionHeader('Appearance'),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                  label: Text('Phone'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                  label: Text('Dark'),
                ),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (s) => state.setThemeMode(s.first),
            ),
          ),
          const SectionHeader('Settings'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.update_rounded),
                  title: const Text('Electricity rates'),
                  subtitle: Text(
                    '${state.tariffOrigin.label} · updated ${Fmt.isoLabel(state.tariff.updatedAt)}'
                    '${state.autoUpdateRates && RemoteConfig.isConfigured ? ' · auto' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const TariffScreen()),
                ),
                const Divider(indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.insights_rounded),
                  title: const Text('Allow anonymous data export'),
                  subtitle: const Text('Needed for "Export data" (Power BI)'),
                  value: state.analyticsConsent,
                  onChanged: state.setAnalyticsConsent,
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('About & privacy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const AboutScreen()),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: Icon(Icons.restart_alt_rounded, color: theme.colorScheme.error),
                  title: Text('Reset app', style: TextStyle(color: theme.colorScheme.error)),
                  subtitle: const Text('Delete all data on this phone'),
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
