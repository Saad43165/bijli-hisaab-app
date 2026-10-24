import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/companies.dart';
import '../../core/l10n/l10n.dart';
import '../../core/navigation/app_nav.dart';
import '../../services/online_bill_service.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/loading_button.dart';
import '../../state/app_state.dart';
import 'meter_edit_screen.dart';
import 'widgets/bill_lookup.dart';

/// Add another meter (shop, parents' house…) by its reference number: the
/// company, details and bill history come in by themselves.
class AddMeterScreen extends StatefulWidget {
  const AddMeterScreen({super.key});

  @override
  State<AddMeterScreen> createState() => _AddMeterScreenState();
}

class _AddMeterScreenState extends State<AddMeterScreen> {
  final _name = TextEditingController();
  PowerCompany? _company;
  OnlineBill? _bill;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final name = _name.text.trim().isEmpty ? '{0} meter'.trf({'0': _company!.shortCode}) : _name.text.trim();
    setState(() => _saving = true);
    try {
      final already = state.meterWithReference(_bill!.reference) != null;
      await state.addMeterFromOnlineBill(_company!, _bill!, name: name);
      if (!mounted) return;
      showSnack(
        context,
        already
            ? 'This meter was already added — switched to it and updated its bills.'.tr
            : '{0} added with {1} months of bills. It\'s now your active meter.'
                .trf({'0': name, '1': _bill!.history.length + 1}),
      );
      AppNav.goTab(0);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: {0}'.trf({'0': e}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final found = _bill != null;
    return Scaffold(
      appBar: AppBar(title: Text('Add a meter'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (!found) ...[
            Text('Type the reference number from this meter\'s bill'.tr, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'For your shop, your parents\' house or a second connection. We\'ll find the company and bills.'.tr,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            ReferenceLookup(
              onFound: (c, b) => setState(() {
                _company = c;
                _bill = b;
              }),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const MeterEditScreen()),
              ),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text('K-Electric, or no reference number? Set up by hand'.tr),
            ),
          ] else ...[
            FoundBillCard(company: _company!, bill: _bill!),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name this meter'.tr,
                hintText: 'Shop, Ammi ka ghar, Upstairs…'.tr,
              ),
            ),
            const SizedBox(height: 16),
            LoadingButton(loading: _saving, onPressed: _save, label: 'Add meter'.tr, icon: Icons.add_rounded),
            TextButton(
              onPressed: _saving ? null : () => setState(() => _bill = null),
              child: Text('Not this bill'.tr),
            ),
          ],
        ],
      ),
    );
  }
}
