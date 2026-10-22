import 'package:flutter/material.dart';

import 'widgets/bill_calculator_card.dart';
import '../../core/l10n/l10n.dart';

/// Tools → Bill calculator.
class BillCalculatorScreen extends StatelessWidget {
  const BillCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bill calculator'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: const [BillCalculatorCard()],
      ),
    );
  }
}
