import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/meter_ocr_service.dart';
import '../../../core/l10n/l10n.dart';

/// Drawn over the live camera: dims everything outside a wide frame in the
/// middle (where the meter digits go), with amber corners, a guide line,
/// a tap-to-focus ring and a problem hint.
///
/// The frame uses [MeterFrame]'s numbers so it matches the area the OCR
/// service searches.
class MeterFrameOverlay extends StatelessWidget {
  const MeterFrameOverlay({super.key, this.focusPoint, this.hint});

  final Offset? focusPoint;

  /// Shown under the frame when a scan didn't work.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final frame = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width * MeterFrame.widthFactor,
          height: size.height * MeterFrame.heightFactor,
        );
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _FramePainter(frame))),
            Positioned(
              left: 24,
              right: 24,
              bottom: size.height - frame.top + 14,
              child: Text(
                'Fit the meter numbers inside the frame'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: frame.bottom + 14,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: hint == null
                    ? Text(
                        'Skip digits in red or after a decimal point'.tr,
                        key: const ValueKey('tip'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      )
                    : Container(
                        key: ValueKey(hint),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.dangerDark.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                hint!,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            if (focusPoint != null)
              Positioned(
                left: focusPoint!.dx - 32,
                top: focusPoint!.dy - 32,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(focusPoint),
                  tween: Tween(begin: 1.4, end: 1),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.amber, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.frame);

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(frame, const Radius.circular(16));

    // Dim the outside.
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(r)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(outside, Paint()..color = Colors.black.withValues(alpha: 0.55));

    // Thin outline.
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.5),
    );

    // Amber corners.
    final corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.amber;
    final len = (frame.shortestSide * 0.35).clamp(14.0, 34.0);
    const rad = 16.0;
    void bracket(Offset c, double dx, double dy) {
      final p = Path()
        ..moveTo(c.dx, c.dy + dy * len)
        ..lineTo(c.dx, c.dy + dy * rad)
        ..arcToPoint(Offset(c.dx + dx * rad, c.dy), radius: const Radius.circular(rad), clockwise: dx * dy > 0)
        ..lineTo(c.dx + dx * len, c.dy);
      canvas.drawPath(p, corner);
    }

    bracket(frame.topLeft, 1, 1);
    bracket(frame.topRight, -1, 1);
    bracket(frame.bottomLeft, 1, -1);
    bracket(frame.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.frame != frame;
}
