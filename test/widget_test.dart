import 'package:bijli_bachao/core/theme/app_theme.dart';
import 'package:bijli_bachao/services/usage_forecaster.dart';
import 'package:bijli_bachao/shared/widgets/art.dart';
import 'package:bijli_bachao/shared/widgets/empty_state.dart';
import 'package:bijli_bachao/shared/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared widgets render with the app theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Column(
            children: [
              StatusPill(status: UsageStatus.danger),
              EmptyState(art: Art.receipt, title: 'No bills yet', message: 'Add one'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Will cross limit'), findsOneWidget);
    expect(find.text('No bills yet'), findsOneWidget);
  });
}
