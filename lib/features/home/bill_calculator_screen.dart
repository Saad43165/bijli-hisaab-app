import 'package:flutter/material.dart';

import 'widgets/bill_calculator_card.dart';

/// Tools → Bill calculator.
class BillCalculatorScreen extends StatelessWidget {
  const BillCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: const [BillCalculatorCard()],
      ),
    );
  }
}
