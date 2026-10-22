import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Small key-value settings stored on the device.
class SettingsService {
  SettingsService._(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const _kOnboardingDone = 'onboarding_done';
  static const _kActiveMeterId = 'active_meter_id';
  static const _kInstallId = 'install_id';
  static const _kAnalyticsConsent = 'analytics_consent';
  static const _kRemindersEnabled = 'reminders_enabled';
  static const _kSlabAlertsEnabled = 'slab_alerts_enabled';
  static const _kTariffOverride = 'tariff_override_json';
  static const _kLastAlertKey = 'last_slab_alert_key';
  static const _kAutoUpdateRates = 'auto_update_rates';
  static const _kSmartScanner = 'smart_scanner';
  static const _kRemoteTariff = 'remote_tariff_json';
  static const _kLastTariffCheck = 'last_tariff_check';
  static const _kLastTariffStatus = 'last_tariff_status';
  static const _kLastAutoBackup = 'last_auto_backup';
  static const _kThemeMode = 'theme_mode';
  static const _kSimpleHome = 'simple_home';
  static const _kLanguage = 'language';

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    final service = SettingsService._(prefs);
    await service._ensureInstallId();
    return service;
  }

  Future<void> _ensureInstallId() async {
    if (_prefs.getString(_kInstallId) != null) return;
    final rnd = Random.secure();
    final id = List.generate(16, (_) => rnd.nextInt(16).toRadixString(16)).join();
    await _prefs.setString(_kInstallId, id);
  }

  /// Random anonymous ID used to separate users in the Power BI export.
  String get installId => _prefs.getString(_kInstallId) ?? 'unknown';

  bool get onboardingDone => _prefs.getBool(_kOnboardingDone) ?? false;
  Future<void> setOnboardingDone(bool v) => _prefs.setBool(_kOnboardingDone, v);

  int? get activeMeterId => _prefs.getInt(_kActiveMeterId);
  Future<void> setActiveMeterId(int? id) =>
      id == null ? _prefs.remove(_kActiveMeterId) : _prefs.setInt(_kActiveMeterId, id);

  bool get analyticsConsent => _prefs.getBool(_kAnalyticsConsent) ?? false;
  Future<void> setAnalyticsConsent(bool v) => _prefs.setBool(_kAnalyticsConsent, v);

  bool get remindersEnabled => _prefs.getBool(_kRemindersEnabled) ?? true;
  Future<void> setRemindersEnabled(bool v) => _prefs.setBool(_kRemindersEnabled, v);

  bool get slabAlertsEnabled => _prefs.getBool(_kSlabAlertsEnabled) ?? true;
  Future<void> setSlabAlertsEnabled(bool v) => _prefs.setBool(_kSlabAlertsEnabled, v);

  String? get tariffOverrideJson => _prefs.getString(_kTariffOverride);
  Future<void> setTariffOverrideJson(String? json) => json == null
      ? _prefs.remove(_kTariffOverride)
      : _prefs.setString(_kTariffOverride, json);

  /// Prevents sending the same slab notification again in the same cycle.
  String? get lastSlabAlertKey => _prefs.getString(_kLastAlertKey);
  Future<void> setLastSlabAlertKey(String key) => _prefs.setString(_kLastAlertKey, key);

  /// Download new rates automatically (default on). When off, the user can
  /// edit rates by hand.
  bool get autoUpdateRates => _prefs.getBool(_kAutoUpdateRates) ?? true;
  Future<void> setAutoUpdateRates(bool v) => _prefs.setBool(_kAutoUpdateRates, v);

  /// Use Google's document scanner (edge detection, auto-capture, flash).
  bool get smartScanner => _prefs.getBool(_kSmartScanner) ?? true;
  Future<void> setSmartScanner(bool v) => _prefs.setBool(_kSmartScanner, v);

  /// Home shows just the essentials (default) or the full dashboard.
  bool get simpleHome => _prefs.getBool(_kSimpleHome) ?? true;
  Future<void> setSimpleHome(bool v) => _prefs.setBool(_kSimpleHome, v);

  /// 'en' (default) or 'ur'.
  String get language => _prefs.getString(_kLanguage) ?? 'en';
  Future<void> setLanguage(String v) => _prefs.setString(_kLanguage, v);

  /// 'system' (default), 'light' or 'dark'.
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  Future<void> setThemeMode(String v) => _prefs.setString(_kThemeMode, v);

  String? get remoteTariffJson => _prefs.getString(_kRemoteTariff);
  Future<void> setRemoteTariffJson(String json) => _prefs.setString(_kRemoteTariff, json);

  DateTime? get lastTariffCheck {
    final ms = _prefs.getInt(_kLastTariffCheck);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastTariffCheck(DateTime t) =>
      _prefs.setInt(_kLastTariffCheck, t.millisecondsSinceEpoch);

  String? get lastTariffStatus => _prefs.getString(_kLastTariffStatus);
  Future<void> setLastTariffStatus(String s) => _prefs.setString(_kLastTariffStatus, s);

  /// Per-type reminder switches (keys from ReminderType.settingKey). On by default.
  bool flag(String key, {bool fallback = true}) => _prefs.getBool(key) ?? fallback;
  Future<void> setFlag(String key, bool v) => _prefs.setBool(key, v);

  DateTime? get lastAutoBackup {
    final ms = _prefs.getInt(_kLastAutoBackup);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastAutoBackup(DateTime t) => _prefs.setInt(_kLastAutoBackup, t.millisecondsSinceEpoch);

  /// Values of [keys] that are set (for backups).
  Map<String, Object?> exportValues(Set<String> keys) => {
        for (final k in keys)
          if (_prefs.containsKey(k)) k: _prefs.get(k),
      };

  /// Writes backed-up values; unknown types are skipped.
  Future<void> importValues(Map<String, Object?> values) async {
    for (final e in values.entries) {
      final v = e.value;
      if (v is bool) {
        await _prefs.setBool(e.key, v);
      } else if (v is int) {
        await _prefs.setInt(e.key, v);
      } else if (v is String) {
        await _prefs.setString(e.key, v);
      }
    }
  }

  /// Clears everything except the install ID.
  Future<void> resetAll() async {
    final id = installId;
    final remote = remoteTariffJson;
    await _prefs.clear();
    await _prefs.setString(_kInstallId, id);
    // Downloaded rates aren't personal data — keep them.
    if (remote != null) await _prefs.setString(_kRemoteTariff, remote);
  }
}
