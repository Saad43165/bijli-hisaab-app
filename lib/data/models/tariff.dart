/// How energy charges are computed once units are known.
enum BillingMode {
  /// Every unit is billed at the rate of the slab the total falls in.
  whole('whole', 'All units at current slab rate'),

  /// Units of the previous slab at its rate, the rest at the current rate.
  previousSlab('previous_slab', 'Benefit of one previous slab'),

  /// Each slab's units at that slab's rate (fully incremental).
  incremental('incremental', 'Incremental (each slab at its rate)');

  const BillingMode(this.json, this.label);

  final String json;
  final String label;

  static BillingMode fromJson(String? v) =>
      BillingMode.values.firstWhere((e) => e.json == v, orElse: () => BillingMode.whole);
}

/// The rate category a bill is charged under.
enum ConsumerClass {
  lifeline('Lifeline'),
  protected('Protected'),
  unprotected('Unprotected');

  const ConsumerClass(this.label);

  final String label;

  /// Lifeline consumers also qualify for protected rates up to 200 units.
  bool get hasProtection => this != ConsumerClass.unprotected;
}

class Slab {
  const Slab({required this.from, this.to, required this.rate, this.fixedPerKw = 0});

  final int from;

  /// Inclusive upper bound; null for the open-ended last slab ("above 700").
  final int? to;

  /// Rs per unit (kWh).
  final double rate;

  /// Fixed charge Rs per kW of sanctioned load per month for this slab.
  final double fixedPerKw;

  bool contains(int units) => units >= from && (to == null || units <= to!);

  int get width => to == null ? 0 : to! - from + 1;

  String get label => to == null ? 'Above ${from - 1}' : '$from–$to';

  Slab copyWith({double? rate, double? fixedPerKw}) =>
      Slab(from: from, to: to, rate: rate ?? this.rate, fixedPerKw: fixedPerKw ?? this.fixedPerKw);

