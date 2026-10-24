import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Urdu in Noto Nastaliq, right-to-left, with the extra line height
/// Nastaliq needs so ascenders/descenders don't clip.
class UrduText extends StatelessWidget {
  const UrduText(this.text, {super.key, this.style, this.textAlign = TextAlign.end});

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium!;
    return Text(
      text,
      textDirection: TextDirection.rtl,
      textAlign: textAlign,
      style: base
          .merge(style)
          .copyWith(fontFamily: AppTheme.urduFontFamily, height: 2.0, fontWeight: FontWeight.w400),
    );
  }
}
