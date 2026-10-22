import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/appliance.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../state/app_state.dart';
import '../../../core/l10n/l10n.dart';

/// "How many do you have?" — tap + / − on the usual appliances and add them
/// all at once with typical hours. Used as the empty state and from Quick add.
class QuickSetup extends StatefulWidget {
  const QuickSetup({super.key, this.inSheet = false, this.onCustom});

  /// In a bottom sheet: closes it after adding.
  final bool inSheet;

  /// Shows a "Something else" button that opens the full appliance picker.
  final VoidCallback? onCustom;

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const FractionallySizedBox(heightFactor: 0.92, child: QuickSetup(inSheet: true)),
      );

  @override
  State<QuickSetup> createState() => _QuickSetupState();
}

class _QuickSetupState extends State<QuickSetup> {
  final Map<String, int> _counts = {};
  bool _saving = false;

  int get _total => _counts.values.fold(0, (s, n) => s + n);

  double get _units => _counts.entries.fold(0.0, (s, e) {
        final p = ApplianceCatalog.preset(e.key);
        return p == null ? s : s + p.watts * e.value * p.hoursPerDay * 30 / 1000;
      });

  void _change(String name, int delta) {
    HapticFeedback.selectionClick();
    setState(() => _counts[name] = ((_counts[name] ?? 0) + delta).clamp(0, 50));
  }

  Future<void> _add() async {
    final state = context.read<AppState>();
    final meterId = state.activeMeter?.id;
    if (meterId == null || _total == 0) return;
    final now = DateTime.now();
    final list = [
      for (final e in _counts.entries)
        if (e.value > 0)
          if (ApplianceCatalog.preset(e.key) case final p?)
            Appliance(
              meterId: meterId,
              name: p.name,
              category: p.category,
              watts: p.watts,
              quantity: e.value,
              hoursPerDay: p.hoursPerDay,
              createdAt: now,
            ),
    ];
    setState(() => _saving = true);
    try {
      await state.addAppliances(list);
      if (!mounted) return;
      showSnack(context, 'Added ${list.length} ${list.length == 1 ? 'appliance' : 'appliances'} — '
          'tap one to adjust its hours');
      if (widget.inSheet) {
        Navigator.pop(context);
      } else if (mounted) {
        setState(() => _counts.clear());
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not add: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = context.watch<AppState>().marginalRate;
    final names = ApplianceCatalog.quickSetup;

    final grid = GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 128,
      ),
      itemCount: names.length,
      itemBuilder: (context, i) {
        final p = ApplianceCatalog.preset(names[i])!;
        final n = _counts[p.name] ?? 0;
        return _Counter(
          name: p.name,
          art: Art.forAppliance(p.name, p.category),
          detail: '${p.watts} W · ${_hours(p.hoursPerDay)}/day',
          count: n,
          onAdd: () => _change(p.name, 1),
          onRemove: n == 0 ? null : () => _change(p.name, -1),
        );
      },
    );

    final footer = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _total == 0
          ? Text(
              'Tap + for each one you have. You can change hours later.'.tr,
              key: const ValueKey('hint'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            )
          : FilledButton(
              key: const ValueKey('add'),
              onPressed: _saving ? null : _add,
              child: Text('Add $_total ${_total == 1 ? 'item' : 'items'} · '
                  '~${Fmt.whole(_units)} units, ${Fmt.rs(_units * rate)} a month'),
            ),
    );

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What do you have at home?'.tr, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Count them and see which ones cost you the most each month.'.tr,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
      ],
    );

    // The list scrolls; the Add button stays pinned at the bottom.
    return Padding(
      padding: EdgeInsets.fromLTRB(16, widget.inSheet ? 0 : 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: grid),
          const SizedBox(height: 12),
          footer,
          if (widget.onCustom != null)
            TextButton.icon(
              onPressed: widget.onCustom,
              icon: const Icon(Icons.search_rounded),
              label: Text('Something else? Search all appliances'.tr),
            ),
        ],
      ),
    );
  }

  static String _hours(double h) => h < 1 ? '${(h * 60).round()} min' : '${Fmt.oneDp(h).replaceAll('.0', '')} h';
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.name,
    required this.art,
    required this.detail,
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  final String name;
  final String art;
  final String detail;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = count > 0;
    return AppCard(
      elevated: !on,
      onTap: onAdd,
      borderColor: on ? AppColors.amber : null,
      color: on ? AppColors.amber.withValues(alpha: 0.10) : null,
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArtImage(art, size: 34),
              const Spacer(),
              if (on)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(999)),
                  child: Text('×$count',
                      style: theme.textTheme.labelLarge?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
          Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _Round(icon: Icons.remove_rounded, onTap: onRemove),
              const SizedBox(width: 6),
              _Round(icon: Icons.add_rounded, onTap: onAdd, filled: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton.filledTonal(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: filled ? AppColors.amber : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          foregroundColor: filled ? AppColors.navy : theme.colorScheme.onSurface,
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}
