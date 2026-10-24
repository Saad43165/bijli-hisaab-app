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
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/usage_forecaster.dart';
import '../../../shared/widgets/art.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../state/app_state.dart';
import '../../../core/l10n/l10n.dart';

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
  bool _light = false;

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
          text: '{0}: {1} units so far this month, heading for {2}. Estimated bill {3}. — Bijli Hisaab'.trf({'0': meterName, '1': Fmt.whole(s.unitsUsed), '2': Fmt.whole(s.projectedUnits), '3': Fmt.rs(s.estimateProjected.total)}),
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Couldn\'t share: {0}'.trf({'0': e}));
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
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Add two readings this month to share your usage.'.tr),
        ),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Share this month'.tr, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Send a picture of your usage to family or your landlord.'.tr, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Center(
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, icon: const Icon(Icons.dark_mode_rounded), label: Text('Dark'.tr)),
                  ButtonSegment(value: true, icon: const Icon(Icons.light_mode_rounded), label: Text('Light'.tr)),
                ],
                selected: {_light},
                onSelectionChanged: (v) => setState(() => _light = v.first),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: FittedBox(
                child: RepaintBoundary(
                  key: _boundary,
                  child: SummaryPicture(
                    summary: s,
                    meterName: meter.name,
                    company: PowerCompanies.of(meter.disco).shortCode,
                    light: _light,
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
              label: Text('Share picture'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picture itself: 360×450 logical pixels (1080×1350 when shared),
/// every label in English with Urdu under it. Laid out the same on every
/// phone: no text scaling, left to right, big numbers shrink to fit.
class SummaryPicture extends StatelessWidget {
  const SummaryPicture({
    super.key,
    required this.summary,
    required this.meterName,
    required this.company,
    this.light = false,
  });

  /// White and amber instead of the dark navy card.
  final bool light;

  final CycleSummary summary;
  final String meterName;
  final String company;

  static const width = 360.0;
  static const height = 450.0;

  static const _en = AppTheme.fontFamily;
  static const _ur = AppTheme.urduFontFamily;

  static (String, String) _statusText(UsageStatus s) => switch (s) {
        UsageStatus.safe => ('On track', 'ٹھیک ہے'),
        UsageStatus.warn => ('Close to limit', 'حد کے قریب'),
        UsageStatus.danger => ('Will cross', 'حد پار ہوگی'),
        UsageStatus.overLimits => ('Highest slab', 'سب سے اونچا سلیب'),
        UsageStatus.noData => ('', ''),
      };

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final base = StatusStyle.of(context, s.status);
    final style = light ? base : base.onNavy();
    final fg = light ? AppColors.navy : Colors.white;
    final muted = fg.withValues(alpha: light ? 0.62 : 0.68);
    final target = s.targetLimit;
    final progress = target == null || target == 0 ? 1.0 : (s.unitsUsed / target).clamp(0.0, 1.0);
    final projectedFrac = target == null || target == 0 ? 1.0 : (s.projectedUnits / target).clamp(0.0, 1.0);
    final barColor = s.status == UsageStatus.safe ? AppColors.amber : style.color;

    TextStyle en(double size, {Color? color, FontWeight weight = FontWeight.w500, double height = 1.2}) =>
        TextStyle(fontFamily: _en, fontSize: size, color: color ?? fg, fontWeight: weight, height: height);
    TextStyle ur(double size, {Color? color}) =>
        TextStyle(fontFamily: _ur, fontSize: size, color: color ?? muted, height: 1.55);

    /// English line with its Urdu line under it.
    Widget bi(String english, String urdu, {double size = 10, Color? color, CrossAxisAlignment align = CrossAxisAlignment.start}) =>
        Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(english, maxLines: 1, overflow: TextOverflow.ellipsis, style: en(size, color: color ?? muted, weight: FontWeight.w600)),
            Text(urdu, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: ur(size, color: color)),
          ],
        );

    /// A number that shrinks instead of being cut off.
    Widget fit(String text, TextStyle st) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(text, maxLines: 1, style: st),
        );

    Widget stat(String label, String urdu, String value, {Color? color}) => Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bi(label, urdu, size: 9.5),
                const SizedBox(height: 2),
                fit(value, en(18, color: color, weight: FontWeight.w800)),
              ],
            ),
          ),
        );

    final (statusEn, statusUr) = _statusText(s.status);
    final cycle = '${Fmt.dayShort(s.cycleStart)} – ${Fmt.dayShort(s.cycleEnd.subtract(const Duration(days: 1)))}';

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: light ? const [Color(0xFFFFF4CC), Color(0xFFFFFFFF)] : const [Color(0xFF1B2F4E), AppColors.navy],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const ArtImage(Art.brandBolt, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bijli Hisaab', style: en(15, weight: FontWeight.w800)),
                        Text('بجلی حساب', textDirection: TextDirection.rtl, style: ur(10.5)),
                      ],
                    ),
                  ),
                  if (statusEn.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(9, 3, 9, 1),
                      decoration: BoxDecoration(
                        color: style.color.withValues(alpha: light ? 0.14 : 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: bi(statusEn, statusUr, size: 9.5, color: style.color, align: CrossAxisAlignment.center),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('$meterName · $company', maxLines: 1, overflow: TextOverflow.ellipsis, style: en(11.5, color: muted)),
              Text('$cycle · day ${s.dayOfCycle} of ${s.daysTotal}', maxLines: 1, style: en(10.5, color: muted)),
              const SizedBox(height: 10),
              bi('Units used', 'استعمال شدہ یونٹ', size: 10),
              SizedBox(
                height: 62,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: fit(Fmt.whole(s.unitsUsed), en(56, weight: FontWeight.w800, height: 1))),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: target == null
                          ? bi('units', 'یونٹ', size: 12)
                          : bi('of $target units', '$target یونٹ میں سے', size: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 11,
                  child: Stack(
                    children: [
                      Container(color: fg.withValues(alpha: light ? 0.08 : 0.10)),
                      FractionallySizedBox(
                        widthFactor: projectedFrac,
                        child: Container(color: barColor.withValues(alpha: 0.30)),
                      ),
                      FractionallySizedBox(widthFactor: progress, child: Container(color: barColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              bi('Heading for ~${Fmt.whole(s.projectedUnits)} units by month end',
                  'مہینے کے آخر تک تقریباً ${Fmt.whole(s.projectedUnits)} یونٹ', size: 9.5),
              const SizedBox(height: 12),
              Row(
                children: [
                  stat('Per day', 'روزانہ', Fmt.oneDp(s.dailyRate)),
                  stat('Days left', 'باقی دن', '${s.daysLeft}'),
                  stat('Estimated bill', 'متوقع بل', Fmt.rs(s.estimateProjected.total),
                      color: s.status == UsageStatus.safe ? null : style.color),
                ],
              ),
              const Spacer(),
              if (s.safeDailyBudget != null && target != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: light ? 0.06 : 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      fit('Stay under $target: max ${Fmt.oneDp(s.safeDailyBudget!)} units a day',
                          en(12, weight: FontWeight.w700)),
                      Text(
                        '$target سے نیچے رہنے کے لیے روزانہ زیادہ سے زیادہ ${Fmt.oneDp(s.safeDailyBudget!)} یونٹ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: ur(10.5, color: fg),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              bi('Know your bill, save electricity · NEPRA rates, FCA & GST',
                  'اپنا بل جانیں، بجلی بچائیں · نیپرا ریٹ، ایف سی اے اور جی ایس ٹی', size: 9),
            ],
          ),
        ),
      ),
    );
  }
}
