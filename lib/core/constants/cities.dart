/// Main cities and towns with their province and the electricity company
/// that serves them. Used to suggest cities for the chosen company, keep the
/// province consistent, and catch a city typed under the wrong company.
class Cities {
  Cities._();

  /// City → (province, company code).
  static const Map<String, (String, String)> _data = {
    // IESCO: Islamabad, Rawalpindi, Attock, Jhelum, Chakwal
    'Islamabad': ('ICT', 'IESCO'),
    'Rawalpindi': ('Punjab', 'IESCO'), 'Attock': ('Punjab', 'IESCO'), 'Jhelum': ('Punjab', 'IESCO'),
    'Chakwal': ('Punjab', 'IESCO'), 'Taxila': ('Punjab', 'IESCO'), 'Murree': ('Punjab', 'IESCO'),
    'Wah Cantt': ('Punjab', 'IESCO'), 'Talagang': ('Punjab', 'IESCO'), 'Gujar Khan': ('Punjab', 'IESCO'),
    'Fateh Jang': ('Punjab', 'IESCO'), 'Pind Dadan Khan': ('Punjab', 'IESCO'), 'Kallar Syedan': ('Punjab', 'IESCO'),
    'Hasan Abdal': ('Punjab', 'IESCO'), 'Dina': ('Punjab', 'IESCO'),
    // LESCO: Lahore, Kasur, Okara, Sheikhupura, Nankana Sahib
    'Lahore': ('Punjab', 'LESCO'), 'Kasur': ('Punjab', 'LESCO'), 'Okara': ('Punjab', 'LESCO'),
    'Sheikhupura': ('Punjab', 'LESCO'), 'Nankana Sahib': ('Punjab', 'LESCO'), 'Muridke': ('Punjab', 'LESCO'),
    'Raiwind': ('Punjab', 'LESCO'), 'Pattoki': ('Punjab', 'LESCO'), 'Renala Khurd': ('Punjab', 'LESCO'),
    'Depalpur': ('Punjab', 'LESCO'),
    // GEPCO: Gujranwala, Sialkot, Gujrat, Narowal, Mandi Bahauddin, Hafizabad
    'Gujranwala': ('Punjab', 'GEPCO'), 'Sialkot': ('Punjab', 'GEPCO'), 'Gujrat': ('Punjab', 'GEPCO'),
    'Narowal': ('Punjab', 'GEPCO'), 'Mandi Bahauddin': ('Punjab', 'GEPCO'), 'Hafizabad': ('Punjab', 'GEPCO'),
    'Kamoke': ('Punjab', 'GEPCO'), 'Daska': ('Punjab', 'GEPCO'), 'Wazirabad': ('Punjab', 'GEPCO'),
    'Kharian': ('Punjab', 'GEPCO'), 'Shakargarh': ('Punjab', 'GEPCO'), 'Lalamusa': ('Punjab', 'GEPCO'),
    'Sambrial': ('Punjab', 'GEPCO'),
    // FESCO: Faisalabad, Sargodha, Jhang, Toba Tek Singh, Chiniot, Mianwali, Khushab, Bhakkar
    'Faisalabad': ('Punjab', 'FESCO'), 'Sargodha': ('Punjab', 'FESCO'), 'Jhang': ('Punjab', 'FESCO'),
    'Toba Tek Singh': ('Punjab', 'FESCO'), 'Chiniot': ('Punjab', 'FESCO'), 'Mianwali': ('Punjab', 'FESCO'),
    'Khushab': ('Punjab', 'FESCO'), 'Bhakkar': ('Punjab', 'FESCO'), 'Gojra': ('Punjab', 'FESCO'),
    'Jaranwala': ('Punjab', 'FESCO'), 'Kamalia': ('Punjab', 'FESCO'), 'Samundri': ('Punjab', 'FESCO'),
    'Bhalwal': ('Punjab', 'FESCO'),
    // MEPCO: south Punjab
    'Multan': ('Punjab', 'MEPCO'), 'Bahawalpur': ('Punjab', 'MEPCO'), 'Rahim Yar Khan': ('Punjab', 'MEPCO'),
    'Dera Ghazi Khan': ('Punjab', 'MEPCO'), 'Sahiwal': ('Punjab', 'MEPCO'), 'Khanewal': ('Punjab', 'MEPCO'),
    'Vehari': ('Punjab', 'MEPCO'), 'Muzaffargarh': ('Punjab', 'MEPCO'), 'Bahawalnagar': ('Punjab', 'MEPCO'),
    'Lodhran': ('Punjab', 'MEPCO'), 'Layyah': ('Punjab', 'MEPCO'), 'Rajanpur': ('Punjab', 'MEPCO'),
    'Pakpattan': ('Punjab', 'MEPCO'), 'Burewala': ('Punjab', 'MEPCO'), 'Arifwala': ('Punjab', 'MEPCO'),
    'Kot Addu': ('Punjab', 'MEPCO'), 'Sadiqabad': ('Punjab', 'MEPCO'), 'Khanpur': ('Punjab', 'MEPCO'),
    'Chichawatni': ('Punjab', 'MEPCO'), 'Mian Channu': ('Punjab', 'MEPCO'),
    // PESCO: Khyber Pakhtunkhwa (except Hazara)
    'Peshawar': ('KP', 'PESCO'), 'Mardan': ('KP', 'PESCO'), 'Mingora': ('KP', 'PESCO'), 'Swat': ('KP', 'PESCO'),
    'Kohat': ('KP', 'PESCO'), 'Dera Ismail Khan': ('KP', 'PESCO'), 'Bannu': ('KP', 'PESCO'),
    'Nowshera': ('KP', 'PESCO'), 'Charsadda': ('KP', 'PESCO'), 'Swabi': ('KP', 'PESCO'),
    'Chitral': ('KP', 'PESCO'), 'Dir': ('KP', 'PESCO'), 'Timergara': ('KP', 'PESCO'), 'Karak': ('KP', 'PESCO'),
    'Lakki Marwat': ('KP', 'PESCO'), 'Batkhela': ('KP', 'PESCO'), 'Tank': ('KP', 'PESCO'),
    'Hangu': ('KP', 'PESCO'), 'Shabqadar': ('KP', 'PESCO'),
    // HAZECO: Hazara division
    'Abbottabad': ('KP', 'HAZECO'), 'Mansehra': ('KP', 'HAZECO'), 'Haripur': ('KP', 'HAZECO'),
    'Battagram': ('KP', 'HAZECO'), 'Havelian': ('KP', 'HAZECO'),
    // TESCO: merged tribal districts
    'Bajaur': ('KP', 'TESCO'), 'Khar': ('KP', 'TESCO'), 'Landi Kotal': ('KP', 'TESCO'), 'Jamrud': ('KP', 'TESCO'),
    'Parachinar': ('KP', 'TESCO'), 'Miranshah': ('KP', 'TESCO'), 'Wana': ('KP', 'TESCO'),
    'Ghalanai': ('KP', 'TESCO'),
    // HESCO: lower Sindh (outside Karachi)
    'Hyderabad': ('Sindh', 'HESCO'), 'Mirpur Khas': ('Sindh', 'HESCO'), 'Nawabshah': ('Sindh', 'HESCO'),
    'Badin': ('Sindh', 'HESCO'), 'Thatta': ('Sindh', 'HESCO'), 'Tando Adam': ('Sindh', 'HESCO'),
    'Tando Allahyar': ('Sindh', 'HESCO'), 'Umerkot': ('Sindh', 'HESCO'), 'Sanghar': ('Sindh', 'HESCO'),
    'Jamshoro': ('Sindh', 'HESCO'), 'Kotri': ('Sindh', 'HESCO'), 'Matiari': ('Sindh', 'HESCO'),
    // SEPCO: upper Sindh
    'Sukkur': ('Sindh', 'SEPCO'), 'Larkana': ('Sindh', 'SEPCO'), 'Jacobabad': ('Sindh', 'SEPCO'),
    'Shikarpur': ('Sindh', 'SEPCO'), 'Khairpur': ('Sindh', 'SEPCO'), 'Dadu': ('Sindh', 'SEPCO'),
    'Ghotki': ('Sindh', 'SEPCO'), 'Kandhkot': ('Sindh', 'SEPCO'), 'Rohri': ('Sindh', 'SEPCO'),
    // K-Electric: Karachi and nearby
    'Karachi': ('Sindh', 'K-Electric'), 'Hub': ('Balochistan', 'K-Electric'), 'Gharo': ('Sindh', 'K-Electric'),
    'Dhabeji': ('Sindh', 'K-Electric'), 'Uthal': ('Balochistan', 'K-Electric'),
    // QESCO: Balochistan
    'Quetta': ('Balochistan', 'QESCO'), 'Turbat': ('Balochistan', 'QESCO'), 'Khuzdar': ('Balochistan', 'QESCO'),
    'Gwadar': ('Balochistan', 'QESCO'), 'Chaman': ('Balochistan', 'QESCO'), 'Sibi': ('Balochistan', 'QESCO'),
    'Zhob': ('Balochistan', 'QESCO'), 'Loralai': ('Balochistan', 'QESCO'),
    'Dera Murad Jamali': ('Balochistan', 'QESCO'), 'Kalat': ('Balochistan', 'QESCO'),
    'Pishin': ('Balochistan', 'QESCO'), 'Mastung': ('Balochistan', 'QESCO'),
    // AJK Electricity Department
    'Muzaffarabad': ('AJK', 'AJK-ED'), 'Mirpur': ('AJK', 'AJK-ED'), 'Kotli': ('AJK', 'AJK-ED'),
    'Bhimber': ('AJK', 'AJK-ED'), 'Rawalakot': ('AJK', 'AJK-ED'), 'Bagh': ('AJK', 'AJK-ED'),
    // GB Water & Power
    'Gilgit': ('GB', 'GB-WPD'), 'Skardu': ('GB', 'GB-WPD'), 'Hunza': ('GB', 'GB-WPD'),
    'Chilas': ('GB', 'GB-WPD'), 'Ghizer': ('GB', 'GB-WPD'),
  };

