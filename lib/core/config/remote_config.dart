/// Where the app downloads the latest tariff from.
///
/// Set this ONCE to the raw URL of `tariff_pk.json` in your public GitHub
/// repo (see docs/AUTO_UPDATE_RATES.md). After that, updating rates means
/// editing that JSON file on GitHub — every installed app picks it up within
/// a day, no new app release needed.
///
/// You can also override it at build time:
///   flutter build apk --dart-define=TARIFF_URL=https://.../tariff_pk.json
class RemoteConfig {
  RemoteConfig._();

  static const String _placeholder = 'YOUR_GITHUB_USERNAME';

  /// Public repo holding the rates file (rates_repo/ in this project).
  static const String _owner = 'Saad43165';

  static const String tariffUrl = String.fromEnvironment(
    'TARIFF_URL',
    defaultValue:
        'https://raw.githubusercontent.com/$_owner/bijli-hisaab-rates/main/tariff_pk.json',
  );

  /// How often the app checks for new rates on its own.
  static const Duration checkInterval = Duration(hours: 12);

  static const Duration timeout = Duration(seconds: 12);

  static bool get isConfigured =>
      tariffUrl.startsWith('https://') && !tariffUrl.contains(_placeholder);
}
