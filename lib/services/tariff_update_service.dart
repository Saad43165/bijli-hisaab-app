import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config/remote_config.dart';
import '../data/models/tariff.dart';
import 'settings_service.dart';
import '../core/l10n/l10n.dart';

enum TariffCheckStatus { updated, upToDate, skipped, notConfigured, failed }

class TariffCheckResult {
  const TariffCheckResult(this.status, {this.tariff, this.message});

  final TariffCheckStatus status;

  /// The newly downloaded tariff when [status] is [TariffCheckStatus.updated].
  final Tariff? tariff;
  final String? message;
}

/// Downloads the published tariff JSON, validates it and caches it on the
/// phone. The app keeps whichever tariff (bundled or downloaded) has the
/// highest `version`, so a bad or old file never replaces good rates.
class TariffUpdateService {
  TariffUpdateService(this._settings, {http.Client? client}) : _client = client ?? http.Client();

  final SettingsService _settings;
  final http.Client _client;

  /// The cached downloaded tariff, if any and still valid.
  Tariff? cached() {
    final raw = _settings.remoteTariffJson;
    if (raw == null) return null;
    try {
      final t = Tariff.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return TariffValidator.validate(t) == null ? t : null;
    } catch (_) {
      return null;
    }
  }

  Future<TariffCheckResult> check({required int currentVersion, bool force = false}) async {
    if (!RemoteConfig.isConfigured) {
      return TariffCheckResult(TariffCheckStatus.notConfigured,
          message: 'Online rates are not set up yet'.tr);
    }
    final last = _settings.lastTariffCheck;
    if (!force && last != null && DateTime.now().difference(last) < RemoteConfig.checkInterval) {
      return const TariffCheckResult(TariffCheckStatus.skipped);
    }

    try {
      final uri = Uri.parse(RemoteConfig.tariffUrl)
          .replace(queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()});
      final res = await _client
          .get(uri, headers: const {'Cache-Control': 'no-cache', 'Accept': 'application/json'})
          .timeout(RemoteConfig.timeout);
      await _settings.setLastTariffCheck(DateTime.now());

      if (res.statusCode == 404) {
        return await _fail('Online rates aren\'t published yet — using built-in rates'.tr);
      }
      if (res.statusCode != 200) {
        return await _fail('Server returned {0}'.trf({'0': res.statusCode}));
      }
      final tariff = Tariff.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
      final problem = TariffValidator.validate(tariff);
      if (problem != null) return await _fail('Published rates rejected: {0}'.trf({'0': problem}));

      if (tariff.version <= currentVersion) {
        await _settings.setLastTariffStatus('Up to date'.tr);
        return const TariffCheckResult(TariffCheckStatus.upToDate);
      }
      await _settings.setRemoteTariffJson(jsonEncode(tariff.toJson()));
      await _settings.setLastTariffStatus('Updated to {0}'.trf({'0': tariff.updatedAt}));
      return TariffCheckResult(TariffCheckStatus.updated, tariff: tariff);
    } on TimeoutException {
      return _fail('No response — check your internet'.tr);
    } catch (e) {
      debugPrint('Tariff check failed: $e');
      return _fail('Could not check for new rates'.tr);
    }
  }

  Future<TariffCheckResult> _fail(String message) async {
    await _settings.setLastTariffStatus(message);
    return TariffCheckResult(TariffCheckStatus.failed, message: message);
  }
}
