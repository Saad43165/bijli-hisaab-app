import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/loading_button.dart';
import '../../state/app_state.dart';

/// Quick entry of the last 12 months from the bill's history table.
class PastBillsScreen extends StatefulWidget {
  const PastBillsScreen({super.key});

  @override
  State<PastBillsScreen> createState() => _PastBillsScreenState();
}

class _PastBillsScreenState extends State<PastBillsScreen> {
  late final List<String> _months;
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _months = [for (var i = 1; i <= 12; i++) Fmt.monthKey(DateTime(now.year, now.month - i))];
    final existing = {for (final b in context.read<AppState>().bills) b.month: b.units};
    _controllers = {
      for (final m in _months) m: TextEditingController(text: existing[m]?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final values = <String, int>{};
    for (final m in _months) {
      final n = Fmt.parseNumber(_controllers[m]!.text);
      if (n != null && n >= 0) values[m] = n.round();
    }
    if (values.isEmpty) {
      showSnack(context, 'Enter units for at least one month');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().saveHistory(values);
      if (!mounted) return;
      showSnack(context, 'Saved ${values.length} months');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Past 12 months')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Your bill has a table of the last 12 months with units. '
                'Copy them here — leave blank if unknown.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _months.length,
                itemBuilder: (context, i) {
                  final m = _months[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(Fmt.monthKeyLabel(m), style: theme.textTheme.titleMedium),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controllers[m],
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textInputAction:
                                i == _months.length - 1 ? TextInputAction.done : TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'Units',
                              suffixText: 'units',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: LoadingButton(label: 'Save', loading: _saving, onPressed: _save),
            ),
          ],
        ),
      ),
    );
  }
}
