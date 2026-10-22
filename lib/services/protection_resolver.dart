import '../data/models/bill.dart';
import '../data/models/meter.dart';
import '../data/models/tariff.dart';
import '../core/l10n/l10n.dart';

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
          return ProtectionStatus(
            consumerClass: ConsumerClass.protected,
            reason: 'Lifeline needs a single-phase meter with load up to 1 kW — using protected rates'.tr,
          );
        }
        return ProtectionStatus(
          consumerClass: ConsumerClass.lifeline,
          reason: 'Set as lifeline in meter settings'.tr,
        );
      case ProtectedSetting.protected:
        return ProtectionStatus(
          consumerClass: ConsumerClass.protected,
          reason: 'Set as protected in meter settings'.tr,
        );
      case ProtectedSetting.unprotected:
        return ProtectionStatus(
          consumerClass: ConsumerClass.unprotected,
          reason: 'Set as not protected in meter settings'.tr,
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
        reason: 'A bill in the last {0} months was above {1} units'.trf({'0': months, '1': limit}),
      );
    }
    if (recent.length < months) {
      return ProtectionStatus(
        consumerClass: ConsumerClass.unprotected,
        reason: 'Needs {0} months of bills to confirm (have {1}). Add past bills or set the status in meter settings.'.trf({'0': months, '1': recent.length}),
      );
    }
    return ProtectionStatus(
      consumerClass: ConsumerClass.protected,
      reason: 'Last {0} bills were all {1} units or less'.trf({'0': months, '1': limit}),
    );
  }
}
