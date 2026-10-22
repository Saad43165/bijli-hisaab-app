import '../data/models/bill.dart';
import '../data/models/meter.dart';
import '../data/models/tariff.dart';

class ProtectionStatus {
  const ProtectionStatus({required this.consumerClass, required this.reason});

  final ConsumerClass consumerClass;
  final String reason;

  bool get isProtected => consumerClass.hasProtection;
}

/// Decides which rate category a meter is billed under.
class ProtectionResolver {
  ProtectionResolver._();

  /// [bills] in any order.
  static ProtectionStatus resolve(Meter meter, List<Bill> bills, Tariff tariff) {
    switch (meter.protectedSetting) {
      case ProtectedSetting.lifeline:
        if (meter.phase != 'single' || meter.sanctionedLoadKw > 1) {
          return const ProtectionStatus(
            consumerClass: ConsumerClass.protected,
            reason: 'Lifeline needs a single-phase meter with load up to 1 kW — using protected rates',
          );
        }
        return const ProtectionStatus(
          consumerClass: ConsumerClass.lifeline,
          reason: 'Set as lifeline in meter settings',
        );
      case ProtectedSetting.protected:
        return const ProtectionStatus(
          consumerClass: ConsumerClass.protected,
          reason: 'Set as protected in meter settings',
        );
      case ProtectedSetting.unprotected:
        return const ProtectionStatus(
          consumerClass: ConsumerClass.unprotected,
          reason: 'Set as not protected in meter settings',
        );
      case ProtectedSetting.auto:
        break;
    }

    final months = tariff.protectedMonths;
    final limit = tariff.protectedThresholdUnits;
    final sorted = [...bills]..sort((a, b) => b.month.compareTo(a.month));
    final recent = sorted.take(months).toList();

    if (recent.any((b) => b.units > limit)) {
      return ProtectionStatus(
        consumerClass: ConsumerClass.unprotected,
        reason: 'A bill in the last $months months was above $limit units',
      );
    }
    if (recent.length < months) {
      return ProtectionStatus(
        consumerClass: ConsumerClass.unprotected,
        reason: 'Needs $months months of bills to confirm (have ${recent.length}). '
            'Add past bills or set the status in meter settings.',
      );
    }
    return ProtectionStatus(
      consumerClass: ConsumerClass.protected,
      reason: 'Last $months bills were all $limit units or less',
    );
  }
}
