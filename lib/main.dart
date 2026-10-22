import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/l10n/l10n.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final settings = await SettingsService.create();
  L10n.setLanguage(settings.language);
  await NotificationService.instance.init();

  final state = AppState(settings: settings);

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state..init(),
      child: const BijliBachaoApp(),
    ),
  );
}
