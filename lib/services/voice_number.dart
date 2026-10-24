import 'package:speech_to_text/speech_to_text.dart';

import '../core/l10n/l10n.dart';

/// Reads a meter number spoken aloud ("12450", "ایک دو چار پانچ صفر").
class VoiceNumber {
  VoiceNumber._();

  static final SpeechToText _speech = SpeechToText();
  static bool _ready = false;

  /// Listens once and returns the digits heard, or null. [onPartial] gets
  /// live text while the user speaks.
  static Future<String?> listen({void Function(String text)? onPartial}) async {
    if (!_ready) {
      _ready = await _speech.initialize();
      if (!_ready) return null;
    }
    String? result;
    var done = false;
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: L10n.isUrdu ? 'ur_PK' : 'en_US',
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
      onResult: (r) {
        onPartial?.call(r.recognizedWords);
        if (r.finalResult) {
          result = digits(r.recognizedWords);
          done = true;
        }
      },
    );
    // Wait until the recogniser stops (final result, silence or timeout).
    for (var i = 0; i < 160 && !done && _speech.isListening; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!done) {
      await _speech.stop();
      result ??= digits(_speech.lastRecognizedWords);
    }
    return (result?.isEmpty ?? true) ? null : result;
  }

  static Future<void> stop() => _speech.stop();

  /// Listens once and returns the words heard (for the assistant), or null.
  static Future<String?> listenWords({void Function(String text)? onPartial, String? localeId}) async {
    if (!_ready) {
      _ready = await _speech.initialize();
      if (!_ready) return null;
    }
    String? result;
    var done = false;
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: localeId ?? (L10n.isUrdu ? 'ur_PK' : 'en_US'),
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
      onResult: (r) {
        onPartial?.call(r.recognizedWords);
        if (r.finalResult) {
          result = r.recognizedWords;
          done = true;
        }
      },
    );
    for (var i = 0; i < 250 && !done && _speech.isListening; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!done) {
      await _speech.stop();
      result ??= _speech.lastRecognizedWords;
    }
    return (result?.trim().isEmpty ?? true) ? null : result!.trim();
  }

  static const _words = {
    // English
    'zero': '0', 'oh': '0', 'one': '1', 'two': '2', 'to': '2', 'too': '2', 'three': '3', 'four': '4',
    'for': '4', 'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
    // Urdu
    'صفر': '0', 'زیرو': '0', 'ایک': '1', 'دو': '2', 'تین': '3', 'چار': '4', 'پانچ': '5',
    'چھ': '6', 'چھے': '6', 'سات': '7', 'آٹھ': '8', 'نو': '9',
  };

  /// Digits in [text]: numerals (Latin, Urdu or Arabic) and digit words said
  /// one by one. "12,450" → "12450", "one two four" → "124".
  static String digits(String text) {
    final out = StringBuffer();
    for (final token in text.toLowerCase().split(RegExp(r'[\s,\-]+'))) {
      if (token.isEmpty) continue;
      final w = _words[token];
      if (w != null) {
        out.write(w);
        continue;
      }
      for (final c in token.runes) {
        if (c >= 0x30 && c <= 0x39) {
          out.writeCharCode(c);
        } else if (c >= 0x6F0 && c <= 0x6F9) {
          out.writeCharCode(0x30 + c - 0x6F0);
        } else if (c >= 0x660 && c <= 0x669) {
          out.writeCharCode(0x30 + c - 0x660);
        }
      }
    }
    return out.toString();
  }
}
