import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/bill_scan_analyzer.dart';

/// A box to draw on a scanned page.
class PageHighlight {
  const PageHighlight({required this.box, required this.page, required this.color, this.selected = false});

  final OcrBox box;
  final int page;
  final Color color;
  final bool selected;
}

/// Swipeable scanned pages with boxes around the values we read.
/// Tap to open full screen with pinch-zoom.
class ScannedPageViewer extends StatefulWidget {
  const ScannedPageViewer({
    super.key,
    required this.imagePaths,
    required this.highlights,
    this.page = 0,
    this.onPageChanged,
    this.onRotate,
    this.height = 260,
  });

  final List<String> imagePaths;
  final List<PageHighlight> highlights;
  final int page;
  final ValueChanged<int>? onPageChanged;

  /// Turns page [index] a quarter clockwise (shows a Rotate button when set).
  final ValueChanged<int>? onRotate;
  final double height;

  @override
  State<ScannedPageViewer> createState() => _ScannedPageViewerState();
}

class _ScannedPageViewerState extends State<ScannedPageViewer> {
  late final PageController _pages = PageController(initialPage: widget.page);
  final Map<String, Size> _sizes = {};

  @override
  void initState() {
    super.initState();
    for (final p in widget.imagePaths) {
      _loadSize(p);
    }
  }

  @override
  void didUpdateWidget(covariant ScannedPageViewer old) {
    super.didUpdateWidget(old);
    for (final p in widget.imagePaths) {
      if (!_sizes.containsKey(p)) _loadSize(p);
    }
    if (widget.page != old.page && _pages.hasClients && _pages.page?.round() != widget.page) {
      _pages.animateToPage(widget.page, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _loadSize(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      if (mounted) setState(() => _sizes[path] = size);
    } catch (_) {
      // Highlights just won't show for this page.
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _openFull(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('Page ${index + 1} of ${widget.imagePaths.length}'),
          ),
          body: InteractiveViewer(
            maxScale: 6,
            child: Center(child: _page(index)),
          ),
        ),
      ),
    );
  }

  Widget _page(int index) {
    final path = widget.imagePaths[index];
    final size = _sizes[path];
    final boxes = widget.highlights.where((h) => h.page == index).toList();
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54)),
            ),
            if (size != null)
              CustomPaint(painter: _HighlightPainter(imageSize: size, highlights: boxes)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.imagePaths.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: widget.height,
        color: AppColors.navy,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: n,
              onPageChanged: widget.onPageChanged,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _openFull(i),
                child: Padding(padding: const EdgeInsets.all(8), child: _page(i)),
              ),
            ),
            if (widget.onRotate != null)
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => widget.onRotate!(_pages.hasClients ? (_pages.page ?? 0).round() : widget.page),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rotate_right_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Rotate',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      n > 1 ? 'Tap to zoom · swipe for page 2' : 'Tap to zoom',
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter({required this.imageSize, required this.highlights});

  final Size imageSize;
  final List<PageHighlight> highlights;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;
    final scale = (size.width / imageSize.width) < (size.height / imageSize.height)
        ? size.width / imageSize.width
        : size.height / imageSize.height;
    final dx = (size.width - imageSize.width * scale) / 2;
    final dy = (size.height - imageSize.height * scale) / 2;

    for (final h in highlights) {
      final r = Rect.fromLTRB(
        dx + h.box.left * scale - 3,
        dy + h.box.top * scale - 3,
        dx + h.box.right * scale + 3,
        dy + h.box.bottom * scale + 3,
      );
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
      canvas.drawRRect(rr, Paint()..color = h.color.withValues(alpha: h.selected ? 0.30 : 0.16));
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h.selected ? 2.5 : 1.5
          ..color = h.color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter old) =>
      old.imageSize != imageSize || old.highlights != highlights;
}
