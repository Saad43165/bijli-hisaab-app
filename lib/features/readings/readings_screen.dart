import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/meter_reading.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_pill.dart';
import '../../state/app_state.dart';
import '../../shared/widgets/art.dart';
import 'add_reading_screen.dart';
import '../../core/l10n/l10n.dart';

class ReadingsScreen extends StatelessWidget {
  const ReadingsScreen({super.key});

  void _add(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AddReadingScreen()),
      );

  static Future<bool> _confirmDelete(BuildContext context, MeterReading r) => confirmDialog(
        context,
        title: 'Delete reading?'.tr,
        message: '${Fmt.whole(r.value)} on ${Fmt.day(r.date)} will be removed.',
        confirmLabel: 'Delete'.tr,
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final readings = state.readings.reversed.toList(); // newest first

    return Scaffold(
      appBar: AppBar(title: Text('Readings · ${state.activeMeter?.name ?? ''}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_rounded),
        label: Text('Add reading'.tr, style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: readings.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  art: Art.stopwatch,
                  title: 'No readings yet'.tr,
                  message: 'Note the number on your meter every few days to track this month\'s units.'.tr,
                  actionLabel: 'Add reading'.tr,
                  onAction: () => _add(context),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Row(
                    children: [
                      Icon(Icons.swipe_left_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${readings.length} ${readings.length == 1 ? 'reading' : 'readings'} · '
                          'swipe left or long-press to delete',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < readings.length; i++) ...[
                        _ReadingRow(
                          reading: readings[i],
                          older: i + 1 < readings.length ? readings[i + 1] : null,
                          onDelete: () async {
                            final r = readings[i];
                            if (await _confirmDelete(context, r) && r.id != null) {
                              await state.deleteReading(r.id!);
                            }
                          },
                          confirmDismiss: () => _confirmDelete(context, readings[i]),
                          onDismissed: () {
                            final id = readings[i].id;
                            if (id != null) state.deleteReading(id);
                          },
                        ),
                        if (i < readings.length - 1) const Divider(indent: 72),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({
    required this.reading,
    required this.older,
    required this.onDelete,
    required this.confirmDismiss,
    required this.onDismissed,
  });

  final MeterReading reading;
  final MeterReading? older;
  final VoidCallback onDelete;
  final Future<bool> Function() confirmDismiss;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = reading;
    String? delta;
    final o = older;
    if (o != null) {
      final days = DateX.daysBetween(o.date, r.date);
      final units = r.value - o.value;
      if (days > 0) {
        delta = '+${Fmt.whole(units)} in $days ${days == 1 ? 'day' : 'days'} · ${Fmt.oneDp(units / days)}/day';
      }
    }

    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
      ),
      confirmDismiss: (_) => confirmDismiss(),
      onDismissed: (_) => onDismissed(),
      child: ListTile(
        onLongPress: onDelete,
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        leading: ArtTile(
          switch (r.source) {
            'bill' => Art.receipt,
            'photo' => Art.camera,
            _ => Art.stopwatch,
          },
          size: 42,
        ),
        title: Text(Fmt.whole(r.value), style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 0.5)),
        subtitle: Text([
          Fmt.day(r.date),
          if (r.peakValue != null) 'Off-peak ${Fmt.whole(r.offPeakValue!)} · Peak ${Fmt.whole(r.peakValue!)}',
          if (r.exportValue != null) 'Import ${Fmt.whole(r.value)} · Export ${Fmt.whole(r.exportValue!)}',
          ?delta,
        ].join('\n')),
        isThreeLine: delta != null || r.peakValue != null || r.exportValue != null,
        trailing: switch (r.source) {
          'bill' => const TagBadge('From bill'),
          'photo' => const TagBadge('From photo'),
          _ => null,
        },
      ),
    );
  }
}
