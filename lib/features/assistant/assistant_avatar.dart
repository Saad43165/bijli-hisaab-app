import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/art.dart';

/// The assistant's face: the app's own bolt on navy, like the app icon, with
/// a small amber spark so it reads as "the helper".
class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, this.size = 36, this.spark = true});

  final double size;
  final bool spark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(size * 0.14),
            decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
            child: ArtImage(Art.brandBolt, size: size * 0.72),
          ),
          if (spark)
            PositionedDirectional(
              end: -size * 0.06,
              top: -size * 0.06,
              child: Container(
                width: size * 0.36,
                height: size * 0.36,
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                ),
                child: Icon(Icons.auto_awesome_rounded, size: size * 0.22, color: AppColors.navy),
              ),
            ),
        ],
      ),
    );
  }
}
