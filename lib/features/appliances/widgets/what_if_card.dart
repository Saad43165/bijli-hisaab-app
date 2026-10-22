import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/appliance.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';
import '../../../state/app_state.dart';

/// "What if I used the AC 2 hours less a day?" — units and rupees saved on
/// the whole bill, including a drop to a cheaper slab.
class WhatIfCard extends StatefulWidget {
  const WhatIfCard({super.key, required this.appliances});

  /// Sorted biggest first.
  final List<Appliance> appliances;

  @override
  State<WhatIfCard> createState() => _WhatIfCardState();
}

class _WhatIfCardState extends State<WhatIfCard> {
  int? _id;
  double _hoursLess = 1;

  Appliance get _selected =>
      widget.appliances.firstWhere((a) => a.id == _id, orElse: () => widget.appliances.first);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final state = context.watch<AppState>();
    final a = _selected;
    final maxHours = a.hoursPerDay.clamp(0.5, 24.0);
    final hoursLess = _hoursLess.clamp(0.5, maxHours).toDouble();

    final savedUnits = (a.watts * a.quantity * hoursLess * 30 / 1000).round();
    final base = state.typicalMonthlyUnits;
    final before = state.estimateFor(base);
    final after = state.estimateFor(base - savedUnits);
    final savedRs = before == null || after == null ? 0.0 : before.total - after.total;
    final String? slabDrop = before != null && after != null && after.slab.label != before.slab.label
        ? 'Drops you from the ${before.slab.label} slab to ${after.slab.label} — every unit gets cheaper.'
        : null;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ArtTile(Art.moneyBag, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text('What if…', style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final x in widget.appliances)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: ArtImage(Art.forAppliance(x.name, x.category), size: 18),
                      label: Text(x.name),
                      selected: x.id == a.id,
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        _id = x.id;
                        _hoursLess = x.hoursPerDay >= 2 ? 2 : (x.hoursPerDay / 2).clamp(0.5, 24).toDouble();
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: theme.textTheme.bodyLarge,
              children: [
                const TextSpan(text: 'Use it '),
                TextSpan(
                  text: '${_hours(hoursLess)} less',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: ' a day (now ${_hours(a.hoursPerDay)})'),
              ],
            ),
          ),
          if (maxHours > 0.5)
            Slider(
              value: hoursLess,
              min: 0.5,
              max: maxHours,
              divisions: ((maxHours - 0.5) * 2).round().clamp(1, 47),
              label: _hours(hoursLess),
              onChanged: (v) => setState(() => _hoursLess = v),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.safe.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOU SAVE', style: theme.textTheme.labelSmall?.copyWith(color: p.safe)),
                      Text(
                        '${Fmt.rs(savedRs)} a month',
                        style: theme.textTheme.headlineSmall?.copyWith(color: p.safe),
                      ),
                      Text(
                        '$savedUnits units · bill ${before == null ? '' : Fmt.rs(before.total)} → '
                        '${after == null ? '' : Fmt.rs(after.total)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (slabDrop != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.south_rounded, size: 18, color: p.safe),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    slabDrop,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Based on about ${Fmt.whole(base)} units a month, with taxes and slab rates.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _hours(double h) {
    final whole = h == h.roundToDouble();
    final v = whole ? h.toInt().toString() : h.toStringAsFixed(1);
    return '$v ${h == 1 ? 'hour' : 'hours'}';
  }
}
