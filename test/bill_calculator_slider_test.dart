import 'package:bijli_bachao/core/theme/app_theme.dart';
import 'package:bijli_bachao/features/home/bill_calculator_screen.dart';
import 'package:bijli_bachao/services/settings_service.dart';
import 'package:bijli_bachao/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'tariff_calculator_test.dart' show loadTariff;

void main() {
  Future<void> open(WidgetTester tester, {double textScale = 1, Size size = const Size(390, 844)}) async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    final settings = await SettingsService.create();
    final state = AppState(settings: settings)..debugUseTariff(loadTariff());
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const BillCalculatorScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('dragging the units slider across 100/200/300 never moves it', (tester) async {
    await open(tester);
    final slider = find.byType(Slider);
    final top = tester.getTopLeft(slider);
    // Start at 0 units and drag right in small steps, past every limit.
    await tester.tap(find.text('100'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(slider));
    final width = tester.getSize(slider).width;
    for (var i = 0; i < 40; i++) {
      await gesture.moveBy(Offset(width / 80, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(slider), top, reason: 'step $i');
    }
    for (var i = 0; i < 40; i++) {
      await gesture.moveBy(Offset(-width / 40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(slider), top, reason: 'back $i');
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(slider), top);
    expect(tester.takeException(), isNull);
  });

  testWidgets('presets across slab limits keep the slider in place', (tester) async {
    await open(tester);
    final slider = find.byType(Slider);
    final top = tester.getTopLeft(slider);
    for (final p in ['100', '200', '300', '400', '500', '200']) {
      await tester.tap(find.text(p));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(slider), top, reason: p);
    }
  });

  testWidgets('no overflow on a small phone with large text', (tester) async {
    await open(tester, textScale: 1.6, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('200').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
