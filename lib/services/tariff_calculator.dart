import '../data/models/tariff.dart';

/// Line-by-line bill estimate.
class BillEstimate {
  const BillEstimate({
    required this.units,
    required this.appliedClass,
    required this.slab,
    required this.energy,
    required this.fixed,
    required this.fcSurcharge,
    required this.fca,
    required this.qta,
    required this.electricityDuty,
    required this.gst,
    required this.tvFee,
    this.peakUnits,
    this.exportUnits = 0,
    this.exportCredit = 0,
  });

  final int units;

  /// The category actually used (a protected user above 200 → unprotected).
  final ConsumerClass appliedClass;
  final Slab slab;
  final double energy;
  final double fixed;
  final double fcSurcharge;
  final double fca;
  final double qta;
  final double electricityDuty;
  final double gst;
  final double tvFee;

  /// TOU bills: units in peak hours (off-peak = [units] − this). Null for
  /// slab bills.
  final int? peakUnits;

  /// Solar: units sent to the grid, and what they're worth (taken off the bill).
  final int exportUnits;
  final double exportCredit;

  bool get isTou => peakUnits != null;
  int get offPeakUnits => units - (peakUnits ?? 0);

  /// 'TOU' for time-of-use bills, otherwise the slab, e.g. '201–300'.
  String get slabLabel => isTou ? 'TOU' : slab.label;

  /// Charges before any solar credit.
  double get charges => energy + fixed + fcSurcharge + fca + qta + electricityDuty + gst + tvFee;

  /// What you pay; negative means the grid owes you.
  double get total => charges - exportCredit;

  BillEstimate withExport(int units, double credit) => BillEstimate(
        units: this.units,
        appliedClass: appliedClass,
        slab: slab,
        energy: energy,
        fixed: fixed,
        fcSurcharge: fcSurcharge,
        fca: fca,
        qta: qta,
        electricityDuty: electricityDuty,
        gst: gst,
        tvFee: tvFee,
        peakUnits: peakUnits,
        exportUnits: units,
        exportCredit: credit,
      );

  /// Average cost of one unit including everything.
  double get effectiveRate => units == 0 ? 0 : total / units;

  static const BillEstimate zero = BillEstimate(
    units: 0,
    appliedClass: ConsumerClass.unprotected,
    slab: Slab(from: 1, to: 100, rate: 0),
    energy: 0,
    fixed: 0,
    fcSurcharge: 0,
    fca: 0,
    qta: 0,
    electricityDuty: 0,
    gst: 0,
    tvFee: 0,
  );
}

/// Pure tariff maths (no Flutter imports, unit-tested in test/).
class TariffCalculator {
  const TariffCalculator(this.tariff);

  final Tariff tariff;

  int get _lifelineMax => tariff.lifelineCategory?.limits.lastOrNull ?? 100;

  /// Category actually used for [units] for a consumer of class [c].
  ConsumerClass appliedClass(int units, ConsumerClass c) {
    if (c == ConsumerClass.lifeline && tariff.lifelineCategory != null && units <= _lifelineMax) {
      return ConsumerClass.lifeline;
    }
    if (c.hasProtection && units <= tariff.protectedThresholdUnits) {
      return ConsumerClass.protected;
    }
    return ConsumerClass.unprotected;
  }

  BillEstimate estimate(
    int units, {
    required ConsumerClass consumerClass,
    required double sanctionedLoadKw,
    required String province,
  }) {
    if (units <= 0) return BillEstimate.zero;

    final applied = appliedClass(units, consumerClass);
    final cat = tariff.categoryOf(applied);
    final slab = cat.slabs[cat.indexFor(units)];

    final energy = energyCharge(units, cat);
    final load = sanctionedLoadKw < 0 ? 0.0 : sanctionedLoadKw;
    final fixed = slab.fixedPerKw * load;
    final fc = cat.fcSurchargePerUnit * units;
    final fca = cat.appliesAdjustments ? tariff.fcaPerUnit * units : 0.0;
    final qta = cat.appliesAdjustments ? tariff.qtaPerUnit * units : 0.0;
    final ed = energy * tariff.dutyFor(province) / 100;
    final gst = (energy + fixed + fc + fca + qta) * tariff.gstPercent / 100;

    return BillEstimate(
      units: units,
      appliedClass: applied,
      slab: slab,
      energy: energy,
      fixed: fixed,
      fcSurcharge: fc,
      fca: fca,
      qta: qta,
      electricityDuty: ed,
      gst: gst < 0 ? 0 : gst,
      tvFee: tariff.tvFee,
    );
  }

