import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../services/backup/backup_data.dart';
import '../../services/backup/backup_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/hero_style.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/loading_button.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/app_state.dart';
import 'widgets/restore_preview_sheet.dart';
import '../../core/l10n/l10n.dart';

/// Tools → Backup. Also opened from onboarding ("Restore a
/// backup") with [restoreOnly], where saving makes no sense.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, this.restoreOnly = false});

  final bool restoreOnly;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  static const int _maxFileBytes = 20 * 1024 * 1024;

  bool _saving = false;
  bool _busy = false;
  late Future<List<LocalBackup>> _local = context.read<AppState>().localBackups();

  void _reloadLocal() => setState(() => _local = context.read<AppState>().localBackups());

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AppState>().shareBackup();
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save the backup: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickFile() async {
    final PlatformFile? file;
    try {
      // Any type: backups sent over WhatsApp often lose their .json type.
      file = await FilePicker.pickFile(dialogTitle: 'Choose a Bijli Hisaab backup');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open files: $e');
      return;
    }
    if (file == null || !mounted) return;

    final BackupData data;
    try {
      final size = await file.length();
      if (size != null && size > _maxFileBytes) {
        throw const BackupFormatException('This file is too big to be a Bijli Hisaab backup.');
      }
      final text = utf8.decode(await file.readAsBytes());
      if (!mounted) return;
      data = await context.read<AppState>().readBackup(text);
    } on BackupFormatException catch (e) {
      if (mounted) _problem(e.message);
      return;
    } on FormatException {
      if (mounted) _problem('This file isn\'t a Bijli Hisaab backup.');
      return;
    } catch (e) {
      if (mounted) _problem('Could not read the file: $e');
      return;
    }
    if (mounted) await _confirmAndRestore(data);
  }

  Future<void> _restoreLocal(LocalBackup b) async {
    try {
      final data = await context.read<AppState>().readLocalBackup(b);
      if (mounted) await _confirmAndRestore(data);
    } catch (e) {
      if (mounted) _problem('This copy can\'t be read.');
    }
  }

  Future<void> _confirmAndRestore(BackupData data) async {
    if (data.isEmpty) {
      _problem('This backup has no meters in it.');
      return;
    }
    final state = context.read<AppState>();
    final phoneHasData = state.onboardingDone && state.meters.isNotEmpty;
    final mode = await showRestorePreview(context, summary: data.summary, phoneHasData: phoneHasData);
    if (mode == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final r = await state.restoreBackup(data, mode);
      if (!mounted) return;
      final what = r.total == 0
          ? 'Nothing new — you already had everything in this backup.'.tr
          : 'Restored ${_list([
              if (r.meters > 0) '${r.meters} ${r.meters == 1 ? 'meter' : 'meters'}',
              if (r.readings > 0) '${Fmt.whole(r.readings)} readings',
              if (r.bills > 0) '${r.bills} bills',
              if (r.appliances > 0) '${r.appliances} appliances',
            ])}.';
      showSnack(context, what);
      if (widget.restoreOnly) {
        // Onboarding is finished now; go to the dashboard.
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _reloadLocal();
      }
    } catch (e) {
      if (mounted) _problem('Restore failed, nothing was changed.\n\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _list(List<String> parts) => switch (parts.length) {
        0 => 'nothing',
        1 => parts.first,
        _ => '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}',
      };

  void _problem(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const ArtImage(Art.warning, size: 44),
        title: Text('Can\'t restore'.tr),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'.tr))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final p = AppPalette.of(context);

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.restoreOnly ? 'Restore a backup'.tr : 'Backup & restore'.tr)),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                AppCard(
                  gradient: HeroStyle.of(context).gradient,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const ArtTile(Art.lock, onNavy: true, size: 54),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.restoreOnly ? 'Moving from another phone?'.tr : 'Keep your data safe'.tr,
                              style: theme.textTheme.titleMedium?.copyWith(color: HeroStyle.of(context).fg),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.restoreOnly
                                  ? 'Pick the backup file you saved from Bijli Hisaab.'.tr
                                  : 'Android backs up your data to your Google account automatically. Save a backup file too before changing phones.'.tr,
                              style: theme.textTheme.bodySmall?.copyWith(color: HeroStyle.of(context).muted, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.restoreOnly) ...[
                  SectionHeader('Automatic'.tr),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ArtTile(Art.globe, size: 40),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Google Drive backup'.tr, style: theme.textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text(
                                'Android saves Bijli Hisaab to your Google account about once a day, on Wi-Fi while charging. Set up a new phone with the same Google account and your meters, readings and bills come back by themselves.'.tr,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Make sure it\'s on: phone Settings → Google → Backup.'.tr,
                                style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SectionHeader('Save'.tr),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${state.meters.length} ${state.meters.length == 1 ? 'meter' : 'meters'} with readings, '
                          'bills, appliances and settings — one small file.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Extra safety: send it to Google Drive, your email or WhatsApp yourself.'.tr,
                          style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                        ),
                        const SizedBox(height: 14),
                        LoadingButton(
                          label: 'Save backup'.tr,
                          icon: Icons.ios_share_rounded,
                          loading: _saving,
                          onPressed: _busy ? null : _save,
                        ),
                      ],
                    ),
                  ),
                ],
                SectionHeader('Restore'.tr),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Open a backup file from Drive, WhatsApp, Downloads or anywhere else.'.tr,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: _busy ? null : _pickFile,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: Text('Restore from file'.tr),
                      ),
                    ],
                  ),
                ),
                FutureBuilder<List<LocalBackup>>(
                  future: _local,
                  builder: (context, snap) {
                    final items = snap.data ?? const <LocalBackup>[];
                    if (items.isEmpty && widget.restoreOnly) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader('Copies on this phone'.tr),
                        if (snap.connectionState != ConnectionState.done)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (items.isEmpty)
                          AppCard(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'A copy is saved here every week automatically. The first one appears after a few days of use.'.tr,
                              style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                            ),
                          )
                        else ...[
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (var i = 0; i < items.length; i++) ...[
                                  _LocalTile(backup: items[i], onTap: _busy ? null : () => _restoreLocal(items[i])),
                                  if (i < items.length - 1) const Divider(indent: 70),
                                ],
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                            child: Text(
                              'Weekly copies (last ${BackupService.keepAuto}) and a copy before each restore or reset. '
                              'They are deleted if you uninstall the app — save a backup file too.',
                              style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                            SizedBox(width: 16),
                            Text('Restoring…'.tr),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocalTile extends StatelessWidget {
  const _LocalTile({required this.backup, required this.onTap});

  final LocalBackup backup;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = backup.summary;
    final (art, label) = switch (s.kind) {
      BackupKind.auto => (Art.calendar, 'Weekly copy'),
      BackupKind.beforeRestore => (Art.shield, 'Before restore'),
      BackupKind.beforeReset => (Art.shield, 'Before reset'),
      BackupKind.manual => (Art.memo, 'Saved backup'),
    };
    return ListTile(
      leading: ArtTile(art, size: 40),
      title: Text('$label · ${DateFormat('d MMM, h:mm a').format(s.createdAt)}'),
      subtitle: Text(
        '${s.meters} ${s.meters == 1 ? 'meter' : 'meters'} · ${Fmt.whole(s.readings)} readings · ${s.bills} bills',
      ),
      trailing: const Icon(Icons.restore_rounded),
      onTap: onTap,
    );
  }
}
