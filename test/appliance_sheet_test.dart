import 'package:bijli_bachao/core/theme/app_theme.dart';
import 'package:bijli_bachao/data/models/appliance.dart';
import 'package:bijli_bachao/features/appliances/appliances_screen.dart';
import 'package:bijli_bachao/features/appliances/widgets/appliance_sheet.dart';
import 'package:bijli_bachao/services/settings_service.dart';
import 'package:bijli_bachao/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'tariff_calculator_test.dart' show loadTariff;

Appliance _ac({int qty = 1, double hours = 6, String name = 'AC 1.5 ton (non-inverter)'}) => Appliance(
      id: 1,
      meterId: 1,
      name: name,
      category: 'cooling',
      watts: 1800,
      quantity: qty,
      hoursPerDay: hours,
      createdAt: DateTime(2026),
    );

void main() {
  Future<void> open(WidgetTester tester, Appliance a, {double textScale = 1, Size size = const Size(390, 844)}) async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    final settings = await SettingsService.create();
    final state = AppState(settings: settings)..debugUseTariff(loadTariff());
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        // Anchored at the bottom like the real sheet: if anything below a
        // slider changes height, the slider moves.
        home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: ApplianceSheet(existing: a))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> dragAndCheck(WidgetTester tester, Finder slider) async {
    final top = tester.getTopLeft(slider);
    final width = tester.getSize(slider).width;
    final g = await tester.startGesture(tester.getTopLeft(slider) + Offset(24, tester.getSize(slider).height / 2));
    for (var i = 0; i < 30; i++) {
      await g.moveBy(Offset(width / 32, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(slider), top, reason: 'step $i');
    }
    for (var i = 0; i < 30; i++) {
      await g.moveBy(Offset(-width / 32, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(slider), top, reason: 'back $i');
    }
    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('hours and quantity sliders stay put while dragging', (tester) async {
    await open(tester, _ac());
    final sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(2));
    await dragAndCheck(tester, sliders.at(0));
    await dragAndCheck(tester, sliders.at(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow on a small phone with large text', (tester) async {
    await open(tester, _ac(qty: 12, hours: 24), textScale: 1.5, size: const Size(320, 900));
    expect(tester.takeException(), isNull);
  });

  test('sort: biggest cost first, or by name', () {
    final list = [_ac(hours: 2, name: 'Fan'), _ac(hours: 10, name: 'AC'), _ac(hours: 5, name: 'Motor')];
    expect(AppliancesScreen.sorted(list, byName: false).map((a) => a.name), ['AC', 'Motor', 'Fan']);
    expect(AppliancesScreen.sorted(list, byName: true).map((a) => a.name), ['AC', 'Fan', 'Motor']);
  });
}
