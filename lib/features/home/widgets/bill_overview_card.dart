import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/bill.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/hero_style.dart';
import '../../../state/app_state.dart';

/// Your latest bill (amount, due date) and what the next one will roughly be,
/// worked out from your bill history — useful with no meter readings at all.
class BillOverviewCard extends StatelessWidget {
  const BillOverviewCard({super.key, required this.onOpenHistory, this.onViewBill});

  final VoidCallback onOpenHistory;

  /// Opens the official bill page; null when the company has none.
  final VoidCallback? onViewBill;

  /// Units expected on the bill after [latest]: the same month last year when
  /// known (usage follows the seasons), else the average of the last 3 bills.
  static int? nextUnits(List<Bill> newestFirst) {
    if (newestFirst.isEmpty) return null;
    final latest = newestFirst.first.monthDate;
    final next = DateTime(latest.year, latest.month + 1);
    final lastYear = newestFirst.where((b) => b.monthDate == DateTime(next.year - 1, next.month)).firstOrNull;
    if (lastYear != null) return lastYear.units;
    final recent = newestFirst.take(3).toList();
    return (recent.fold<int>(0, (a, b) => a + b.units) / recent.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bills = state.bills;
    if (bills.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final h = HeroStyle.of(context);
    final b = bills.first;
    final prev = bills.length > 1 ? bills[1] : null;
    final today = DateUtils.dateOnly(DateTime.now());
    final due = b.dueDate;
    final daysLeft = due?.difference(today).inDays;

    final next = nextUnits(bills);
    final nextMonth = DateTime(b.monthDate.year, b.monthDate.month + 1);
    final nextAmount = next == null ? null : state.estimateFor(next)?.total;

    final change = prev == null || prev.units == 0 ? null : (b.units - prev.units) / prev.units * 100;

    String dueText() {
      if (due == null || daysLeft == null) return '';
      if (daysLeft > 1) return 'Due {0} · {1} days left'.trf({'0': Fmt.dayShort(due), '1': daysLeft});
      if (daysLeft == 1) return 'Due tomorrow'.tr;
      if (daysLeft == 0) return 'Due today'.tr;
      return 'Due date passed ({0})'.trf({'0': Fmt.dayShort(due)});
    }

    final paid = state.isBillPaid(b);
    final urgent = !paid && daysLeft != null && daysLeft <= 2;

    return AppCard(
      gradient: h.gradient,
      padding: const EdgeInsets.all(18),
      onTap: onOpenHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'YOUR {0} BILL'.trf({'0': Fmt.month(b.monthDate).toUpperCase()}),
            style: theme.textTheme.labelSmall?.copyWith(color: h.muted),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                b.amount > 0 ? Fmt.rs(b.amount) : '{0} units'.trf({'0': b.units}),
                style: theme.textTheme.displaySmall?.copyWith(color: h.fg, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              if (b.amount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '{0} units'.trf({'0': b.units}),
                    style: theme.textTheme.titleSmall?.copyWith(color: h.muted),
                  ),
                ),
            ],
          ),
          if (due != null)
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (urgent ? AppPalette.of(context).danger : h.accent).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    paid ? 'Paid ✓'.tr : dueText(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: paid ? AppPalette.of(context).safe : (urgent ? AppPalette.of(context).danger : h.accent),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: h.fg, visualDensity: VisualDensity.compact),
                    onPressed: () => state.setBillPaid(b, !paid),
                    child: Text(paid ? 'Undo'.tr : 'Mark as paid'.tr),
                  ),
                ),
              ],
            ),
          if (change != null) ...[
            const SizedBox(height: 10),
            Text(
              (change >= 0 ? '{0}% more units than {1}' : '{0}% fewer units than {1}').trf({
                '0': change.abs().round(),
                '1': Fmt.month(prev!.monthDate),
              }),
              style: theme.textTheme.bodySmall?.copyWith(color: h.muted),
            ),
          ],
          if (next != null) ...[
            const SizedBox(height: 14),
            Divider(color: h.fg.withValues(alpha: 0.12), height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.trending_up_rounded, color: h.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextAmount == null
                        ? 'Next bill ({0}): about {1} units'.trf({'0': Fmt.month(nextMonth), '1': next})
                        : 'Next bill ({0}): about {1} units ≈ {2}'.trf({
                            '0': Fmt.month(nextMonth),
                            '1': next,
                            '2': Fmt.rs(nextAmount),
                          }),
                    style: theme.textTheme.bodyMedium?.copyWith(color: h.fg, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          if (onViewBill != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: h.accent, padding: EdgeInsets.zero),
                onPressed: onViewBill,
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: Text('View full bill'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
