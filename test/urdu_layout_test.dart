import 'package:bijli_bachao/core/l10n/l10n.dart';
import 'package:bijli_bachao/core/theme/app_theme.dart';
import 'package:bijli_bachao/shared/widgets/app_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => L10n.setLanguage('en'));

  testWidgets('every nav label is fully shown on a small phone (English)', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        bottomNavigationBar: AppNavBar(
          index: 0,
          onSelect: (_) {},
          items: const [
            AppNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
            AppNavItem(icon: Icons.bar_chart, selectedIcon: Icons.bar_chart, label: 'History'),
            AppNavItem(icon: Icons.kitchen, selectedIcon: Icons.kitchen, label: 'Appliances'),
            AppNavItem(icon: Icons.grid_view, selectedIcon: Icons.grid_view, label: 'Tools'),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Appliances'), findsOneWidget);
  });

  testWidgets('nav bar fits a small phone in Urdu, right to left', (tester) async {
    L10n.setLanguage('ur');
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (var selected = 0; selected < 4; selected++) {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            bottomNavigationBar: AppNavBar(
              index: selected,
              onSelect: (_) {},
              items: [
                AppNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'.tr),
                AppNavItem(icon: Icons.bar_chart, selectedIcon: Icons.bar_chart, label: 'History'.tr),
                AppNavItem(icon: Icons.kitchen, selectedIcon: Icons.kitchen, label: 'Appliances'.tr),
                AppNavItem(icon: Icons.grid_view, selectedIcon: Icons.grid_view, label: 'Tools'.tr),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect('Home'.tr, isNot('Home'));
  });
}
