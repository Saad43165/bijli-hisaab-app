import 'dart:io';
import 'dart:ui' as ui;

import 'package:bijli_bachao/core/theme/app_theme.dart';
import 'package:bijli_bachao/data/models/tariff.dart';
import 'package:bijli_bachao/features/home/widgets/share_summary_sheet.dart';
import 'package:bijli_bachao/services/tariff_calculator.dart';
import 'package:bijli_bachao/services/usage_forecaster.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's real fonts so text is measured as on the phone.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  }

  await load(AppTheme.fontFamily, [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]);
  await load(AppTheme.urduFontFamily, ['NotoNastaliqUrdu-Regular.ttf']);
}

CycleSummary _summary({double used = 142, double projected = 213, double bill = 9876, int? target = 200}) => CycleSummary(
      cycleStart: DateTime(2026, 10, 9),
      cycleEnd: DateTime(2026, 11, 9),
      today: DateTime(2026, 10, 22),
      consumerClass: ConsumerClass.unprotected,
      protectionReason: '',
      status: UsageStatus.warn,
      unitsUsed: used,
      dailyRate: 10.9,
      projectedUnits: projected,
      targetLimit: target,
      safeDailyBudget: target == null ? null : 3.4,
      estimateProjected: BillEstimate(
        units: projected.round(),
        appliedClass: ConsumerClass.unprotected,
        slab: const Slab(from: 201, to: 300, rate: 30),
        energy: bill,
        fixed: 0,
        fcSurcharge: 0,
        fca: 0,
        qta: 0,
        electricityDuty: 0,
        gst: 0,
        tvFee: 0,
      ),
    );

void main() {
  setUpAll(_loadFonts);

  Future<void> pump(WidgetTester tester, CycleSummary s, {required bool light, GlobalKey? key}) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: Material(
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SummaryPicture(summary: s, meterName: 'Home meter', company: 'LESCO', light: light),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final light in [false, true]) {
    testWidgets('long numbers fit without overflow (${light ? 'light' : 'dark'})', (tester) async {
      await pump(tester, _summary(used: 1234, projected: 2345, bill: 123456), light: light);
      expect(tester.takeException(), isNull);
      expect(find.text('of 200 units'), findsOneWidget);
      expect(find.text('استعمال شدہ یونٹ'), findsOneWidget);
      expect(find.text('متوقع بل'), findsOneWidget);
      expect(find.text('Rs 123,456'), findsOneWidget);
    });
  }

  testWidgets('no slab limit left', (tester) async {
    await pump(tester, _summary(target: null), light: false);
    expect(tester.takeException(), isNull);
  });

  // Writes sample pictures to look at: SHARE_SAMPLE=<dir> flutter test test/share_picture_test.dart
  final out = Platform.environment['SHARE_SAMPLE'];
  if (out != null) {
    for (final light in [false, true]) {
      testWidgets('writes sample ${light ? 'light' : 'dark'}', (tester) async {
        final key = GlobalKey();
        await pump(tester, _summary(used: 1234, projected: 2345, bill: 123456), light: light, key: key);
        await tester.runAsync(() async {
          // Let the brand image decode before drawing.
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final box = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await box.toImage(pixelRatio: 3);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$out/share_sample${light ? '_light' : ''}.png').writeAsBytesSync(png!.buffer.asUint8List());
          expect(image.width, 1080);
          expect(image.height, 1350);
        });
      });
    }
  }
}
