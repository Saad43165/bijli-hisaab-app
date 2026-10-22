import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

/// Rotates an image file by [quarterTurns] × 90° clockwise and writes the
/// result next to it as a PNG. Uses the engine's decoder (which already
/// applies EXIF orientation), so no extra packages are needed.
///
/// The long side is capped at [maxSide] to keep OCR and saving fast.
Future<String> rotateImageFile(String path, int quarterTurns, {int maxSide = 3000}) async {
  final turns = quarterTurns % 4;
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final src = frame.image;
  codec.dispose();

  final scale = math.min(1.0, maxSide / math.max(src.width, src.height));
  final w = (src.width * scale).round();
  final h = (src.height * scale).round();
  final outW = turns.isOdd ? h : w;
  final outH = turns.isOdd ? w : h;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.translate(outW / 2, outH / 2);
  canvas.rotate(turns * math.pi / 2);
  canvas.drawImageRect(
    src,
    ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    ui.Rect.fromCenter(center: ui.Offset.zero, width: w.toDouble(), height: h.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final rotated = await picture.toImage(outW, outH);
  picture.dispose();
  src.dispose();

  final png = await rotated.toByteData(format: ui.ImageByteFormat.png);
  rotated.dispose();
  if (png == null) throw StateError('Could not encode rotated image');

  final dot = path.lastIndexOf('.');
  final base = dot > path.lastIndexOf(Platform.pathSeparator) ? path.substring(0, dot) : path;
  final out = '${base}_r${DateTime.now().microsecondsSinceEpoch}.png';
  await File(out).writeAsBytes(png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes), flush: true);
  return out;
}
