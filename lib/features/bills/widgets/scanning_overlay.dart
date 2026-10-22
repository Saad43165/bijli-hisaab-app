import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/l10n.dart';

/// Full-screen "reading your bill" state: the captured page with a moving
/// scan line while OCR runs.
class ScanningOverlay extends StatefulWidget {
  const ScanningOverlay({super.key, required this.imagePath, required this.pages});

  final String imagePath;
  final int pages;

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            AspectRatio(
              aspectRatio: 0.72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.navySoft),
                    ),
                    ColoredBox(color: AppColors.navy.withValues(alpha: 0.35)),
                    AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) => Align(
                        alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_c.value)),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.amber,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.amber.withValues(alpha: 0.7),
                                blurRadius: 18,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Reading your bill…'.tr,
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              widget.pages > 1
                  ? '{0} pages · finding units, amount and dates'.trf({'0': widget.pages})
                  : 'Finding units, amount and dates'.tr,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              'Nothing leaves your phone'.tr,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
