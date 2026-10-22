import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import '../core/constants/companies.dart';
import '../core/l10n/l10n.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/formatters.dart';
import '../data/db/app_database.dart';
import '../data/models/app_event.dart';
import '../data/models/appliance.dart';
import '../data/models/bill.dart';
import '../data/models/meter.dart';
import '../data/models/meter_reading.dart';
import '../data/models/tariff.dart';
import '../data/repositories/appliance_repository.dart';
import '../data/repositories/bill_repository.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/meter_repository.dart';
import '../data/repositories/reading_repository.dart';
import '../data/repositories/tariff_repository.dart';
import '../services/backup/backup_data.dart';
import '../services/backup/backup_service.dart';
import '../services/backup/restore_plan.dart';
import '../services/export_service.dart';
import '../services/home_widget_sync.dart';
import '../services/notification_service.dart';
import '../services/protection_resolver.dart';
import '../services/reminders/reminder_planner.dart';
import '../services/settings_service.dart';
import '../services/tariff_update_service.dart';
import '../services/tariff_calculator.dart';
import '../services/usage_forecaster.dart';

/// Single source of truth for the UI. Screens read from it and call its
/// methods; they never talk to repositories directly.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({
    required SettingsService settings,
    MeterRepository? meters,
    ReadingRepository? readings,
    BillRepository? bills,
    ApplianceRepository? appliances,
    EventRepository? events,
    NotificationService? notifications,
  })  : _settings = settings,
        _meterRepo = meters ?? MeterRepository(),
        _readingRepo = readings ?? ReadingRepository(),
        _billRepo = bills ?? BillRepository(),
        _applianceRepo = appliances ?? ApplianceRepository(),
        _eventRepo = events ?? EventRepository(),
        _notifications = notifications ?? NotificationService.instance,
        _updates = TariffUpdateService(settings),
        _backups = BackupService(settings) {
    _tariffRepo = TariffRepository(settings, _updates);
  }

  final SettingsService _settings;
  final MeterRepository _meterRepo;
  final ReadingRepository _readingRepo;
  final BillRepository _billRepo;
  final ApplianceRepository _applianceRepo;
  final EventRepository _eventRepo;
  final NotificationService _notifications;
  final TariffUpdateService _updates;
  final BackupService _backups;
  late final TariffRepository _tariffRepo;
  bool _observing = false;

  bool _loading = true;
  String? _error;
  Tariff? _tariff;
  TariffOrigin _tariffOrigin = TariffOrigin.bundled;
  bool _checkingRates = false;
  String? _ratesNotice;
  List<Meter> _meters = const [];
  Meter? _activeMeter;
  List<MeterReading> _readings = const [];
  List<Bill> _bills = const [];
  List<Appliance> _appliances = const [];
  CycleSummary? _summary;
  ProtectionStatus? _protection;

  // ---------------------------------------------------------------- getters

  bool get loading => _loading;
  String? get error => _error;
  bool get onboardingDone => _settings.onboardingDone && _meters.isNotEmpty;
  Tariff get tariff => _tariff!;
  bool get hasTariff => _tariff != null;
  TariffOrigin get tariffOrigin => _tariffOrigin;
  bool get autoUpdateRates => _settings.autoUpdateRates;
  bool get checkingRates => _checkingRates;
  DateTime? get lastRatesCheck => _settings.lastTariffCheck;
  String? get lastRatesStatus => _settings.lastTariffStatus;

  /// One-time message after new rates were downloaded (shown as a banner).
  String? get ratesNotice => _ratesNotice;
  /// The tariff as it applies to the active meter's company.
  Tariff get effectiveTariff => tariff.forCompany(_activeMeter?.disco ?? '');
  TariffCalculator get calculator => TariffCalculator(effectiveTariff);

  /// The active meter's electricity company.
  PowerCompany get company => PowerCompanies.of(_activeMeter?.disco ?? 'LESCO');

  List<Meter> get meters => _meters;
  Meter? get activeMeter => _activeMeter;

  /// Readings of the active meter, oldest first.
  List<MeterReading> get readings => _readings;

  /// Bills of the active meter, newest first.
  List<Bill> get bills => _bills;
  List<Appliance> get appliances => _appliances;
  CycleSummary? get summary => _summary;
  ProtectionStatus? get protection => _protection;

  String get installId => _settings.installId;
  bool get analyticsConsent => _settings.analyticsConsent;
  bool get remindersEnabled => _settings.remindersEnabled;
  bool get slabAlertsEnabled => _settings.slabAlertsEnabled;
  bool get smartScanner => _settings.smartScanner;

  bool get simpleHome => _settings.simpleHome;

  Future<void> setSimpleHome(bool v) async {
    await _settings.setSimpleHome(v);
    notifyListeners();
  }

  /// 'en' or 'ur'.
  String get language => _settings.language;

  Future<void> setLanguage(String code) async {
    await _settings.setLanguage(code);
    L10n.setLanguage(code);
    notifyListeners();
  }

  /// One-off UI flags (tour seen, tips dismissed).
  bool uiFlag(String key) => _settings.flag(key, fallback: false);

  Future<void> setUiFlag(String key, bool value) async {
    await _settings.setFlag(key, value);
    notifyListeners();
  }

  ThemeMode get themeMode => switch (_settings.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode mode) async {
    await _settings.setThemeMode(mode.name);
    notifyListeners();
  }

  Future<void> setSmartScanner(bool v) async {
    await _settings.setSmartScanner(v);
    notifyListeners();
  }

  /// Expected total bill for [units] on the active meter (scanner sanity check).
  double estimateBillFor(int units) => estimateFor(units)?.charges ?? 0;

  MeterReading? get latestReading => _readings.isEmpty ? null : _readings.last;

  /// The last reading on or before [date] (for validating new readings).
  MeterReading? readingBefore(DateTime date) {
    MeterReading? found;
    for (final r in _readings) {
      if (!DateX.dateOnly(r.date).isAfter(DateX.dateOnly(date))) found = r;
    }
    return found;
  }

  /// Bills for the last 12 months, oldest first (for the history chart).
  List<Bill> get last12Bills {
    final sorted = [..._bills]..sort((a, b) => a.month.compareTo(b.month));
    return sorted.length <= 12 ? sorted : sorted.sublist(sorted.length - 12);
  }

  double get applianceMonthlyUnits =>
      _appliances.fold(0.0, (sum, a) => sum + a.monthlyUnits);

  /// Units in a typical month: this month's projection, else the last
  /// bill, else what the appliances add up to.
  int get typicalMonthlyUnits {
    final s = _summary;
    if (s != null && s.hasData) return s.projectedUnits.round();
    if (_bills.isNotEmpty) return _bills.first.units;
    return applianceMonthlyUnits.round();
  }

  /// Full bill estimate (slab, fixed charges, taxes) for [units] on the
  /// active meter, or null before setup.
  BillEstimate? estimateFor(int units) {
    final meter = _activeMeter;
    if (meter == null || !hasTariff) return null;
    if (meter.meterType == MeterType.tou) {
      final share = _summary?.peakShare ?? UsageForecaster.defaultPeakShare;
      final u = units < 0 ? 0 : units;
      return calculator.estimateTou(
        u,
        peakUnits: (u * share).round(),
        sanctionedLoadKw: meter.sanctionedLoadKw,
        province: meter.province,
      );
    }
    return calculator.estimate(
      units < 0 ? 0 : units,
      consumerClass: _protection?.consumerClass ?? ConsumerClass.unprotected,
      sanctionedLoadKw: meter.sanctionedLoadKw,
      province: meter.province,
    );
  }

  /// Cost of one extra unit at the expected month-end usage.
  double get marginalRate {
    if (!hasTariff) return 0;
    return calculator.marginalRate(
      typicalMonthlyUnits,
      consumerClass: _protection?.consumerClass ?? ConsumerClass.unprotected,
    );
  }

  // ------------------------------------------------------------- lifecycle

  Future<void> init() async {
    _loading = true;
    _error = null;
    notifyListeners();
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    try {
      await _reloadTariff();
      _meters = await _meterRepo.getAll();
      final activeId = _settings.activeMeterId;
      _activeMeter = _meters.where((m) => m.id == activeId).firstOrNull ??
          (_meters.isEmpty ? null : _meters.first);
      await _loadActiveMeterData();
      if (onboardingDone) {
        await _log(AppEvent.appOpen);
        unawaited(_replanReminders());
        unawaited(_backups.autoBackupIfDue());
      }
    } catch (e, st) {
      debugPrint('AppState.init failed: $e\n$st');
      _error = 'Could not load your data. Please restart the app.'.tr;
    } finally {
      _loading = false;
      notifyListeners();
    }
    unawaited(checkForRateUpdates());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Checks at most every 12 hours (see RemoteConfig.checkInterval).
    if (state == AppLifecycleState.resumed) unawaited(checkForRateUpdates());
  }

  @override
  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _reloadTariff() async {
    final active = await _tariffRepo.load();
    _tariff = active.tariff;
    _tariffOrigin = active.origin;
  }

  /// Reloads data without logging an app-open event (pull to refresh).
  Future<void> refresh() async {
    _meters = await _meterRepo.getAll();
    await _loadActiveMeterData();
    notifyListeners();
  }

  Future<void> _loadActiveMeterData() async {
    final meter = _activeMeter;
    if (meter == null || meter.id == null) {
      _readings = const [];
      _bills = const [];
      _appliances = const [];
      _summary = null;
      _protection = null;
      return;
    }
    final id = meter.id!;
    final (readings, bills, appliances) = await (
      _readingRepo.forMeter(id),
      _billRepo.forMeter(id),
      _applianceRepo.forMeter(id),
    ).wait;
    _readings = readings;
    _bills = bills;
    _appliances = appliances;
    _recompute();
  }

  void _recompute() {
    _computeSummary();
    if (!_loading) unawaited(_replanReminders());
  }

  void _computeSummary() {
    final meter = _activeMeter;
    if (meter == null || _tariff == null) {
      _summary = null;
      _protection = null;
      return;
    }
    _protection = ProtectionResolver.resolve(meter, _bills, effectiveTariff);
    _summary = UsageForecaster(calculator).compute(
      meter: meter,
      readings: _readings,
      consumerClass: _protection!.consumerClass,
      protectionReason: _protection!.reason,
    );
    // Keep the home-screen widget in step with what the app shows.
    unawaited(HomeWidgetSync.push(
      meterLabel: '${meter.name} · ${PowerCompanies.of(meter.disco).shortCode}',
      summary: _summary,
      hasReading: _readings.isNotEmpty,
    ));
  }

  // ------------------------------------------------------------- onboarding

  Future<void> completeOnboarding({
    required Meter meter,
    required bool analyticsConsent,
    double? lastReading,
    DateTime? lastReadingDate,
  }) async {
    await _settings.setAnalyticsConsent(analyticsConsent);
    final saved = await addMeter(meter);
    if (lastReading != null && saved.id != null) {
      await _readingRepo.upsert(MeterReading(
        meterId: saved.id!,
        date: DateX.dateOnly(lastReadingDate ?? DateTime.now()),
        value: lastReading,
        source: 'bill',
        createdAt: DateTime.now(),
      ));
    }
    await _settings.setOnboardingDone(true);
    await _log(AppEvent.onboardingDone, meterId: saved.id);
    await _loadActiveMeterData();
    notifyListeners();

    if (remindersEnabled) {
      await _notifications.requestPermission();
    }
    await _replanReminders();
  }

  // ------------------------------------------------------------------ meters

  Future<Meter> addMeter(Meter meter) async {
    final saved = await _meterRepo.insert(meter);
    _meters = await _meterRepo.getAll();
    _activeMeter = saved;
    await _settings.setActiveMeterId(saved.id);
    await _log(AppEvent.meterAdded, meterId: saved.id, detail: 'disco=${saved.disco}');
    await _loadActiveMeterData();
    notifyListeners();
    return saved;
  }

  Future<void> updateMeter(Meter meter) async {
    await _meterRepo.update(meter);
    _meters = await _meterRepo.getAll();
    if (_activeMeter?.id == meter.id) _activeMeter = meter;
    _recompute();
    notifyListeners();
  }

  Future<void> deleteMeter(int id) async {
    await _meterRepo.delete(id);
    _meters = await _meterRepo.getAll();
    if (_activeMeter?.id == id) {
      _activeMeter = _meters.isEmpty ? null : _meters.first;
      await _settings.setActiveMeterId(_activeMeter?.id);
    }
    if (_meters.isEmpty) await _settings.setOnboardingDone(false);
    await _loadActiveMeterData();
    notifyListeners();
  }

  Future<void> setActiveMeter(int id) async {
    final m = _meters.where((m) => m.id == id).firstOrNull;
    if (m == null) return;
    _activeMeter = m;
    await _settings.setActiveMeterId(id);
    await _loadActiveMeterData();
    notifyListeners();
  }

  // ---------------------------------------------------------------- readings

  /// Saves a reading and fires a slab notification if needed.
  /// [peakValue]: TOU meters' peak register ([value] is off-peak + peak).
  /// [exportValue]: solar meters' export register ([value] is the import).
  Future<void> addReading(
    double value,
    DateTime date, {
    String source = 'manual',
    double? peakValue,
    double? exportValue,
  }) async {
    final meter = _activeMeter;
    if (meter?.id == null) return;
    await _readingRepo.upsert(MeterReading(
      meterId: meter!.id!,
      date: DateX.dateOnly(date),
      value: value,
      source: source,
      createdAt: DateTime.now(),
      peakValue: peakValue,
      exportValue: exportValue,
    ));
    await _log(AppEvent.readingAdded, meterId: meter.id, value: value);
    _readings = await _readingRepo.forMeter(meter.id!);
    _recompute();
    notifyListeners();
    await _maybeAlert();
  }

  Future<void> deleteReading(int id) async {
    final meter = _activeMeter;
    if (meter?.id == null) return;
    await _readingRepo.delete(id);
    _readings = await _readingRepo.forMeter(meter!.id!);
    _recompute();
    notifyListeners();
  }

  Future<void> _maybeAlert() async {
    final s = _summary;
    final meter = _activeMeter;
    if (s == null || meter == null || !s.hasData) return;
    if (s.status != UsageStatus.danger && s.status != UsageStatus.warn) return;

    final key = '${meter.id}-${Fmt.isoDate(s.cycleStart)}-${s.targetLimit}-${s.status.name}';
    if (_settings.lastSlabAlertKey == key) return;
    await _settings.setLastSlabAlertKey(key);
    await _log(
      AppEvent.slabWarning,
      meterId: meter.id,
      value: s.projectedUnits.roundToDouble(),
      detail: 'limit=${s.targetLimit};status=${s.status.name}',
    );

    if (!slabAlertsEnabled) return;
    final budget = s.safeDailyBudget == null ? '' : Fmt.oneDp(s.safeDailyBudget!);
    final String title;
    final String body;
    if (s.protectionAtRisk) {
      title = 'You may lose protected rates'.tr;
      body = 'At this pace you\'ll reach {0} units. Use max {1} units/day to stay at {2} or below.'.trf({'0': Fmt.whole(s.projectedUnits), '1': budget, '2': s.protectedThreshold});
    } else if (s.status == UsageStatus.danger) {
      title = 'Slab alert: {0} units'.trf({'0': s.targetLimit});
      body = 'Projected {0} units this month. Use max {1} units/day to stay under {2}.'.trf({'0': Fmt.whole(s.projectedUnits), '1': budget, '2': s.targetLimit});
    } else {
      title = 'Close to {0} units'.trf({'0': s.targetLimit});
      body = 'You\'re on track for {0} units. Keep it under {1} units/day.'.trf({'0': Fmt.whole(s.projectedUnits), '1': budget});
    }
    await _notifications.showSlabAlert(title: title, body: body);
  }

  // ------------------------------------------------------------------- bills

  /// Saves a bill. When editing and the month changed, the old row is removed.
  /// If [addReadingFromBill] and the bill has a present reading, it is also
  /// stored as a meter reading on the meter's reading day of that month.
  Future<void> saveBill(Bill bill, {Bill? original, bool addReadingFromBill = true}) async {
    final meter = _activeMeter;
    if (meter?.id == null) return;
    if (original?.id != null && original!.month != bill.month) {
      await _billRepo.delete(original.id!);
    }
    await _billRepo.upsert(bill);
    if (original == null) {
      await _log(AppEvent.billAdded,
          meterId: meter!.id, value: bill.units.toDouble(), detail: 'source=${bill.source}');
    }

    final present = bill.presentReading;
    if (addReadingFromBill && present != null) {
      final m = bill.monthDate;
      final date = DateX.clampedDay(m.year, m.month, meter!.readingDay);
      if (!date.isAfter(DateX.today())) {
        await _readingRepo.upsert(MeterReading(
          meterId: meter.id!,
          date: date,
          value: present,
          source: 'bill',
          createdAt: DateTime.now(),
        ));
      }
    }
    await _loadActiveMeterData();
    notifyListeners();
  }

  /// Quick entry of past months from the bill's history table.
  Future<void> saveHistory(Map<String, int> unitsByMonth) async {
    final meter = _activeMeter;
    if (meter?.id == null || unitsByMonth.isEmpty) return;
    final existing = {for (final b in _bills) b.month: b};
    final toSave = <Bill>[];
    unitsByMonth.forEach((month, units) {
      final old = existing[month];
      if (old != null && old.units == units) return;
      toSave.add(Bill(
        meterId: meter!.id!,
        month: month,
        units: units,
        amount: old?.amount ?? 0,
        dueDate: old?.dueDate,
        presentReading: old?.presentReading,
        source: old?.source ?? 'history',
        createdAt: old?.createdAt ?? DateTime.now(),
      ));
    });
    if (toSave.isEmpty) return;
    await _billRepo.upsertMany(toSave);
    await _log(AppEvent.billAdded,
        meterId: meter!.id, value: toSave.length.toDouble(), detail: 'source=history');
    await _loadActiveMeterData();
    notifyListeners();
  }

  Future<void> deleteBill(int id) async {
    await _billRepo.delete(id);
    await _loadActiveMeterData();
    notifyListeners();
  }

  Future<void> logBillScanned(List<String> fields) =>
      _log(AppEvent.billScanned, meterId: _activeMeter?.id, detail: fields.join('|'));

  // -------------------------------------------------------------- appliances

  Future<void> saveAppliance(Appliance a) async {
    final isNew = a.id == null;
    await _applianceRepo.save(a);
    if (isNew) {
      await _log(AppEvent.applianceAdded, meterId: a.meterId, detail: 'category=${a.category}');
    }
    _appliances = await _applianceRepo.forMeter(a.meterId);
    notifyListeners();
  }

  /// Adds several appliances at once (quick setup).
  Future<void> addAppliances(List<Appliance> list) async {
    if (list.isEmpty) return;
    for (final a in list) {
      await _applianceRepo.save(a);
      await _log(AppEvent.applianceAdded, meterId: a.meterId, detail: 'category=${a.category}');
    }
    _appliances = await _applianceRepo.forMeter(list.first.meterId);
    notifyListeners();
  }

  Future<void> deleteAppliance(Appliance a) async {
    if (a.id == null) return;
    await _applianceRepo.delete(a.id!);
    _appliances = await _applianceRepo.forMeter(a.meterId);
    notifyListeners();
  }

  // ------------------------------------------------------------------ tariff

  /// Downloads newer rates if available. Runs on app start, on resume and
  /// from "Check now". Throttled unless [force] is true.
  Future<TariffCheckResult> checkForRateUpdates({bool force = false}) async {
    if (!hasTariff || _checkingRates) {
      return const TariffCheckResult(TariffCheckStatus.skipped);
    }
    if (!autoUpdateRates && !force) {
      return const TariffCheckResult(TariffCheckStatus.skipped);
    }
    _checkingRates = true;
    notifyListeners();
    try {
      final current = (await _tariffRepo.load()).tariff.version;
      final bundled = (await _tariffRepo.loadDefault()).version;
      final result = await _updates.check(
        currentVersion: current > bundled ? current : bundled,
        force: force,
      );
      if (result.status == TariffCheckStatus.updated) {
        await _reloadTariff();
        _recompute();
        final t = result.tariff!;
        _ratesNotice = 'Rates updated ({0}) — {1}'.trf({'0': Fmt.isoLabel(t.updatedAt), '1': t.fcaLabel});
      }
      return result;
    } finally {
      _checkingRates = false;
      notifyListeners();
    }
  }

  void dismissRatesNotice() {
    _ratesNotice = null;
    notifyListeners();
  }

  Future<void> setAutoUpdateRates(bool v) async {
    await _settings.setAutoUpdateRates(v);
    await _reloadTariff();
    _recompute();
    notifyListeners();
    if (v) await checkForRateUpdates(force: true);
  }

  /// Saves hand-edited rates (auto-update must be off).
  Future<void> updateTariff(Tariff t) async {
    if (autoUpdateRates) await _settings.setAutoUpdateRates(false);
    await _tariffRepo.saveCustom(t);
    await _reloadTariff();
    _recompute();
    notifyListeners();
  }

  /// Drops hand-edited rates and goes back to the newest official ones.
  Future<void> resetTariff() async {
    await _tariffRepo.clearCustom();
    await _reloadTariff();
    _recompute();
    notifyListeners();
  }

  // ---------------------------------------------------------------- settings

  Future<void> setAnalyticsConsent(bool v) async {
    await _settings.setAnalyticsConsent(v);
    notifyListeners();
  }

  Future<void> setRemindersEnabled(bool v) async {
    await _settings.setRemindersEnabled(v);
    if (v) await _notifications.requestPermission();
    await _replanReminders();
    notifyListeners();
  }

  // -------------------------------------------------------------- reminders

  bool reminderOn(ReminderType t) => _settings.flag(t.settingKey);

  Future<void> setReminder(ReminderType t, bool v) async {
    await _settings.setFlag(t.settingKey, v);
    if (v) await _notifications.requestPermission();
    await _replanReminders();
    notifyListeners();
  }

  Set<ReminderType> get _enabledReminders =>
      remindersEnabled ? {for (final t in ReminderType.values) if (reminderOn(t)) t} : const {};

  /// What will be sent next, for the Reminders screen.
  List<PlannedReminder> get upcomingReminders =>
      onboardingDone ? const ReminderPlanner().plan(_reminderInputs()) : const [];

  ReminderInputs _reminderInputs() {
    final meter = _activeMeter;
    final dueBill = _bills
        .where((b) => b.dueDate != null)
        .fold<Bill?>(null, (best, b) => best == null || b.dueDate!.isAfter(best.dueDate!) ? b : best);
    return ReminderInputs(
      now: DateTime.now(),
      enabled: _enabledReminders,
      meterName: _meters.length > 1 ? meter?.name : null,
      companyCode: meter == null ? '' : company.shortCode,
      summary: _summary,
      lastReadingDate: latestReading?.date,
      billAmount: dueBill?.amount,
      billDueDate: dueBill?.dueDate,
      billMonth: dueBill?.month,
    );
  }

  /// Re-plans every scheduled reminder from the latest data. Called after
  /// any change to readings, bills, meters or reminder settings.
  Future<void> _replanReminders() {
    // One at a time, so quick edits can't interleave cancel/schedule calls.
    // Each run reads the latest data when it starts.
    return _replanQueue = _replanQueue.then((_) async {
      try {
        final plan = onboardingDone ? const ReminderPlanner().plan(_reminderInputs()) : const <PlannedReminder>[];
        await _notifications.scheduleReminders(plan);
      } catch (e) {
        debugPrint('Reminder planning failed: $e');
      }
    });
  }

  Future<void> _replanQueue = Future.value();

  Future<void> setSlabAlertsEnabled(bool v) async {
    await _settings.setSlabAlertsEnabled(v);
    if (v) await _notifications.requestPermission();
    notifyListeners();
  }

  // ------------------------------------------------------------------ export

  Future<ExportResult> exportForPowerBi() async {
    final service = ExportService();
    await _log(AppEvent.exportDone, meterId: _activeMeter?.id);
    final result = await service.buildCsvFiles(installId);
    await service.share(result);
    return result;
  }

  // ----------------------------------------------------------------- backup

  /// Opens the share sheet with a backup file of everything.
  Future<void> shareBackup() async {
    await _backups.shareBackup();
    await _log(AppEvent.backupSaved);
  }

  /// Parses a picked file; throws [BackupFormatException] if it's not valid.
  Future<BackupData> readBackup(String text) => _backups.readFile(text);

  Future<List<LocalBackup>> localBackups() => _backups.localBackups();

  Future<BackupData> readLocalBackup(LocalBackup b) => _backups.readLocal(b);

  /// Restores a backup and reloads everything. Also finishes onboarding
  /// when restoring on a new phone.
  Future<RestoreResult> restoreBackup(BackupData backup, RestoreMode mode) async {
    final result = await _backups.restore(backup, mode);
    _meters = await _meterRepo.getAll();
    if (_meters.isNotEmpty) await _settings.setOnboardingDone(true);
    final activeId = _settings.activeMeterId;
    _activeMeter = _meters.where((m) => m.id == activeId).firstOrNull ?? (_meters.isEmpty ? null : _meters.first);
    if (_activeMeter?.id != null) await _settings.setActiveMeterId(_activeMeter!.id);
    await _reloadTariff();
    await _loadActiveMeterData();
    await _replanReminders();
    await _log(AppEvent.backupRestored, value: result.total.toDouble(), detail: mode.name);
    notifyListeners();
    return result;
  }

  /// Wipes all data and settings; the app returns to onboarding.
  Future<void> resetApp() async {
    await _backups.copyBeforeReset();
    await AppDatabase.instance.clearAll();
    await _settings.resetAll();
    await _notifications.cancelAll();
    _meters = const [];
    _activeMeter = null;
    await _loadActiveMeterData();
    await _reloadTariff();
    notifyListeners();
  }

  // ----------------------------------------------------------------- helpers

  Future<void> _log(String type, {int? meterId, double? value, String? detail}) async {
    try {
      await _eventRepo.log(type, meterId: meterId, value: value, detail: detail);
    } catch (e) {
      debugPrint('Event log failed: $e');
    }
  }
}
