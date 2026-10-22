import 'package:flutter/material.dart';

import '../../core/constants/companies.dart';

/// Company logo if one is bundled in assets/images/companies/, otherwise a
/// clean coloured badge with the company code.
class CompanyBadge extends StatelessWidget {
  const CompanyBadge(this.company, {super.key, this.size = 44});

  final PowerCompany company;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);
    final inset = size * 0.06;
    final px = ((size - inset * 2) * MediaQuery.devicePixelRatioOf(context)).round();
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Logos sit on a white tile so they read the same in light and dark mode.
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: dark ? null : Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Image.asset(
        company.logoAsset,
        cacheWidth: px,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        // No logo bundled: full-size coloured badge instead of the tile.
        errorBuilder: (_, _, _) => Transform.scale(
          scale: size / (size - inset * 2),
          child: _Fallback(company: company, size: size, radius: radius),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.company, required this.size, required this.radius});

  final PowerCompany company;
  final double size;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final c = company.color;
    final text = company.shortCode;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(c, Colors.white, 0.12)!, Color.lerp(c, Colors.black, 0.18)!],
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(size * 0.1),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * (text.length <= 3 ? 0.34 : 0.26),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
