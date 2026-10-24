import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/appliance.dart';
import '../../services/appliance_planner.dart';
import '../../shared/widgets/animated_number.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/hero_style.dart';
import '../../shared/widgets/loading_button.dart';
import '../../state/app_state.dart';
import '../assistant/assistant_button.dart';
import '../assistant/assistant_screen.dart';
import 'widgets/appliance_sheet.dart';
import 'widgets/quick_setup.dart';

/// What uses your electricity and how to pay less. One tap fills in a
/// typical home from your bill; everything is adjusted with + / −.
class AppliancesScreen extends StatefulWidget {
  const AppliancesScreen({super.key});

  /// Monthly units the appliance list should roughly add up to.
  static int targetUnits(AppState s) {
    final bills = s.bills.take(12).toList();
    if (bills.isNotEmpty) return (bills.fold<int>(0, (a, b) => a + b.units) / bills.length).round();
    final t = s.typicalMonthlyUnits;
    return t > 0 ? t : 200;
  }

  /// [items] biggest cost first, or by name.
  static List<Appliance> sorted(List<Appliance> items, {required bool byName}) => [...items]
    ..sort((a, b) => byName
        ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
        : b.monthlyUnits.compareTo(a.monthlyUnits));

  @override
  State<AppliancesScreen> createState() => _AppliancesScreenState();
}

class _AppliancesScreenState extends State<AppliancesScreen> {
  bool _byName = false;

  /// Swipe or − to zero: remove, with Undo in the snack bar.
  Future<void> _remove(Appliance a) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.mediumImpact();
    await state.deleteAppliance(a);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('{0} removed'.trf({'0': a.name.tr})),
        action: SnackBarAction(
          label: 'Undo'.tr,
          onPressed: () => state.saveAppliance(Appliance(
            meterId: a.meterId,
            name: a.name,
            category: a.category,
            watts: a.watts,
            quantity: a.quantity,
            hoursPerDay: a.hoursPerDay,
            createdAt: a.createdAt,
          )),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final items = AppliancesScreen.sorted(state.appliances, byName: _byName);
    final total = state.applianceMonthlyUnits;
    final rate = state.marginalRate;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 20,
        titleTextStyle: theme.textTheme.headlineSmall,
        title: Text('Appliances'.tr),
        actions: const [AssistantButton(), SizedBox(width: 12)],
      ),
      body: items.isEmpty
          ? const _EmptyStart()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _SummaryCard(total: total, rate: rate),
                const SizedBox(height: 12),
                _SavingsCard(items: items, rate: rate),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text('YOUR APPLIANCES · {0}'.trf({'0': items.length}),
                          style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    PopupMenuButton<bool>(
                      tooltip: 'Sort'.tr,
                      initialValue: _byName,
                      onSelected: (v) => setState(() => _byName = v),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: false, child: Text('Biggest cost first'.tr)),
                        PopupMenuItem(value: true, child: Text('By name'.tr)),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort_rounded, size: 18),
                            const SizedBox(width: 4),
                            Text(_byName ? 'By name'.tr : 'By cost'.tr, style: theme.textTheme.labelLarge),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => QuickSetup.show(context),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text('Add'.tr),
                    ),
                  ],
                ),
                for (final a in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ValueKey('appliance-${a.id}'),
                      direction: DismissDirection.endToStart,
                      background: const _SwipeDelete(),
                      onDismissed: (_) => _remove(a),
                      child: _ApplianceRow(appliance: a, total: total, rate: rate, onRemove: () => _remove(a)),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Swipe left to remove. Costs use {0} per unit, before taxes.'.trf({'0': Fmt.rate(rate)}),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

class _SwipeDelete extends StatelessWidget {
  const _SwipeDelete();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.only(end: 20),
      decoration: BoxDecoration(color: p.danger.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(20)),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
    );
  }
}

// ---------------------------------------------------------------- empty

class _EmptyStart extends StatefulWidget {
  const _EmptyStart();

  @override
  State<_EmptyStart> createState() => _EmptyStartState();
}

class _EmptyStartState extends State<_EmptyStart> {
  bool _busy = false;

