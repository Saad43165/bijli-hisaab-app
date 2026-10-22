import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/utils/formatters.dart';
import 'usage_forecaster.dart';

/// Writes this month's numbers for the Android home-screen widget
/// (android/.../UsageWidgetProvider.kt) and asks it to redraw.
class HomeWidgetSync {
  HomeWidgetSync._();

  static const androidName = 'UsageWidgetProvider';

  /// What was last sent to the widget.
  static String? _last;

  /// What the widget shows for [summary]. Pure, so it's unit-tested.
  @visibleForTesting
  static Map<String, Object> values({
    required String meterLabel,
    required CycleSummary? summary,
    required bool hasReading,
  }) {
    final s = summary;
    if (s == null || !s.hasData) {
      return {
        'meter': meterLabel,
        'units': '—',
        'of': 'units this month',
        'progress': 0,
        'status': '',
        'statusColor': '#F5B700',
        'line': hasReading ? 'Add another reading to see this month' : 'Tap to add today\'s reading',
      };
    }
    final days = '${s.daysLeft} ${s.daysLeft == 1 ? 'day' : 'days'} left';
    final target = s.targetLimit;
    final budget = s.safeDailyBudget;
    final String line;
    if (s.isTou || target == null) {
      line = '~${Fmt.whole(s.projectedUnits)} by month end · $days';
    } else if (budget != null) {
      line = 'Max ${Fmt.oneDp(budget)} units a day · $days';
    } else {
      line = days;
    }
    final (String status, String color) = switch (s.status) {
      UsageStatus.safe => ('On track', '#34C38F'),
      UsageStatus.warn => ('Close', '#F5A524'),
      UsageStatus.danger => ('Will cross', '#F06565'),
      UsageStatus.overLimits => ('Highest slab', '#F06565'),
      UsageStatus.noData => ('', '#F5B700'),
    };
    return {
      'meter': meterLabel,
      'units': Fmt.whole(s.unitsUsed),
      'of': target == null ? 'units this month' : 'of $target units',
      'progress': (s.progress * 100).round(),
      'status': s.isTou ? 'TOU' : status,
      'statusColor': color,
      'line': line,
    };
  }

  static Future<void> push({
    required String meterLabel,
    required CycleSummary? summary,
    required bool hasReading,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final v = values(meterLabel: meterLabel, summary: summary, hasReading: hasReading);
    // Recomputes happen often; only talk to the launcher when numbers change.
    final key = v.toString();
    if (key == _last) return;
    _last = key;
    try {
      for (final e in v.entries) {
        await HomeWidget.saveWidgetData(e.key, e.value);
      }
      await HomeWidget.updateWidget(androidName: androidName);
    } catch (e) {
      // No widget placed yet, or the plugin isn't available (tests).
      debugPrint('Home widget update skipped: $e');
    }
  }

  /// Asks the launcher to add the widget (Android 8+, supported launchers).
  static Future<bool> requestPin() async {
    try {
      await HomeWidget.requestPinWidget(androidName: androidName);
      return true;
    } catch (_) {
      return false;
    }
  }
}