  /// Provinces each company serves, most common first.
  static const Map<String, List<String>> _companyProvinces = {
    'LESCO': ['Punjab'],
    'GEPCO': ['Punjab'],
    'FESCO': ['Punjab'],
    'MEPCO': ['Punjab'],
    'IESCO': ['Punjab', 'ICT'],
    'PESCO': ['KP'],
    'HAZECO': ['KP'],
    'TESCO': ['KP'],
    'HESCO': ['Sindh'],
    'SEPCO': ['Sindh'],
    'K-Electric': ['Sindh', 'Balochistan'],
    'QESCO': ['Balochistan'],
    'AJK-ED': ['AJK'],
    'GB-WPD': ['GB'],
  };

  static final List<String> names = _data.keys.toList()..sort();

  static String? _key(String city) {
    final k = city.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (k.isEmpty) return null;
    for (final name in _data.keys) {
      if (name.toLowerCase() == k) return name;
    }
    return null;
  }

  /// Province for [city] (case and spacing ignored), or null if unknown.
  static String? provinceOf(String city) => _data[_key(city)]?.$1;

  /// Company that serves [city], or null if unknown.
  static String? companyOf(String city) => _data[_key(city)]?.$2;

  /// Provinces [company] serves (all provinces if unknown).
  static List<String> provincesFor(String company) =>
      _companyProvinces[company] ?? const ['Punjab', 'Sindh', 'KP', 'Balochistan', 'ICT', 'AJK', 'GB'];

  /// Known cities served by [company].
  static List<String> citiesFor(String company) => [
        for (final n in names)
          if (_data[n]!.$2 == company) n,
      ];

  /// Cities of [company] starting with [query] first, then ones containing it.
  static List<String> suggest(String query, {String? company, int limit = 6}) {
    final pool = company == null ? names : citiesFor(company);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return pool.take(limit).toList();
    final starts = pool.where((n) => n.toLowerCase().startsWith(q));
    final contains = pool.where((n) => !n.toLowerCase().startsWith(q) && n.toLowerCase().contains(q));
    return [...starts, ...contains].take(limit).toList();
  }

  /// Province to use for [city] under [company]: the city's own province,
  /// else the company's main one.
  static String provinceFor(String company, String city) {
    final allowed = provincesFor(company);
    final p = provinceOf(city);
    return p != null && allowed.contains(p) ? p : allowed.first;
  }
}
