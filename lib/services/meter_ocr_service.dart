import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'bill_scan_analyzer.dart';
import 'meter_reading_extractor.dart';

/// Where the on-screen frame sits, as fractions of the photo (0..1).
/// The camera screen draws the frame with the same numbers.
class MeterFrame {
  const MeterFrame._();

  static const double widthFactor = 0.84;
  static const double heightFactor = 0.2;

  /// Slightly bigger than drawn, because people rarely line it up exactly.
  static ui.Rect searchArea(double w, double h) {
    const grow = 1.35;
    final fw = w * math.min(1, widthFactor * grow);
    final fh = h * heightFactor * grow;
    return ui.Rect.fromCenter(center: ui.Offset(w / 2, h / 2), width: fw, height: fh);
  }
}

/// On-device OCR for a photo of the meter display.
class MeterOcrService {
  const MeterOcrService({this.extractor = const MeterReadingExtractor()});

  final MeterReadingExtractor extractor;

  static final _digitGroup = RegExp(r'^[0-9OISBL|]{1,8}$');

  Future<MeterReadResult> read(
    String imagePath, {
    double? lastReading,
    int daysSinceLast = 30,
    bool framed = true,
  }) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final lines = <OcrLine>[];
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final r = line.boundingBox;
          lines.add(OcrLine(line.text, OcrBox(r.left, r.top, r.right, r.bottom)));
          // A line made only of digit groups ("12450 6", the red drum split
          // off) — keep each group too so the extractor can pick or join them.
          // Lines with words (serial numbers etc.) are never split.
          if (line.elements.length > 1 &&
              line.elements.every((e) => _digitGroup.hasMatch(e.text.toUpperCase()))) {
            for (final e in line.elements) {
              final b = e.boundingBox;
              lines.add(OcrLine(e.text, OcrBox(b.left, b.top, b.right, b.bottom)));
            }
          }
        }
      }
    } finally {
      await recognizer.close();
    }

    final size = await _uprightSize(imagePath);
    var inFrame = lines;
    if (framed && size != null) {
      final area = MeterFrame.searchArea(size.width, size.height);
      final kept = lines.where((l) => area.contains(ui.Offset(l.box.centerX, l.box.centerY))).toList();
      if (kept.isNotEmpty) inFrame = kept;
    }

    return extractor.extract(
      inFrame,
      lastReading: lastReading,
      daysSinceLast: daysSinceLast,
      imageWidth: size?.width,
      imageHeight: size?.height,
    );
  }

  /// Photo size as ML Kit sees it (portrait, EXIF rotation applied).
  /// Reads only the header, not the whole image.
  static Future<ui.Size?> _uprightSize(String path) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(path);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width.toDouble();
      final h = descriptor.height.toDouble();
      descriptor.dispose();
      buffer.dispose();
      // The camera screen is locked to portrait.
      return ui.Size(math.min(w, h), math.max(w, h));
    } catch (e) {
      debugPrint('Could not read image size: $e');
      return null;
    }
  }
}
