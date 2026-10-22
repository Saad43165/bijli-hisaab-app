import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/backup/backup_data.dart';
import '../../../services/backup/restore_plan.dart';
import '../../../shared/widgets/art.dart';

/// Shows what's in a backup and asks how to restore it.
/// Returns the chosen [RestoreMode], or null if cancelled.
Future<RestoreMode?> showRestorePreview(
  BuildContext context, {
  required BackupSummary summary,
  required bool phoneHasData,
}) {
  return showModalBottomSheet<RestoreMode>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => RestorePreviewSheet(summary: summary, phoneHasData: phoneHasData),
  );
}

class RestorePreviewSheet extends StatefulWidget {
  const RestorePreviewSheet({super.key, required this.summary, required this.phoneHasData});

  final BackupSummary summary;
  final bool phoneHasData;

  @override
  State<RestorePreviewSheet> createState() => _RestorePreviewSheetState();
}

class _RestorePreviewSheetState extends State<RestorePreviewSheet> {
  // Merge is the safer default when the phone already has data.
  late RestoreMode _mode = widget.phoneHasData ? RestoreMode.merge : RestoreMode.replace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final s = widget.summary;
    final when = DateFormat('d MMM yyyy, h:mm a').format(s.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ArtTile(Art.memo, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Restore this backup?', style: theme.textTheme.titleLarge),
                    Text('Saved $when', style: theme.textTheme.bodySmall?.copyWith(color: p.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Count(value: s.meters, label: s.meters == 1 ? 'meter' : 'meters'),
              _Count(value: s.readings, label: 'readings'),
              _Count(value: s.bills, label: 'bills'),
              _Count(value: s.appliances, label: 'appliances'),
            ],
          ),
          if (s.meterNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              s.meterNames.join(' · '),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
            ),
          ],
          if (widget.phoneHasData) ...[
            const SizedBox(height: 18),
            _ModeOption(
              selected: _mode == RestoreMode.merge,
              icon: Icons.merge_rounded,
              title: 'Add to my data',
              text: 'Keeps everything on this phone and adds what\'s missing.',
              onTap: () => setState(() => _mode = RestoreMode.merge),
            ),
            const SizedBox(height: 10),
            _ModeOption(
              selected: _mode == RestoreMode.replace,
              icon: Icons.swap_horiz_rounded,
              title: 'Replace my data',
              text: 'Deletes what\'s on this phone and loads the backup.',
              danger: true,
              onTap: () => setState(() => _mode = RestoreMode.replace),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: p.safe),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'A copy of your current data is saved first, so you can undo this.',
                    style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: _mode == RestoreMode.replace && widget.phoneHasData ? p.danger : null,
            ),
            onPressed: () => Navigator.of(context).pop(_mode),
            icon: const Icon(Icons.restore_rounded),
            label: Text(
              !widget.phoneHasData
                  ? 'Restore'
                  : _mode == RestoreMode.merge
                      ? 'Add to my data'
                      : 'Replace my data',
            ),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(Fmt.whole(value), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: AppPalette.of(context).muted)),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
    this.danger = false,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final accent = danger ? p.danger : AppColors.amberDeep;
    return Material(
      color: selected ? accent.withValues(alpha: 0.08) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? accent : p.border, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: selected ? accent : p.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(text, style: theme.textTheme.bodySmall?.copyWith(color: p.muted)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? accent : p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
