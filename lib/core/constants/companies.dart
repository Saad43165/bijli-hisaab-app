import 'package:flutter/painting.dart';

/// Which tariff a company bills under.
enum TariffAuthority {
  /// NEPRA uniform tariff (all ex-WAPDA DISCOs and K-Electric since 2026).
  nepra,

  /// Area with its own government-set tariff (AJK, Gilgit-Baltistan).
  own,
}

/// An electricity distribution company.
class PowerCompany {
  const PowerCompany({
    required this.code,
    required this.fullName,
    required this.region,
    required this.province,
    required this.color,
    this.group = 'WAPDA DISCO',
    this.authority = TariffAuthority.nepra,
    this.website,
    this.billUrl,
    this.helpline,
    this.accountLabel = 'Reference number (14 digits)',
    this.aliases = const [],
  });

  /// Stored on the meter, e.g. "LESCO", "K-Electric".
  final String code;
  final String fullName;
  final String region;

  /// Default province for the meter form.
  final String province;

  /// Brand-neutral accent colour for the company badge.
  final Color color;
  final String group;
  final TariffAuthority authority;
  final String? website;

  /// Official page to view/download the latest bill.
  final String? billUrl;
  final String? helpline;
  final String accountLabel;

  /// Extra words the bill scanner looks for.
  final List<String> aliases;

  bool get usesNepraTariff => authority == TariffAuthority.nepra;

  /// Optional logo: drop a PNG with this name into assets/images/companies/.
  String get logoAsset => 'assets/images/companies/${code.toLowerCase().replaceAll('-', '_')}.png';

  /// "LESCO", "KE", "AJK" — used on the badge when no logo is bundled.
  String get shortCode => switch (code) {
        'K-Electric' => 'KE',
        'AJK-ED' => 'AJK',
        'GB-WPD' => 'GB',
        _ => code,
      };
}

class PowerCompanies {
  PowerCompanies._();

  static String _pitc(String disco) => 'https://bill.pitc.com.pk/${disco.toLowerCase()}bill';

