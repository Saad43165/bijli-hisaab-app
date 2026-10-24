import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/l10n/l10n.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Draw behind the status and navigation bars on every Android version, as
  // Android 15+ always does, so the app looks the same on all phones.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));

  final settings = await SettingsService.create();
  L10n.setLanguage(settings.language);
  await initializeDateFormatting();
  await NotificationService.instance.init();

  final state = AppState(settings: settings);

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state..init(),
      child: const BijliBachaoApp(),
    ),
  );
}
