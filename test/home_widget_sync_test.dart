import 'package:bijli_bachao/data/models/tariff.dart';
import 'package:bijli_bachao/services/home_widget_sync.dart';
import 'package:bijli_bachao/services/usage_forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CycleSummary summary({UsageStatus status = UsageStatus.warn}) => CycleSummary(
        cycleStart: DateTime(2026, 10, 9),
        cycleEnd: DateTime(2026, 11, 9),
        today: DateTime(2026, 10, 22),
        consumerClass: ConsumerClass.unprotected,
        protectionReason: '',
        status: status,
        unitsUsed: 150,
        dailyRate: 11.5,
        projectedUnits: 190,
        targetLimit: 200,
        safeDailyBudget: 2.9,
      );

  test('shows units, limit, budget and days left', () {
    final v = HomeWidgetSync.values(meterLabel: 'Home · IESCO', summary: summary(), hasReading: true);
    expect(v['units'], '150');
    expect(v['of'], 'of 200 units');
    expect(v['progress'], 75);
    expect(v['status'], 'Close');
    expect(v['line'], 'Max 2.9 units a day · 18 days left');
  });

  test('asks for readings until there is data', () {
    final none = HomeWidgetSync.values(meterLabel: 'Home', summary: null, hasReading: false);
    expect(none['units'], '—');
    expect(none['line'], contains('add today'));
    final one = HomeWidgetSync.values(meterLabel: 'Home', summary: null, hasReading: true);
    expect(one['line'], contains('another reading'));
  });
}
