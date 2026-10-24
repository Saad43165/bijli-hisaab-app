import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/meter.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/loading_button.dart';
import '../../state/app_state.dart';
import '../../core/l10n/l10n.dart';

/// "Solar & TOU": pick what kind of meter the active meter is.
class MeterTypeScreen extends StatefulWidget {
  const MeterTypeScreen({super.key});

  @override
  State<MeterTypeScreen> createState() => _MeterTypeScreenState();
}

class _MeterTypeScreenState extends State<MeterTypeScreen> {
  late MeterType _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = context.read<AppState>().activeMeter?.meterType ?? MeterType.standard;
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final meter = state.activeMeter;
    if (meter == null) return;
    setState(() => _saving = true);
    try {
      await state.updateMeter(meter.copyWith(meterType: _type));
      if (!mounted) return;
      showSnack(context, switch (_type) {
        MeterType.standard => 'Set to a normal meter'.tr,
        MeterType.tou => 'TOU set — add peak and off-peak readings from now on'.tr,
        _ => 'Solar set — add import and export readings from now on'.tr,
      });
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: {0}'.trf({'0': e}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meter = context.watch<AppState>().activeMeter;
    final solar = _type.isSolar;

    return Scaffold(
      appBar: AppBar(title: Text('Solar & TOU'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              'What kind of meter does "{0}" have?'.trf({'0': meter?.name ?? 'your home'}),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'This changes how readings are entered and how the bill is worked out.'.tr,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _Option(
              art: Art.bolt,
              title: 'Normal meter'.tr,
              body: 'One number on the display. Billed by slabs (most homes).'.tr,
              selected: _type == MeterType.standard,
              onTap: () => setState(() => _type = MeterType.standard),
            ),
            _Option(
              art: Art.sun,
              title: 'Solar panels (net meter)'.tr,
              body: 'The meter counts units taken from the grid (import) and sent to it (export). We take the export credit off your bill.'.tr,
              selected: solar,
              onTap: () => setState(() => _type = solar ? _type : MeterType.netBilling),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child: !solar
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('When was your solar agreement signed?'.tr, style: theme.textTheme.labelSmall),
                          const SizedBox(height: 8),
                          SegmentedButton<MeterType>(
                            segments: [
                              ButtonSegment(value: MeterType.netMetering, label: Text('Before Feb 2026'.tr)),
                              ButtonSegment(value: MeterType.netBilling, label: Text('Feb 2026 or later'.tr)),
                            ],
                            selected: {_type},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) => setState(() => _type = s.first),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _type == MeterType.netMetering
                                ? 'Net metering: exported units cancel out imported units — you pay for the difference.'.tr
                                : 'Net billing: imported units at normal rates; exported units bought back at a lower rate.'.tr,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
            ),
            _Option(
              art: Art.hourglass,
              title: 'Peak / off-peak (TOU)'.tr,
              body: 'Your bill shows peak and off-peak units — usually homes with 5 kW or more.'.tr,
              selected: _type == MeterType.tou,
              onTap: () => setState(() => _type = MeterType.tou),
            ),
            const SizedBox(height: 8),
            Text(
              'Not sure? Look at your bill: "Export units" means solar; "Peak" and "Off-peak" means TOU.'.tr,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            LoadingButton(
              label: 'Save'.tr,
              loading: _saving,
              onPressed: _save,
              icon: Icons.check_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.art,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final String art;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        elevated: !selected,
        color: selected ? AppColors.amber.withValues(alpha: 0.10) : null,
        borderColor: selected ? AppColors.amber : null,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ArtTile(art, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.amberDeep : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
