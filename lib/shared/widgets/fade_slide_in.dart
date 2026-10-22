import 'package:flutter/material.dart';

/// A quick, subtle fade-and-rise when a card first appears. Kept short (the
/// last card is in place within ~0.3 s) so screens never feel slow.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Respect "remove animations" in Android accessibility settings.
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final i = index.clamp(0, 4);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + i * 20),
      curve: Interval(i * 0.06, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
