import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/meter.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/loading_button.dart';
import '../../state/app_state.dart';
import 'widgets/meter_form.dart';
import '../../core/l10n/l10n.dart';

/// Add a new meter (meterId == null) or edit an existing one.
class MeterEditScreen extends StatefulWidget {
  const MeterEditScreen({super.key, this.meterId});

  final int? meterId;

  @override
  State<MeterEditScreen> createState() => _MeterEditScreenState();
}

class _MeterEditScreenState extends State<MeterEditScreen> {
  final _formKey = GlobalKey<MeterFormState>();
  bool _saving = false;

  Meter? _existing(AppState state) =>
      state.meters.where((m) => m.id == widget.meterId).firstOrNull;

  Future<void> _save() async {
    final result = _formKey.currentState?.submit();
    if (result == null) return;
    final state = context.read<AppState>();
    setState(() => _saving = true);
    try {
      if (widget.meterId == null) {
        await state.addMeter(result.meter);
        if (result.reading != null) {
          await state.addReading(result.reading!, result.readingDate ?? DateTime.now());
        }
      } else {
        await state.updateMeter(result.meter);
      }
      // New meters become active; for an edit, only the active meter's bills.
      if (result.onlineBill != null && state.activeMeter?.id == (result.meter.id ?? state.activeMeter?.id)) {
        await state.importOnlineBill(result.onlineBill!);
      }
      if (!mounted) return;
      showSnack(context, 'Meter saved'.tr);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: {0}'.trf({'0': e}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Meter meter) async {
    final state = context.read<AppState>();
    final nav = Navigator.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Delete {0}?'.trf({'0': meter.name}),
      message: 'All readings, bills and appliances for this meter will be deleted.'.tr,
    );
    if (!ok) return;
    nav.pop();
    await state.deleteMeter(meter.id!);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final existing = _existing(state);
    final isNew = widget.meterId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Add meter'.tr : 'Edit meter'.tr),
        actions: [
          if (existing != null && state.meters.length > 1)
            IconButton(
              onPressed: () => _delete(existing),
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete meter'.tr,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            MeterForm(key: _formKey, initial: existing, askForReading: isNew),
            const SizedBox(height: 24),
            LoadingButton(label: 'Save meter'.tr, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
