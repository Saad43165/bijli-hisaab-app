import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants/app_constants.dart';
import '../../services/settings_service.dart';
import '../../services/tariff_update_service.dart';
import '../models/tariff.dart';

enum TariffOrigin {
  bundled('Built into the app'),
  online('Downloaded'),
  custom('Edited by you');

  const TariffOrigin(this.label);
  final String label;
}

class ActiveTariff {
  const ActiveTariff(this.tariff, this.origin);

  final Tariff tariff;
  final TariffOrigin origin;
}

/// Picks the tariff the app uses:
/// - auto-update on  → newest of (bundled, downloaded) by `version`
/// - auto-update off → the user's edited copy, or the newest one if none
class TariffRepository {
  TariffRepository(this._settings, this._updates);

  final SettingsService _settings;
  final TariffUpdateService _updates;

  Tariff? _bundled;

  Future<Tariff> loadDefault() async {
    if (_bundled != null) return _bundled!;
    final raw = await rootBundle.loadString(AppConstants.tariffAsset);
    return _bundled = Tariff.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<ActiveTariff> load() async {
    final bundled = await loadDefault();
    final remote = _updates.cached();
    final newest = (remote != null && remote.version > bundled.version)
        ? ActiveTariff(remote, TariffOrigin.online)
        : ActiveTariff(bundled, TariffOrigin.bundled);

    if (!_settings.autoUpdateRates) {
      final custom = _custom();
      if (custom != null) return ActiveTariff(custom, TariffOrigin.custom);
    }
    return newest;
  }

  Tariff? _custom() {
    final raw = _settings.tariffOverrideJson;
    if (raw == null) return null;
    try {
      final t = Tariff.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return TariffValidator.validate(t) == null ? t : null;
    } catch (_) {
      return null;
    }
  }

  /// Saves the user's own rates (only used while auto-update is off).
  Future<void> saveCustom(Tariff tariff) =>
      _settings.setTariffOverrideJson(jsonEncode(tariff.toJson()));

  Future<void> clearCustom() => _settings.setTariffOverrideJson(null);
}
