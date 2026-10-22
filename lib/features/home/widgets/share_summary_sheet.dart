import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/companies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/art.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../state/app_state.dart';

/// Preview of this month's usage as a picture, shared to WhatsApp etc.
class ShareSummarySheet extends StatefulWidget {
  const ShareSummarySheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const ShareSummarySheet(),
      );

  @override
  State<ShareSummarySheet> createState() => _ShareSummarySheetState();
}

class _ShareSummarySheetState extends State<ShareSummarySheet> {
  final _boundary = GlobalKey();
  bool _sharing = false;

  Future<void> _share(CycleSummary s, String meterName) async {
    setState(() => _sharing = true);
    try {
      final box = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await box.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (png == null) throw StateError('Could not draw the picture');
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'bijli_hisaab_${DateTime.now().millisecondsSinceEpoch}.png'));
      await file.writeAsBytes(png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: '$meterName: ${Fmt.whole(s.unitsUsed)} units so far this month, heading for '
              '${Fmt.whole(s.projectedUnits)}. Estimated bill ${Fmt.rs(s.estimateProjected.total)}. '
              '— Bijli Hisaab',
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Couldn\'t share: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.summary;
    final meter = state.activeMeter;
    final theme = Theme.of(context);
    if (s == null || !s.hasData || meter == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Add two readings this month to share your usage.'),
        ),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Share this month', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Send a picture of your usage to family or your landlord.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            Center(
              child: FittedBox(
                child: RepaintBoundary(
                  key: _boundary,
                  child: SummaryPicture(
                    summary: s,
                    meterName: meter.name,
                    company: PowerCompanies.of(meter.disco).shortCode,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _sharing ? null : () => _share(s, meter.name),
              icon: _sharing
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy))
                  : const Icon(Icons.share_rounded),
              label: const Text('Share picture'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picture itself: 360×450 logical pixels (1080×1350 when shared).
class SummaryPicture extends StatelessWidget {
  const SummaryPicture({super.key, required this.summary, required this.meterName, required this.company});

  final CycleSummary summary;
  final String meterName;
  final String company;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final theme = Theme.of(context);
    final style = StatusStyle.of(context, s.status).onNavy();
    final muted = Colors.white.withValues(alpha: 0.65);
    final target = s.targetLimit;
    final progress = target == null || target == 0 ? 1.0 : (s.unitsUsed / target).clamp(0.0, 1.0);
    final projectedFrac = target == null || target == 0 ? 1.0 : (s.projectedUnits / target).clamp(0.0, 1.0);
    final barColor = s.status == UsageStatus.safe ? AppColors.amber : style.color;

    Widget stat(String label, String value, {Color? color}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: muted, fontSize: 10)),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.titleMedium?.copyWith(color: color ?? Colors.white)),
            ],
          ),
        );

    return Container(
      width: 360,
      height: 450,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2F4E), AppColors.navy],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ArtImage(Art.brandBolt, size: 30),
              const SizedBox(width: 8),
              Text('Bijli Hisaab', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
              const Spacer(),
              StatusPill(status: s.status, onDark: true),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            '$meterName · $company',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          Text(
            '${Fmt.dayShort(s.cycleStart)} – ${Fmt.dayShort(s.cycleEnd.subtract(const Duration(days: 1)))}'
            ' · day ${s.dayOfCycle} of ${s.daysTotal}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.whole(s.unitsUsed),
                style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, fontSize: 64, height: 1),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  target == null ? 'units used' : 'of $target units',
                  style: theme.textTheme.titleMedium?.copyWith(color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.10)),
                  FractionallySizedBox(
                    widthFactor: projectedFrac,
                    child: Container(color: barColor.withValues(alpha: 0.30)),
                  ),
                  FractionallySizedBox(widthFactor: progress, child: Container(color: barColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              stat('PER DAY', Fmt.oneDp(s.dailyRate)),
              stat('MONTH END', '~${Fmt.whole(s.projectedUnits)}',
                  color: s.status == UsageStatus.safe ? null : style.color),
              stat('EST. BILL', Fmt.rs(s.estimateProjected.total)),
            ],
          ),
          const Spacer(),
          if (s.safeDailyBudget != null && target != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Stay under $target: max ${Fmt.oneDp(s.safeDailyBudget!)} units a day for ${s.daysLeft} days',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Estimate with NEPRA rates, FCA and GST',
            style: theme.textTheme.bodySmall?.copyWith(color: muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
