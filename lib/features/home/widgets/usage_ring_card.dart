import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/animated_number.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/hero_style.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../core/l10n/l10n.dart';

/// Navy hero card: units used this cycle in a ring that fills towards the
/// next slab limit, with the projection shown as a faint arc.
class UsageRingCard extends StatelessWidget {
  const UsageRingCard({super.key, required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = HeroStyle.of(context);
    final base = StatusStyle.of(context, summary.status);
    final style = h.dark ? base.onNavy() : base;
    final onNavy = h.fg;
    final onNavyMuted = h.muted;
    final target = summary.targetLimit;
    final projectedFraction = target == null || target == 0
        ? 1.0
        : (summary.projectedUnits / target).clamp(0, 1.0).toDouble();
    final ringColor = summary.status == UsageStatus.safe ? (h.dark ? AppColors.amber : AppColors.amberDeep) : style.color;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      gradient: h.gradient,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Fmt.dayShort(summary.cycleStart)} – '
                  '${Fmt.dayShort(summary.cycleEnd.subtract(const Duration(days: 1)))}',
                  style: theme.textTheme.labelLarge?.copyWith(color: onNavyMuted),
                ),
              ),
              StatusPill(status: summary.status, onDark: h.dark),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 220,
            height: 220,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: summary.progress),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => CustomPaint(
                painter: _RingPainter(
                  progress: value,
                  projected: projectedFraction,
                  color: ringColor,
                  track: h.track,
                  cap: h.dark ? Colors.white : AppColors.navy,
                ),
                child: child,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('USED'.tr, style: theme.textTheme.labelSmall?.copyWith(color: onNavyMuted)),
                    AnimatedNumber(
                      value: summary.unitsUsed,
                      format: Fmt.whole,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 52,
                        color: onNavy,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      target == null ? 'units' : 'of {0} units'.trf({'0': target}),
                      style: theme.textTheme.bodyMedium?.copyWith(color: onNavyMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: h.faint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _Stat(h: h, label: 'DAY'.tr, value: '${summary.dayOfCycle}/${summary.daysTotal}', caption: '{0} left'.trf({'0': summary.daysLeft})),
                _Divider(color: h.track),
                _Stat(h: h, label: 'PER DAY'.tr, value: Fmt.oneDp(summary.dailyRate), caption: 'units avg'.tr),
                _Divider(color: h.track),
                _Stat(
                  h: h,
                  label: 'MONTH END'.tr,
                  value: Fmt.whole(summary.projectedUnits),
                  caption: 'projected'.tr,
                  valueColor: summary.status == UsageStatus.safe ? onNavy : style.color,
                ),
              ],
            ),
          ),
          if (summary.latestReadingDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.speed_rounded, size: 15, color: onNavyMuted),
                const SizedBox(width: 6),
                Text(
                  'Last reading {0} · {1}'.trf({'0': Fmt.whole(summary.latestReadingValue ?? 0), '1': Fmt.dayShort(summary.latestReadingDate!)}),
                  style: theme.textTheme.bodySmall?.copyWith(color: onNavyMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.h, required this.label, required this.value, required this.caption, this.valueColor});

  final HeroStyle h;

  final String label;
  final String value;
  final String caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = h.muted;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: muted, fontSize: 10.5)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(color: valueColor ?? h.fg),
            ),
          ),
          Text(caption, style: theme.textTheme.bodySmall?.copyWith(color: muted, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(width: 1, height: 36, color: color);
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.projected,
    required this.color,
    required this.track,
    required this.cap,
  });

  final double progress;
  final double projected;
  final Color color;
  final Color track;
  final Color cap;

  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 15.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);

    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _start, _sweep, false, arc(track));

    if (projected > progress) {
      canvas.drawArc(rect, _start, _sweep * projected, false, arc(color.withValues(alpha: 0.28)));
    }

    if (progress > 0) {
      canvas.drawArc(rect, _start, _sweep * progress, false, arc(color));

      // Glowing end cap.
      final angle = _start + _sweep * progress;
      final r = rect.width / 2;
      final c = rect.center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      canvas.drawCircle(c, stroke * 0.85, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(c, stroke * 0.32, Paint()..color = cap);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.projected != projected || old.color != color || old.track != track || old.cap != cap;
}
