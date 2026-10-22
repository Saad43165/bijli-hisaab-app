import 'strings_ur.dart';

/// App language. English text is the key; [urdu] holds the translations.
/// Anything not translated yet stays in English, so nothing ever breaks.
class L10n {
  L10n._();

  static String _lang = 'en';

  static String get language => _lang;
  static bool get isUrdu => _lang == 'ur';

  static void setLanguage(String code) => _lang = code == 'ur' ? 'ur' : 'en';
}

extension Tr on String {
  /// This text in the current language.
  String get tr => L10n.isUrdu ? (urdu[this] ?? this) : this;

  /// With placeholders: `'{n} days left'.trf({'n': 5})`.
  String trf(Map<String, Object> args) {
    var s = tr;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }
}