  factory Slab.fromJson(Map<String, dynamic> j) => Slab(
        from: (j['from'] as num).toInt(),
        to: (j['to'] as num?)?.toInt(),
        rate: (j['rate'] as num).toDouble(),
        fixedPerKw: (j['fixed_per_kw'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'rate': rate,
        'fixed_per_kw': fixedPerKw,
      };
}

class TariffCategory {
  const TariffCategory({
    required this.billingMode,
    required this.fcSurchargePerUnit,
    required this.slabs,
    this.appliesAdjustments = true,
  });

  final BillingMode billingMode;

  /// FC / debt servicing surcharge, Rs per unit.
  final double fcSurchargePerUnit;
  final List<Slab> slabs;

  /// Whether monthly FCA and quarterly QTA apply (not for lifeline).
  final bool appliesAdjustments;

  /// Upper limits of all closed slabs, ascending (e.g. 100, 200, ... 700).
  List<int> get limits => [
        for (final s in slabs)
          if (s.to != null) s.to!,
      ];

  /// Index of the slab that contains [units] (clamped to the last slab).
  int indexFor(int units) {
    if (units <= 0) return 0;
    for (var i = 0; i < slabs.length; i++) {
      if (slabs[i].contains(units)) return i;
    }
    return slabs.length - 1;
  }

  TariffCategory copyWith({
    BillingMode? billingMode,
    double? fcSurchargePerUnit,
    List<Slab>? slabs,
  }) =>
      TariffCategory(
        billingMode: billingMode ?? this.billingMode,
        fcSurchargePerUnit: fcSurchargePerUnit ?? this.fcSurchargePerUnit,
        slabs: slabs ?? this.slabs,
        appliesAdjustments: appliesAdjustments,
      );

  factory TariffCategory.fromJson(Map<String, dynamic> j) => TariffCategory(
        billingMode: BillingMode.fromJson(j['billing_mode'] as String?),
        fcSurchargePerUnit: (j['fc_surcharge_per_unit'] as num?)?.toDouble() ?? 0,
        appliesAdjustments: (j['applies_adjustments'] as bool?) ?? true,
        slabs: [
          for (final s in (j['slabs'] as List)) Slab.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      );

  Map<String, dynamic> toJson() => {
        'billing_mode': billingMode.json,
        'fc_surcharge_per_unit': fcSurchargePerUnit,
        'applies_adjustments': appliesAdjustments,
        'slabs': [for (final s in slabs) s.toJson()],
      };
}

class TariffSource {
  const TariffSource({required this.title, required this.url});

  final String title;
  final String url;

  factory TariffSource.fromJson(Map<String, dynamic> j) =>
      TariffSource(title: (j['title'] as String?) ?? '', url: (j['url'] as String?) ?? '');

  Map<String, dynamic> toJson() => {'title': title, 'url': url};
}

/// Time-of-use rates for homes with a sanctioned load of 5 kW and above
/// (no slabs: one rate in peak hours, one off-peak).
class TouRates {
  const TouRates({
    required this.peakRate,
    required this.offPeakRate,
    required this.fixedPerKw,
    required this.fixedLoadShare,
  });

  /// S.R.O. 279(I)/2026: Rs 46.85 peak, Rs 34.53 off-peak, fixed Rs 675 per
  /// kW on 50% of the sanctioned load.
  static const TouRates defaults =
      TouRates(peakRate: 46.85, offPeakRate: 34.53, fixedPerKw: 675, fixedLoadShare: 0.5);

  final double peakRate;
  final double offPeakRate;
  final double fixedPerKw;

  /// Part of the sanctioned load the fixed charge is billed on (0.5 = 50%).
  final double fixedLoadShare;

  factory TouRates.fromJson(Map<String, dynamic>? j) => j == null
      ? defaults
      : TouRates(
          peakRate: (j['peak_rate'] as num?)?.toDouble() ?? defaults.peakRate,
          offPeakRate: (j['off_peak_rate'] as num?)?.toDouble() ?? defaults.offPeakRate,
          fixedPerKw: (j['fixed_per_kw'] as num?)?.toDouble() ?? defaults.fixedPerKw,
          fixedLoadShare: (j['fixed_load_share'] as num?)?.toDouble() ?? defaults.fixedLoadShare,
        );

  Map<String, dynamic> toJson() => {
        'peak_rate': peakRate,
        'off_peak_rate': offPeakRate,
        'fixed_per_kw': fixedPerKw,
        'fixed_load_share': fixedLoadShare,
      };

  TouRates copyWith({double? peakRate, double? offPeakRate, double? fixedPerKw}) => TouRates(
        peakRate: peakRate ?? this.peakRate,
        offPeakRate: offPeakRate ?? this.offPeakRate,
        fixedPerKw: fixedPerKw ?? this.fixedPerKw,
        fixedLoadShare: fixedLoadShare,
      );
}

/// What exported solar units are worth.
class SolarRates {
  const SolarRates({required this.netMeteringRate, required this.netBillingRate});

  /// NEPRA, Feb 2026: existing net-metering agreements keep Rs 25.32 per
  /// surplus unit; new agreements (net billing) get Rs 8.13 per exported unit.
  static const SolarRates defaults = SolarRates(netMeteringRate: 25.32, netBillingRate: 8.13);

  /// Old agreements: paid for net surplus (exported − imported) units.
  final double netMeteringRate;

  /// New agreements (net billing): buyback rate for every exported unit.
  final double netBillingRate;

  factory SolarRates.fromJson(Map<String, dynamic>? j) => j == null
      ? defaults
      : SolarRates(
          netMeteringRate: (j['net_metering_rate'] as num?)?.toDouble() ?? defaults.netMeteringRate,
          netBillingRate: (j['net_billing_rate'] as num?)?.toDouble() ?? defaults.netBillingRate,
        );

  Map<String, dynamic> toJson() => {'net_metering_rate': netMeteringRate, 'net_billing_rate': netBillingRate};

  SolarRates copyWith({double? netMeteringRate, double? netBillingRate}) => SolarRates(
        netMeteringRate: netMeteringRate ?? this.netMeteringRate,
        netBillingRate: netBillingRate ?? this.netBillingRate,
      );
}

class Tariff {
  const Tariff({
    required this.schemaVersion,
    required this.version,
    required this.id,
    required this.name,
    required this.effectiveFrom,
    required this.updatedAt,
    required this.sourceNote,
    required this.sources,
    required this.protectedThresholdUnits,
    required this.protectedMonths,
    required this.gstPercent,
    required this.tvFee,
    required this.fcaPerUnit,
    required this.fcaLabel,
    required this.qtaPerUnit,
    required this.qtaLabel,
    required this.electricityDutyPercent,
    required this.lifelineCategory,
    required this.protectedCategory,
    required this.unprotectedCategory,
    this.companyOverrides = const {},
    this.tou = TouRates.defaults,
    this.solar = SolarRates.defaults,
  });

  /// Highest JSON schema this app understands.
  static const int supportedSchema = 2;

  final int schemaVersion;

  /// Increases with every published update (e.g. 2026102101). The app keeps
  /// whichever tariff has the highest version.
  final int version;
  final String id;
  final String name;
  final String effectiveFrom;
  final String updatedAt;
  final String sourceNote;
  final List<TariffSource> sources;
  final int protectedThresholdUnits;
  final int protectedMonths;
  final double gstPercent;
  final double tvFee;

  /// Monthly fuel charges adjustment (FCA/FPA), Rs per unit. Can be negative.
  final double fcaPerUnit;
  final String fcaLabel;

  /// Quarterly tariff adjustment, Rs per unit. Can be negative.
  final double qtaPerUnit;
  final String qtaLabel;

  /// Province -> electricity duty % of energy charges (0 since July 2025).
  final Map<String, double> electricityDutyPercent;
  final TariffCategory? lifelineCategory;
  final TariffCategory protectedCategory;
  final TariffCategory unprotectedCategory;

  /// Per-company differences, keyed by company code (e.g. "K-Electric").
  /// Supported keys: fca_per_unit, fca_label, qta_per_unit, qta_label,
  /// gst_percent, tv_fee. Empty today — the tariff is uniform since 2026.
  final Map<String, Map<String, dynamic>> companyOverrides;

  /// Peak / off-peak rates for TOU meters.
  final TouRates tou;

  /// Export rates for solar meters.
  final SolarRates solar;

  /// This tariff as it applies to one company.
  Tariff forCompany(String code) {
    final o = companyOverrides[code];
    if (o == null || o.isEmpty) return this;
    double? n(String k) => (o[k] as num?)?.toDouble();
    return copyWith(
      fcaPerUnit: n('fca_per_unit'),
      fcaLabel: o['fca_label'] as String?,
      qtaPerUnit: n('qta_per_unit'),
      qtaLabel: o['qta_label'] as String?,
      gstPercent: n('gst_percent'),
      tvFee: n('tv_fee'),
    );
  }

  double dutyFor(String province) => electricityDutyPercent[province] ?? 0;

  TariffCategory categoryOf(ConsumerClass c) => switch (c) {
        ConsumerClass.lifeline => lifelineCategory ?? protectedCategory,
        ConsumerClass.protected => protectedCategory,
        ConsumerClass.unprotected => unprotectedCategory,
      };

  Tariff copyWith({
    double? gstPercent,
    double? tvFee,
    double? fcaPerUnit,
    String? fcaLabel,
    double? qtaPerUnit,
    String? qtaLabel,
    Map<String, double>? electricityDutyPercent,
    TariffCategory? protectedCategory,
    TariffCategory? unprotectedCategory,
    TouRates? tou,
    SolarRates? solar,
  }) =>
      Tariff(
        schemaVersion: schemaVersion,
        version: version,
        id: id,
        name: name,
        effectiveFrom: effectiveFrom,
        updatedAt: updatedAt,
        sourceNote: sourceNote,
        sources: sources,
        protectedThresholdUnits: protectedThresholdUnits,
        protectedMonths: protectedMonths,
        gstPercent: gstPercent ?? this.gstPercent,
        tvFee: tvFee ?? this.tvFee,
        fcaPerUnit: fcaPerUnit ?? this.fcaPerUnit,
        fcaLabel: fcaLabel ?? this.fcaLabel,
        qtaPerUnit: qtaPerUnit ?? this.qtaPerUnit,
        qtaLabel: qtaLabel ?? this.qtaLabel,
        electricityDutyPercent: electricityDutyPercent ?? this.electricityDutyPercent,
        lifelineCategory: lifelineCategory,
        protectedCategory: protectedCategory ?? this.protectedCategory,
        unprotectedCategory: unprotectedCategory ?? this.unprotectedCategory,
        companyOverrides: companyOverrides,
        tou: tou ?? this.tou,
        solar: solar ?? this.solar,
      );

  factory Tariff.fromJson(Map<String, dynamic> j) {
    final adj = Map<String, dynamic>.from((j['adjustments'] as Map?) ?? const {});
    return Tariff(
      schemaVersion: (j['schema_version'] as num?)?.toInt() ?? 1,
      version: (j['version'] as num?)?.toInt() ?? 0,
      id: j['id'] as String,
      name: j['name'] as String,
      effectiveFrom: (j['effective_from'] as String?) ?? '',
      updatedAt: (j['updated_at'] as String?) ?? '',
      sourceNote: (j['source_note'] as String?) ?? '',
      sources: [
        for (final s in (j['sources'] as List?) ?? const [])
          TariffSource.fromJson(Map<String, dynamic>.from(s as Map)),
      ],
      protectedThresholdUnits: (j['protected_threshold_units'] as num?)?.toInt() ?? 200,
      protectedMonths: (j['protected_months'] as num?)?.toInt() ?? 6,
      gstPercent: (j['gst_percent'] as num?)?.toDouble() ?? 18,
      tvFee: (j['tv_fee'] as num?)?.toDouble() ?? 0,
      // "fpa_per_unit" is the schema-1 name.
      fcaPerUnit: ((adj['fca_per_unit'] ?? j['fpa_per_unit']) as num?)?.toDouble() ?? 0,
      fcaLabel: (adj['fca_label'] as String?) ?? 'Fuel charges adjustment',
      qtaPerUnit: (adj['qta_per_unit'] as num?)?.toDouble() ?? 0,
      qtaLabel: (adj['qta_label'] as String?) ?? 'Quarterly adjustment',
      electricityDutyPercent: {
        for (final e in Map<String, dynamic>.from(
          (j['electricity_duty_percent'] as Map?) ?? const {},
        ).entries)
          e.key: (e.value as num).toDouble(),
      },
      lifelineCategory: j['lifeline'] == null
          ? null
          : TariffCategory.fromJson(Map<String, dynamic>.from(j['lifeline'] as Map)),
      protectedCategory:
          TariffCategory.fromJson(Map<String, dynamic>.from(j['protected'] as Map)),
      unprotectedCategory:
          TariffCategory.fromJson(Map<String, dynamic>.from(j['unprotected'] as Map)),
      companyOverrides: {
        for (final e in Map<String, dynamic>.from((j['company_overrides'] as Map?) ?? const {}).entries)
          e.key: Map<String, dynamic>.from(e.value as Map),
      },
      tou: TouRates.fromJson(j['tou'] == null ? null : Map<String, dynamic>.from(j['tou'] as Map)),
      solar: SolarRates.fromJson(j['solar'] == null ? null : Map<String, dynamic>.from(j['solar'] as Map)),
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'version': version,
        'id': id,
        'name': name,
        'effective_from': effectiveFrom,
        'updated_at': updatedAt,
        'source_note': sourceNote,
        'sources': [for (final s in sources) s.toJson()],
        'protected_threshold_units': protectedThresholdUnits,
        'protected_months': protectedMonths,
        'gst_percent': gstPercent,
        'tv_fee': tvFee,
        'adjustments': {
          'fca_per_unit': fcaPerUnit,
          'fca_label': fcaLabel,
          'qta_per_unit': qtaPerUnit,
          'qta_label': qtaLabel,
        },
        'electricity_duty_percent': electricityDutyPercent,
        if (lifelineCategory != null) 'lifeline': lifelineCategory!.toJson(),
        'protected': protectedCategory.toJson(),
        'unprotected': unprotectedCategory.toJson(),
        'company_overrides': companyOverrides,
        'tou': tou.toJson(),
        'solar': solar.toJson(),
      };
}

/// Sanity checks so a typo in the published JSON can never break the app.
class TariffValidator {
  TariffValidator._();

  /// Returns null when valid, otherwise a short reason.
  static String? validate(Tariff t) {
    if (t.schemaVersion > Tariff.supportedSchema) {
      return 'Needs a newer app version (schema ${t.schemaVersion})';
    }
    if (t.version <= 0) return 'Missing version';
    if (t.protectedThresholdUnits < 50 || t.protectedThresholdUnits > 1000) {
      return 'Protected threshold out of range';
    }
    if (t.gstPercent < 0 || t.gstPercent > 40) return 'GST out of range';
    if (t.fcaPerUnit.abs() > 30 || t.qtaPerUnit.abs() > 30) return 'Adjustment out of range';
    if (t.tvFee < 0 || t.tvFee > 500) return 'TV fee out of range';
    for (final entry in {
      'protected': t.protectedCategory,
      'unprotected': t.unprotectedCategory,
      if (t.lifelineCategory != null) 'lifeline': t.lifelineCategory!,
    }.entries) {
      final reason = _category(entry.value);
      if (reason != null) return '${entry.key}: $reason';
    }
    for (final e in t.companyOverrides.entries) {
      for (final k in ['fca_per_unit', 'qta_per_unit']) {
        final v = e.value[k];
        if (v != null && (v is! num || v.abs() > 30)) return '${e.key}: $k out of range';
      }
      final g = e.value['gst_percent'];
      if (g != null && (g is! num || g < 0 || g > 40)) return '${e.key}: gst_percent out of range';
    }
    final tou = t.tou;
    if (tou.peakRate <= 0 || tou.peakRate > 500 || tou.offPeakRate <= 0 || tou.offPeakRate > 500) {
      return 'TOU rates out of range';
    }
    if (tou.fixedPerKw < 0 || tou.fixedPerKw > 5000 || tou.fixedLoadShare < 0 || tou.fixedLoadShare > 1) {
      return 'TOU fixed charge out of range';
    }
    if (t.solar.netMeteringRate < 0 || t.solar.netMeteringRate > 200 ||
        t.solar.netBillingRate < 0 || t.solar.netBillingRate > 200) {
      return 'Solar rates out of range';
    }
    if (t.unprotectedCategory.slabs.last.to != null) {
      return 'unprotected: last slab must be open-ended';
    }
    return null;
  }

  static String? _category(TariffCategory c) {
    if (c.slabs.isEmpty) return 'no slabs';
    if (c.fcSurchargePerUnit < 0 || c.fcSurchargePerUnit > 30) return 'surcharge out of range';
    var expectedFrom = 1;
    for (var i = 0; i < c.slabs.length; i++) {
      final s = c.slabs[i];
      if (s.from != expectedFrom) return 'slab ${s.label} should start at $expectedFrom';
      if (s.rate <= 0 || s.rate > 500) return 'rate for ${s.label} out of range';
      if (s.fixedPerKw < 0 || s.fixedPerKw > 5000) return 'fixed charge for ${s.label} out of range';
      if (s.to == null) {
        if (i != c.slabs.length - 1) return 'open-ended slab must be last';
        break;
      }
      if (s.to! < s.from) return 'slab ${s.label} is reversed';
      expectedFrom = s.to! + 1;
    }
    return null;
  }
}
