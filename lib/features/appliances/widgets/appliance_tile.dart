import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/appliance.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/art.dart';

class ApplianceTile extends StatelessWidget {
  const ApplianceTile({
    super.key,
    required this.appliance,
    required this.share,
    required this.monthlyCost,
    required this.color,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Appliance appliance;
  final double share;
  final double monthlyCost;

  /// Same colour as this appliance in the donut.
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = appliance;
    final qty = a.quantity > 1 ? '${a.quantity} × ' : '';
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      child: Column(
        children: [
          Row(
            children: [
              ArtTile(Art.forAppliance(a.name, a.category), size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '$qty${a.watts} W · ${_hours(a.hoursPerDay)} a day',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${Fmt.rs(monthlyCost)}/mo', style: theme.textTheme.titleSmall),
                  Text(Fmt.units(a.monthlyUnits), style: theme.textTheme.bodySmall),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurfaceVariant),
                onSelected: (v) => switch (v) {
                  'edit' => onTap(),
                  'duplicate' => onDuplicate(),
                  _ => onDelete(),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'delete', child: Text('Remove')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: share.clamp(0, 1).toDouble(),
                      minHeight: 6,
                      color: color,
                      backgroundColor: theme.colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${(share * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _hours(double h) {
    if (h < 1) return '${(h * 60).round()} min';
    return '${h == h.roundToDouble() ? h.toInt() : h.toStringAsFixed(1)} h';
  }
}