  /// Time-of-use bill: no slabs, [peakUnits] at the peak rate and the rest
  /// off-peak; the fixed charge is on part of the sanctioned load.
  BillEstimate estimateTou(
    int units, {
    required int peakUnits,
    required double sanctionedLoadKw,
    required String province,
  }) {
    if (units <= 0) return BillEstimate.zero;
    final peak = peakUnits.clamp(0, units);
    final r = tariff.tou;
    final cat = tariff.unprotectedCategory;
    final energy = peak * r.peakRate + (units - peak) * r.offPeakRate;
    final load = sanctionedLoadKw < 0 ? 0.0 : sanctionedLoadKw;
    final fixed = r.fixedPerKw * load * r.fixedLoadShare;
    final fc = cat.fcSurchargePerUnit * units;
    final fca = tariff.fcaPerUnit * units;
    final qta = tariff.qtaPerUnit * units;
    final ed = energy * tariff.dutyFor(province) / 100;
    final gst = (energy + fixed + fc + fca + qta) * tariff.gstPercent / 100;
    return BillEstimate(
      units: units,
      appliedClass: ConsumerClass.unprotected,
      slab: Slab(from: 1, to: null, rate: units == 0 ? 0 : energy / units),
      energy: energy,
      fixed: fixed,
      fcSurcharge: fc,
      fca: fca,
      qta: qta,
      electricityDuty: ed,
      gst: gst < 0 ? 0 : gst,
      tvFee: tariff.tvFee,
      peakUnits: peak,
    );
  }

  /// Energy charge only, following the category's billing mode.
  static double energyCharge(int units, TariffCategory cat) {
    if (units <= 0 || cat.slabs.isEmpty) return 0;
    final idx = cat.indexFor(units);
    final slab = cat.slabs[idx];

    switch (cat.billingMode) {
      case BillingMode.whole:
        return units * slab.rate;

      case BillingMode.previousSlab:
        if (idx == 0) return units * slab.rate;
        final prev = cat.slabs[idx - 1];
        final prevUnits = prev.width;
        final rest = units - prevUnits;
        if (prevUnits <= 0 || rest < 0) return units * slab.rate;
        return prevUnits * prev.rate + rest * slab.rate;

      case BillingMode.incremental:
        var remaining = units;
        var total = 0.0;
        for (final s in cat.slabs) {
          if (remaining <= 0) break;
          final take = s.to == null ? remaining : (remaining < s.width ? remaining : s.width);
          total += take * s.rate;
          remaining -= take;
        }
        return total;
    }
  }

  /// Rate the next unit would cost (used for appliance costs).
  double marginalRate(int units, {required ConsumerClass consumerClass}) {
    final u = units <= 0 ? 1 : units;
    final cat = tariff.categoryOf(appliedClass(u, consumerClass));
    return cat.slabs[cat.indexFor(u)].rate;
  }

  /// Slab limits that matter for warnings, ascending.
  List<int> limitsFor(ConsumerClass c) {
    final threshold = tariff.protectedThresholdUnits;
    final unprotected = tariff.unprotectedCategory.limits;
    if (c == ConsumerClass.unprotected) return unprotected;

    final floor = c == ConsumerClass.lifeline && tariff.lifelineCategory != null ? _lifelineMax : 0;
    final set = <int>{
      if (c == ConsumerClass.lifeline) ...?tariff.lifelineCategory?.limits,
      ...tariff.protectedCategory.limits.where((l) => l > floor && l <= threshold),
      ...unprotected.where((l) => l > threshold),
    };
    return set.toList()..sort();
  }
}