  Future<void> _autofill() async {
    final state = context.read<AppState>();
    final meterId = state.activeMeter?.id;
    if (meterId == null) return;
    setState(() => _busy = true);
    final now = DateTime.now();
    final list = [
      for (final i in AppliancePlanner.typicalHome(AppliancesScreen.targetUnits(state)))
        if (ApplianceCatalog.preset(i.name) case final p?)
          Appliance(
            meterId: meterId,
            name: p.name,
            category: p.category,
            watts: p.watts,
            quantity: i.quantity,
            hoursPerDay: i.hours,
            createdAt: now,
          ),
    ];
    try {
      await state.addAppliances(list);
      if (mounted) showSnack(context, 'Done! Now tap − / + on anything that doesn\'t match your home.'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = HeroStyle.of(context);
    final target = AppliancesScreen.targetUnits(context.watch<AppState>());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AppCard(
          gradient: h.gradient,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ArtTile(Art.plug, size: 52),
              const SizedBox(height: 12),
              Text('See what uses your electricity'.tr,
                  style: theme.textTheme.headlineSmall?.copyWith(color: h.fg)),
              const SizedBox(height: 6),
              Text(
                'We\'ll fill in a typical home that matches your bill (about {0} units a month). Then just tap − / + on anything that\'s different — and see where you can save.'
                    .trf({'0': target}),
                style: theme.textTheme.bodyMedium?.copyWith(color: h.muted),
              ),
              const SizedBox(height: 16),
              LoadingButton(
                loading: _busy,
                onPressed: _autofill,
                label: 'Fill in a typical home for me'.tr,
                icon: Icons.auto_fix_high_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.checklist_rounded),
                title: Text('Pick my appliances'.tr),
                subtitle: Text('Tap how many fans, lights, ACs… you have'.tr),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => QuickSetup.show(context),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: Text('Tell the assistant'.tr),
                subtitle: Text('"I have 2 ACs, 5 fans and a motor"'.tr),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AssistantScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- summary

/// Total units and cost a month, their share of the bill, and how well
/// they match it.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.rate});

  final double total;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final h = HeroStyle.of(context);
    final target = AppliancesScreen.targetUnits(state);
    final share = target <= 0 ? null : total / target;
    final cost = total * rate;

    final String note;
    if (share == null) {
      note = '';
    } else if (share < 0.75) {
      note = 'About {0} units a month aren\'t explained yet — something is missing or running longer.'
          .trf({'0': Fmt.whole(target - total)});
    } else if (share > 1.3) {
      note = 'That\'s more than your bills show — some hours are probably too high.'.tr;
    } else {
      note = 'Matches your bills well.'.tr;
    }
    final accent = h.dark ? AppColors.amber : AppColors.navy;

    Widget figure(String label, Widget value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: h.muted), maxLines: 1),
              SizedBox(
                height: 34,
                child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: value),
              ),
            ],
          ),
        );

    return AppCard(
      padding: const EdgeInsets.all(18),
      gradient: h.gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('YOUR APPLIANCES USE ABOUT'.tr, style: theme.textTheme.labelSmall?.copyWith(color: h.muted)),
          const SizedBox(height: 8),
          Row(
            children: [
              figure(
                'UNITS A MONTH'.tr,
                AnimatedNumber(
                  value: total,
                  format: Fmt.whole,
                  duration: const Duration(milliseconds: 400),
                  style: theme.textTheme.headlineMedium?.copyWith(color: h.fg, fontWeight: FontWeight.w800),
                ),
              ),
              figure(
                'COST A MONTH'.tr,
                AnimatedNumber(
                  value: cost,
                  format: Fmt.rs,
                  duration: const Duration(milliseconds: 400),
                  style: theme.textTheme.headlineMedium?.copyWith(color: accent, fontWeight: FontWeight.w800),
                ),
              ),
              if (share != null)
                figure(
                  'OF YOUR BILL'.tr,
                  Text('{0}%'.trf({'0': (share * 100).clamp(0, 999).round()}),
                      style: theme.textTheme.headlineMedium?.copyWith(color: h.fg, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          if (share != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: share.clamp(0.0, 1.0),
                minHeight: 8,
                color: AppColors.amber,
                backgroundColor: h.fg.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '{0} of about {1} units on your bills'.trf({'0': Fmt.whole(total), '1': Fmt.whole(target)}),
              style: theme.textTheme.bodySmall?.copyWith(color: h.muted),
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note, style: theme.textTheme.bodySmall?.copyWith(color: h.fg)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- savings

class _SavingsCard extends StatelessWidget {
  const _SavingsCard({required this.items, required this.rate});

  final List<Appliance> items;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ideas = AppliancePlanner.savings(items, rate);
    final p = AppPalette.of(context);
    if (ideas.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: p.safe),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Your appliances are already efficient. Staying under your slab limit is the next big saving.'.tr,
                  style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }
    final best = ideas.fold<double>(0, (s, i) => s + i.rupees);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('WAYS TO SAVE'.tr, style: theme.textTheme.labelSmall)),
              Text('up to {0}/month'.trf({'0': Fmt.rs(best)}),
                  style: theme.textTheme.labelLarge?.copyWith(color: p.safe, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          for (final (i, idea) in ideas.indexed) ...[
            if (i > 0) const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArtTile(Art.forAppliance(idea.applianceName ?? '', 'other'), size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(idea.title, style: theme.textTheme.titleSmall),
                      Text(idea.body, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(Fmt.rs(idea.rupees),
                    style: theme.textTheme.titleSmall?.copyWith(color: p.safe, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AssistantScreen(initialMessage: 'How can I lower my bill with my appliances?'.tr),
              )),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: Text('Ask for a plan'.tr),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- one appliance

/// Name, share of the bill and cost, with − / + for how many and hours.
class _ApplianceRow extends StatelessWidget {
  const _ApplianceRow({required this.appliance, required this.total, required this.rate, required this.onRemove});

  final Appliance appliance;
  final double total;
  final double rate;
  final VoidCallback onRemove;

  Future<void> _set(BuildContext context, {int? quantity, double? hours}) async {
    HapticFeedback.selectionClick();
    final state = context.read<AppState>();
    if (quantity == 0) {
      onRemove();
      return;
    }
    await state.saveAppliance(appliance.copyWith(quantity: quantity, hoursPerDay: hours));
  }

  static double _stepHours(double h, int dir) {
    final step = h < 1 || (h == 1 && dir < 0) ? 0.25 : (h < 4 || (h == 4 && dir < 0) ? 0.5 : 1.0);
    return (h + dir * step).clamp(0.25, 24).toDouble();
  }

  static String _hours(double h) =>
      h < 1 ? '{0} min'.trf({'0': (h * 60).round()}) : '{0} h'.trf({'0': Fmt.oneDp(h).replaceAll('.0', '')});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = appliance;
    final share = total <= 0 ? 0.0 : a.monthlyUnits / total;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      onTap: () => ApplianceSheet.show(context, existing: a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ArtTile(Art.forAppliance(a.name, a.category), size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name.tr, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      '{0} W · {1} units a month'.trf({'0': a.watts * a.quantity, '1': a.monthlyUnits.round()}),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Fmt.rs(a.monthlyUnits * rate),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text('a month'.tr, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.0, 1.0),
                    minHeight: 6,
                    color: AppColors.amber,
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('{0}%'.trf({'0': (share * 100).round()}),
                    textAlign: TextAlign.end, style: theme.textTheme.labelMedium),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _Stepper(
                label: '× {0}'.trf({'0': a.quantity}),
                onMinus: () => _set(context, quantity: a.quantity - 1),
                onPlus: a.quantity >= 50 ? null : () => _set(context, quantity: a.quantity + 1),
                minusIcon: a.quantity == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
              ),
              const Spacer(),
              _Stepper(
                label: '{0}/day'.trf({'0': _hours(a.hoursPerDay)}),
                onMinus: a.hoursPerDay <= 0.25 ? null : () => _set(context, hours: _stepHours(a.hoursPerDay, -1)),
                onPlus: a.hoursPerDay >= 24 ? null : () => _set(context, hours: _stepHours(a.hoursPerDay, 1)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, this.onMinus, this.onPlus, this.minusIcon = Icons.remove_rounded});

  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final IconData minusIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: onMinus,
            icon: Icon(minusIcon),
          ),
          // Fixed width, so the buttons don't shift as the value changes.
          SizedBox(
            width: 64,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, textAlign: TextAlign.center, style: theme.textTheme.labelLarge, maxLines: 1),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: onPlus,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
