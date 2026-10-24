import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/utils/formatters.dart';
import 'usage_forecaster.dart';
import '../core/l10n/l10n.dart';

/// Writes this month's numbers for the Android home-screen widget
/// (android/.../UsageWidgetProvider.kt) and asks it to redraw.
class HomeWidgetSync {
  HomeWidgetSync._();

  static const androidName = 'UsageWidgetProvider';

  /// The small 2×1 widget: units and status only.
  static const smallAndroidName = 'UsageWidgetSmallProvider';

  /// "Bill this month" and "Daily budget".
  static const billAndroidName = 'BillWidgetProvider';
  static const budgetAndroidName = 'BudgetWidgetProvider';

  static const _all = [androidName, smallAndroidName, billAndroidName, budgetAndroidName];

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
    final common = <String, Object>{
      'billTitle': 'Bill this month'.tr,
      'budgetTitle': 'Daily budget'.tr,
      'addReading': '+ ${'Add reading'.tr}',
      'daysFmt': '{0} {1} left'.trf({'0': '{0}', '1': 'days'.tr}),
      'dayFmt': '{0} {1} left'.trf({'0': '{0}', '1': 'day'.tr}),
    };
    if (s == null || !s.hasData) {
      final hint = hasReading ? 'Add another reading to see this month'.tr : 'Tap to add today\'s reading'.tr;
      return {
        ...common,
        'meter': meterLabel,
        'units': '—',
        'of': 'units this month'.tr,
        'progress': 0,
        'status': '',
        'statusColor': '#F5B700',
        'line': hint,
        'bill': '—',
        'billUnits': hint,
        'billUnitsShort': '',
        'billLine': '',
        'cycleEnd': '',
        'budget': '—',
        'budgetOf': hint,
        'budgetLine': '',
        'budgetProgress': 0,
        'budgetColor': '#F5B700',
      };
    }
    final days = '{0} {1} left'.trf({'0': s.daysLeft, '1': s.daysLeft == 1 ? 'day'.tr : 'days'.tr});
    final target = s.targetLimit;
    final budget = s.safeDailyBudget;
    final String line;
    if (s.isTou || target == null) {
      line = '~{0} by month end · {1}'.trf({'0': Fmt.whole(s.projectedUnits), '1': days});
    } else if (budget != null) {
      line = 'Max {0} units a day · {1}'.trf({'0': Fmt.oneDp(budget), '1': days});
    } else {
      line = days;
    }
    final (String status, String color) = switch (s.status) {
      UsageStatus.safe => ('On track'.tr, '#34C38F'),
      UsageStatus.warn => ('Close'.tr, '#F5A524'),
      UsageStatus.danger => ('Will cross'.tr, '#F06565'),
      UsageStatus.overLimits => ('Highest slab'.tr, '#F06565'),
      UsageStatus.noData => ('', '#F5B700'),
    };
    final used = Fmt.whole(s.unitsUsed);
    final slab = s.isTou ? 'TOU' : s.estimateProjected.slabLabel;
    final rate = s.dailyRate;
    final (String budgetLine, String budgetColor, int budgetProgress) = budget == null || target == null
        ? ('Recently {0} a day'.trf({'0': Fmt.oneDp(rate)}), color, 0)
        : rate <= budget
            ? ('Recently {0} a day · on track'.trf({'0': Fmt.oneDp(rate)}), '#34C38F', (rate / budget * 100).round())
            : (
                'Recently {0} a day · cut {1}'.trf({'0': Fmt.oneDp(rate), '1': Fmt.oneDp(rate - budget)}),
                '#F06565',
                100,
              );
    return {
      ...common,
      'bill': Fmt.rs(s.estimateProjected.total),
      'billUnits': target == null
          ? '{0} units · slab {1}'.trf({'0': used, '1': slab})
          : '{0} of {1} units · slab {2}'.trf({'0': used, '1': target, '2': slab}),
      'billUnitsShort': '{0} units'.trf({'0': used}),
      'billLine': 'heading for {0} units'.trf({'0': Fmt.whole(s.projectedUnits)}),
      'cycleEnd': Fmt.isoDate(s.cycleEnd),
      'budget': budget == null ? '—' : Fmt.oneDp(budget),
      'budgetOf': budget == null || target == null
          ? (target == null ? 'No cheaper slab left this month'.tr : 'Over the limit this month'.tr)
          : 'units a day to stay under {0}'.trf({'0': target}),
      'budgetLine': budgetLine,
      'budgetColor': budgetColor,
      'budgetProgress': budgetProgress.clamp(0, 100),
      'meter': meterLabel,
      'units': used,
      'of': target == null ? 'units this month'.tr : 'of {0} units'.trf({'0': target}),
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
      for (final name in _all) {
        await HomeWidget.updateWidget(androidName: name);
      }
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
