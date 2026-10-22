import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../core/config/remote_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/tariff.dart';
import '../../data/repositories/tariff_repository.dart';
import '../../services/tariff_update_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/info_banner.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/app_state.dart';
import '../../shared/widgets/art.dart';
import 'tariff_edit_screen.dart';
import '../../core/l10n/l10n.dart';

/// Shows the rates in use, where they came from, and the auto-update switch.
class TariffScreen extends StatelessWidget {
  const TariffScreen({super.key});

  Future<void> _checkNow(BuildContext context) async {
    final state = context.read<AppState>();
    final r = await state.checkForRateUpdates(force: true);
    if (!context.mounted) return;
    showSnack(context, switch (r.status) {
      TariffCheckStatus.updated => 'New rates downloaded'.tr,
      TariffCheckStatus.upToDate => 'You have the latest rates'.tr,
      TariffCheckStatus.notConfigured => 'Online rates are not set up in this build'.tr,
      TariffCheckStatus.failed => r.message ?? 'Could not check for new rates',
      TariffCheckStatus.skipped => 'Already checking…'.tr,
    });
  }

  Future<void> _edit(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.autoUpdateRates && RemoteConfig.isConfigured) {
      final ok = await confirmDialog(
        context,
        title: 'Edit rates yourself?'.tr,
        message: 'Automatic updates will be turned off while you use your own rates. You can switch back any time.'.tr,
        confirmLabel: 'Edit'.tr,
        destructive: false,
      );
      if (!ok || !context.mounted) return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TariffEditScreen()),
    );
  }

  Future<void> _useOfficial(BuildContext context) async {
    final state = context.read<AppState>();
    await state.resetTariff();
    await state.setAutoUpdateRates(true);
    if (context.mounted) showSnack(context, 'Using official rates again'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final t = state.effectiveTariff;
    final p = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Electricity rates'.tr),
        actions: [
          IconButton(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit rates'.tr,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (state.tariffOrigin == TariffOrigin.custom) ...[
            InfoBanner(
              icon: Icons.edit_note_rounded,
              title: 'Using your own rates'.tr,
              message: 'Automatic updates are off, so estimates won\'t follow new NEPRA rates.'.tr,
              actionLabel: 'Use official rates'.tr,
              onAction: () => _useOfficial(context),
            ),
            const SizedBox(height: 12),
          ],
          _StatusCard(onCheck: () => _checkNow(context)),
          SectionHeader('This month'.tr),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _Row(label: 'Fuel charges adjustment'.tr, note: t.fcaLabel, value: _signed(t.fcaPerUnit)),
                _Row(label: 'Quarterly adjustment'.tr, note: t.qtaLabel, value: _signed(t.qtaPerUnit)),
                _Row(
                  label: 'FC / debt surcharge'.tr,
                  note: 'Normal consumers · protected exempt',
                  value: Fmt.rate(t.unprotectedCategory.fcSurchargePerUnit),
                ),
                _Row(label: 'GST'.tr, note: 'On energy, fixed, surcharge, FCA and QTA', value: '${Fmt.oneDp(t.gstPercent)}%'),
                _Row(
                  label: 'Electricity duty · TV fee'.tr,
                  note: 'Removed from bills since July 2025',
                  value: t.tvFee == 0 && t.dutyFor(state.activeMeter?.province ?? '') == 0 ? 'None'.tr : 'Applied'.tr,
                  last: true,
                ),
              ],
            ),
          ),
          if (t.lifelineCategory != null) ...[
            SectionHeader('Lifeline (≤1 kW, ≤100 units)'.tr),
            _SlabTable(category: t.lifelineCategory!, color: p.safe),
          ],
          SectionHeader('Protected (≤200 units for 6 months)'.tr),
          _SlabTable(category: t.protectedCategory, color: AppColors.amberDeep),
          SectionHeader('Normal (unprotected)'.tr),
          _SlabTable(category: t.unprotectedCategory, color: p.danger),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              t.unprotectedCategory.billingMode == BillingMode.whole
                  ? 'Normal consumers pay the rate of the slab they reach on every unit — 201 units costs far more than 200.'.tr
                  : t.unprotectedCategory.billingMode.label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SectionHeader('Time of use (5 kW and above)'.tr),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _Row(label: 'Peak hours'.tr, note: '4 evening hours, set by season', value: Fmt.rate(t.tou.peakRate)),
                _Row(label: 'Off-peak hours'.tr, note: 'All other hours', value: Fmt.rate(t.tou.offPeakRate)),
                _Row(
                  label: 'Fixed charge'.tr,
                  note: 'Per kW on {0}% of sanctioned load'.trf({'0': (t.tou.fixedLoadShare * 100).round()}),
                  value: Fmt.rs(t.tou.fixedPerKw),
                  last: true,
                ),
              ],
            ),
          ),
          SectionHeader('Solar'.tr),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _Row(
                  label: 'Net billing (from Feb 2026)'.tr,
                  note: 'Paid for every exported unit',
                  value: Fmt.rate(t.solar.netBillingRate),
                ),
                _Row(
                  label: 'Net metering (older agreements)'.tr,
                  note: 'Paid for surplus units after netting',
                  value: Fmt.rate(t.solar.netMeteringRate),
                  last: true,
                ),
              ],
            ),
          ),
          SectionHeader('Sources'.tr),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.sourceNote, style: theme.textTheme.bodySmall),
                for (final s in t.sources) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: s.url));
                      showSnack(context, 'Link copied'.tr);
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.description_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s.title, style: theme.textTheme.bodyMedium)),
                        Icon(Icons.copy_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _signed(double v) => '${v >= 0 ? '+' : '−'}${Fmt.rate(v.abs())}';
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.onCheck});

  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final t = state.effectiveTariff;
    final last = state.lastRatesCheck;
    final configured = RemoteConfig.isConfigured;

    final String lastLine;
    if (!configured) {
      lastLine = 'Using the rates built into the app.';
    } else if (last == null) {
      lastLine = 'Not checked yet';
    } else {
      lastLine = 'Checked ${DateFormat('d MMM, h:mm a').format(last)}'
          '${state.lastRatesStatus == null ? '' : ' · ${state.lastRatesStatus}'}';
    }

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ArtTile(Art.chartUp),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rates updated {0}'.trf({'0': Fmt.isoLabel(t.updatedAt)}), style: theme.textTheme.titleMedium),
                    Text(
                      '{0} · NEPRA tariff from {1}'.trf({'0': state.tariffOrigin.label, '1': Fmt.isoLabel(t.effectiveFrom)}),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            // Without a download address the switch can't do anything, so it
            // shows off and disabled instead of a misleading "on".
            value: configured && state.autoUpdateRates,
            onChanged: configured ? state.setAutoUpdateRates : null,
            title: Text('Update rates automatically'.tr, style: theme.textTheme.titleSmall),
            subtitle: Text(
              configured
                  ? 'Downloads new FCA, quarterly and slab rates when NEPRA changes them'.tr
                  : 'Not available in this version. Rates change with app updates, or tap the pencil to enter them yourself.'.tr,
            ),
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(child: Text(lastLine, style: theme.textTheme.bodySmall)),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.checkingRates || !configured ? null : onCheck,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                icon: state.checkingRates
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Check now'.tr),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.note, this.last = false});

  final String label;
  final String value;
  final String? note;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (note != null) Text(note!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _SlabTable extends StatelessWidget {
  const _SlabTable({required this.category, required this.color});

  final TariffCategory category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final head = theme.textTheme.labelSmall;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 4, child: Text('UNITS'.tr, style: head)),
              Expanded(flex: 3, child: Text('PER UNIT'.tr, style: head, textAlign: TextAlign.right)),
              Expanded(flex: 3, child: Text('FIXED / kW'.tr, style: head, textAlign: TextAlign.right)),
            ],
          ),
          const SizedBox(height: 6),
          for (final s in category.slabs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(s.label, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      Fmt.rate(s.rate),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      s.fixedPerKw == 0 ? '—' : Fmt.rs(s.fixedPerKw),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
