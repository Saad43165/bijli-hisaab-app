import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'bill_scan_analyzer.dart';
import 'image_rotation.dart';

enum CaptureSource {
  /// Google's document scanner: finds the bill edges, auto-captures,
  /// crops, removes shadows, has a flash button and gallery import.
  smartScanner,

  /// Plain camera photo.
  camera,

  /// Existing photo from the gallery.
  gallery,
}

class BillScanResult {
  const BillScanResult({required this.imagePaths, required this.analysis});

  final List<String> imagePaths;
  final BillScanAnalysis analysis;
}

class ScanCancelled implements Exception {
  const ScanCancelled();
}

/// Smart scanner not available (old Google Play services, no Play Store).
class SmartScannerUnavailable implements Exception {
  const SmartScannerUnavailable(this.reason);
  final String reason;
}

/// Capture (document scanner / camera / gallery) + on-device OCR.
class BillOcrService {
  BillOcrService({ImagePicker? picker, BillScanAnalyzer analyzer = const BillScanAnalyzer()})
      : _picker = picker ?? ImagePicker(),
        _analyzer = analyzer;

  final ImagePicker _picker;
  final BillScanAnalyzer _analyzer;

  /// Returns image file paths, or throws [ScanCancelled].
  Future<List<String>> capture(CaptureSource source) async {
    switch (source) {
      case CaptureSource.smartScanner:
        final scanner = DocumentScanner(
          options: DocumentScannerOptions(
            documentFormats: const {DocumentFormat.jpeg},
            mode: ScannerMode.full,
            // Front and back of the bill.
            pageLimit: 2,
            isGalleryImport: true,
          ),
        );
        try {
          final result = await scanner.scanDocument();
          final images = result.images ?? const <String>[];
          if (images.isEmpty) throw const ScanCancelled();
          return images;
        } on PlatformException catch (e) {
          final msg = '${e.code} ${e.message ?? ''}'.toLowerCase();
          if (msg.contains('cancel')) throw const ScanCancelled();
          debugPrint('Document scanner failed: ${e.code} ${e.message}');
          throw SmartScannerUnavailable(e.message ?? e.code);
        } on MissingPluginException {
          throw const SmartScannerUnavailable('Not supported on this device');
        } on TypeError {
          // The plugin returns null when the user backs out.
          throw const ScanCancelled();
        } finally {
          try {
            await scanner.close();
          } catch (_) {}
        }
      case CaptureSource.camera:
      case CaptureSource.gallery:
        final file = await _picker.pickImage(
          source: source == CaptureSource.camera ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 95,
          maxWidth: 3000,
          requestFullMetadata: false,
        );
        if (file == null) throw const ScanCancelled();
        return [file.path];
    }
  }

  /// Reads every page and analyses them together.
  ///
  /// With [autoRotate], a page that reads like nonsense (bill photographed
  /// upside down or sideways) is turned until its text makes sense; the
  /// returned [BillScanResult.imagePaths] then point at the upright copies.
  Future<BillScanResult> read(
    List<String> imagePaths, {
    double Function(int units)? estimateAmount,
    bool autoRotate = true,
    String? expectedCompany,
  }) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final lines = <OcrLine>[];
    final paths = [...imagePaths];
    try {
      for (var page = 0; page < paths.length; page++) {
        var best = await _recognize(recognizer, paths[page]);
        var bestScore = orientationScore(best.map((l) => l.text));
        final original = bestScore;
        // Only pages that read as near-gibberish are tried rotated; a blurry
        // or glary upright page must never be "rescued" into upside down.
        if (autoRotate && original < _lowScore) {
          // Upside down is by far the most common mistake, so try it first.
          for (final turns in const [2, 1, 3]) {
            final String rotated;
            final List<OcrLine> candidate;
            try {
              rotated = await rotateImageFile(imagePaths[page], turns);
              candidate = await _recognize(recognizer, rotated);
            } catch (e) {
              debugPrint('Auto-rotate failed: $e');
              break;
            }
            final score = orientationScore(candidate.map((l) => l.text));
            // The turned page must read clearly like a bill, and far better
            // than the original — not just a little better.
            if (score >= _uprightScore && score >= original * 2 + 3 && score > bestScore) {
              best = candidate;
              bestScore = score;
              paths[page] = rotated;
              break;
            }
          }
        }
        for (final l in best) {
          lines.add(OcrLine(l.text, l.box, page: page));
        }
      }
    } finally {
      await recognizer.close();
    }
    final analysis = _analyzer.analyze(
      lines,
      pageCount: paths.length,
      estimateAmount: estimateAmount,
      expectedCompany: expectedCompany,
    );
    return BillScanResult(imagePaths: paths, analysis: analysis);
  }

  Future<List<OcrLine>> _recognize(TextRecognizer recognizer, String path) async {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          OcrLine(
            line.text,
            OcrBox(line.boundingBox.left, line.boundingBox.top, line.boundingBox.right, line.boundingBox.bottom),
          ),
    ];
  }

  /// A page with at least this many bill words is treated as upright.
  static const _uprightScore = 6;

  /// Below this many bill words a page is treated as possibly turned.
  static const _lowScore = 3;

  static final _billWords = RegExp(
    r'\b(units?|bill|billing|electric\w*|supply|company|reading|present|previous|meter|'
    r'consumer|reference|due|date|amount|payable|charges?|total|tariff|month|load|'
    r'gst|tax|fpa|fc|surcharge|arrears?|name|address|issue|lesco|iesco|fesco|gepco|'
    r'mepco|pesco|hesco|sepco|qesco|tesco|hazeco|k-?electric|wapda)\b',
    caseSensitive: false,
  );

  /// How much the recognised text looks like a bill (upright text scores
  /// high; upside-down text comes back as gibberish and scores near zero).
  @visibleForTesting
  static int orientationScore(Iterable<String> lines) =>
      lines.fold(0, (sum, l) => sum + _billWords.allMatches(l).length);
}