  static final List<PowerCompany> all = [
    PowerCompany(
      code: 'LESCO',
      fullName: 'Lahore Electric Supply Company',
      region: 'Lahore, Kasur, Okara, Sheikhupura, Nankana Sahib',
      province: 'Punjab',
      color: const Color(0xFF1565C0),
      website: 'https://www.lesco.gov.pk',
      billUrl: _pitc('LESCO'),
      helpline: '118',
    ),
    PowerCompany(
      code: 'IESCO',
      fullName: 'Islamabad Electric Supply Company',
      region: 'Islamabad, Rawalpindi, Attock, Jhelum, Chakwal',
      province: 'ICT',
      color: const Color(0xFF00897B),
      website: 'https://www.iesco.com.pk',
      billUrl: _pitc('IESCO'),
      helpline: '118',
    ),
    PowerCompany(
      code: 'FESCO',
      fullName: 'Faisalabad Electric Supply Company',
      region: 'Faisalabad, Jhang, Sargodha, Toba Tek Singh, Chiniot, Khushab, Mianwali, Bhakkar',
      province: 'Punjab',
      color: const Color(0xFF6A1B9A),
      website: 'https://www.fesco.com.pk',
      billUrl: _pitc('FESCO'),
      helpline: '118',
    ),
    PowerCompany(
      code: 'GEPCO',
      fullName: 'Gujranwala Electric Power Company',
      region: 'Gujranwala, Sialkot, Gujrat, Narowal, Hafizabad, Mandi Bahauddin',
      province: 'Punjab',
      color: const Color(0xFF2E7D32),
      website: 'https://www.gepco.com.pk',
      billUrl: _pitc('GEPCO'),
      helpline: '118',
    ),
    PowerCompany(
      code: 'MEPCO',
      fullName: 'Multan Electric Power Company',
      region: 'Multan, Bahawalpur, D.G. Khan, Sahiwal, Rahim Yar Khan, Vehari',
      province: 'Punjab',
      color: const Color(0xFFEF6C00),
      website: 'https://www.mepco.com.pk',
      billUrl: _pitc('MEPCO'),
      helpline: '118',
    ),
    PowerCompany(
      code: 'PESCO',
      fullName: 'Peshawar Electric Supply Company',
      region: 'Peshawar, Mardan, Swat, Kohat, Bannu, D.I. Khan',
      province: 'KP',
      color: const Color(0xFF00838F),
      website: 'https://www.pesco.gov.pk',
      billUrl: _pitc('PESCO'),
      helpline: '118',
    ),
    PowerCompany(
      code: 'HAZECO',
      fullName: 'Hazara Electric Supply Company',
      region: 'Abbottabad, Haripur, Mansehra, Battagram, Torghar, Kohistan',
      province: 'KP',
      color: const Color(0xFF558B2F),
      website: 'https://hazeco.com.pk',
      billUrl: 'https://bill.pitc.com.pk',
      helpline: '118',
    ),
    PowerCompany(
      code: 'TESCO',
      fullName: 'Tribal Electric Supply Company',
      region: 'Merged districts of Khyber Pakhtunkhwa',
      province: 'KP',
      color: const Color(0xFF795548),
      website: 'https://www.tesco.gov.pk',
      billUrl: _pitc('TESCO'),
      helpline: '118',
    ),
    PowerCompany(
      code: 'HESCO',
      fullName: 'Hyderabad Electric Supply Company',
      region: 'Hyderabad, Mirpurkhas, Badin, Thatta, Nawabshah',
      province: 'Sindh',
      color: const Color(0xFFC62828),
      website: 'https://www.hesco.gov.pk',
      billUrl: _pitc('HESCO'),
      helpline: '118',
    ),
    PowerCompany(
      code: 'SEPCO',
      fullName: 'Sukkur Electric Power Company',
      region: 'Sukkur, Larkana, Jacobabad, Shikarpur, Ghotki',
      province: 'Sindh',
      color: const Color(0xFFAD1457),
      website: 'https://www.sepco.com.pk',
      billUrl: _pitc('SEPCO'),
      helpline: '118',
    ),
    PowerCompany(
      code: 'QESCO',
      fullName: 'Quetta Electric Supply Company',
      region: 'Balochistan (except Hub and Lasbela)',
      province: 'Balochistan',
      color: const Color(0xFF4527A0),
      website: 'https://www.qesco.com.pk',
      billUrl: _pitc('QESCO'),
      helpline: '118',
    ),
    const PowerCompany(
      code: 'K-Electric',
      fullName: 'K-Electric',
      region: 'Karachi, Hub, Uthal, Vinder, Bela',
      province: 'Sindh',
      color: Color(0xFFD32F2F),
      group: 'Private utility',
      website: 'https://www.ke.com.pk',
      billUrl: 'https://www.ke.com.pk',
      helpline: '118',
      accountLabel: 'Account number',
      aliases: ['K-ELECTRIC', 'KELECTRIC', 'K ELECTRIC', 'KARACHI ELECTRIC'],
    ),
    const PowerCompany(
      code: 'AJK-ED',
      fullName: 'AJK Electricity Department',
      region: 'Azad Jammu & Kashmir',
      province: 'AJK',
      color: Color(0xFF37474F),
      group: 'Government department',
      authority: TariffAuthority.own,
      accountLabel: 'Consumer number',
      aliases: ['AZAD', 'AJK'],
    ),
    const PowerCompany(
      code: 'GB-WPD',
      fullName: 'Gilgit-Baltistan Water & Power Department',
      region: 'Gilgit-Baltistan',
      province: 'GB',
      color: Color(0xFF455A64),
      group: 'Government department',
      authority: TariffAuthority.own,
      accountLabel: 'Consumer number',
      aliases: ['GILGIT', 'BALTISTAN'],
    ),
  ];

  static PowerCompany of(String code) =>
      all.firstWhere((c) => c.code == code, orElse: () => all.first);

  static PowerCompany? tryOf(String code) {
    for (final c in all) {
      if (c.code == code) return c;
    }
    return null;
  }
}
