import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../services/bill_ocr_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/hero_style.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/loading_button.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/app_state.dart';
import 'bill_form_screen.dart';
import 'scan_review_screen.dart';
import 'widgets/scanning_overlay.dart';

/// Capture a bill (smart document scanner, camera or gallery), read it on
/// the phone, then open the review screen.
class ScanBillScreen extends StatefulWidget {
  const ScanBillScreen({super.key});

  @override
  State<ScanBillScreen> createState() => _ScanBillScreenState();
}

class _ScanBillScreenState extends State<ScanBillScreen> {
  final _ocr = BillOcrService();
  List<String>? _reading; // image paths being read
  bool _capturing = false;

  Future<void> _start(CaptureSource source) async {
    final state = context.read<AppState>();
    final nav = Navigator.of(context);
    setState(() => _capturing = true);
    try {
      List<String> images;
      try {
        images = await _ocr.capture(source);
      } on SmartScannerUnavailable {
        if (!mounted) return;
        showSnack(context, 'Smart scanner isn\'t available on this phone — opening the camera.');
        images = await _ocr.capture(CaptureSource.camera);
      }
      if (!mounted) return;
      setState(() => _reading = images);
      HapticFeedback.mediumImpact();

      final result = await _ocr.read(images, estimateAmount: state.estimateBillFor, expectedCompany: state.activeMeter?.disco);
      await state.logBillScanned(result.analysis.detectedFields);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      await nav.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ScanReviewScreen(initial: result)),
      );
    } on ScanCancelled {
      // User backed out — nothing to do.
    } catch (e) {
      if (mounted) showSnack(context, 'Couldn\'t read the bill: $e');
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
          _reading = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final smart = state.smartScanner;

    if (_reading != null) {
      return Scaffold(
        backgroundColor: AppColors.navy,
        body: ScanningOverlay(imagePath: _reading!.first, pages: _reading!.length),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan bill')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            AppCard(
              gradient: HeroStyle.of(context).gradient,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Row(
                children: [
                  const ArtImage(Art.camera, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan your bill',
                            style: theme.textTheme.titleLarge?.copyWith(color: HeroStyle.of(context).fg)),
                        const SizedBox(height: 4),
                        Text(
                          smart
                              ? 'Finds the edges, captures, crops and reads it — all on your phone.'
                              : 'Take a clear photo and we\'ll read it on your phone.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: HeroStyle.of(context).muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: _Step(art: Art.receipt, n: 1, text: 'Lay the bill flat in good light')),
                SizedBox(width: 10),
                Expanded(child: _Step(art: Art.camera, n: 2, text: 'Hold steady — it captures itself')),
                SizedBox(width: 10),
                Expanded(child: _Step(art: Art.check, n: 3, text: 'Check the values and save')),
              ],
            ),
            const SizedBox(height: 18),
            LoadingButton(
              label: smart ? 'Start scanning' : 'Take photo',
              icon: Icons.document_scanner_rounded,
              loading: _capturing,
              onPressed: () => _start(smart ? CaptureSource.smartScanner : CaptureSource.camera),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (smart) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _capturing ? null : () => _start(CaptureSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 20),
                      label: const Text('Plain photo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _capturing ? null : () => _start(CaptureSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    label: const Text('From gallery'),
                  ),
                ),
              ],
            ),
            const SectionHeader('Scanner settings'),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: SwitchListTile(
                value: smart,
                onChanged: state.setSmartScanner,
                secondary: const ArtTile(Art.sparkles, size: 40),
                title: Text('Smart scanner', style: theme.textTheme.titleSmall),
                subtitle: const Text(
                  'Auto edge detection and capture, flash on/off, crop and shadow removal. '
                  'Scan up to 2 pages (front and back).',
                ),
              ),
            ),
            const SectionHeader('Tips for a perfect scan'),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: const Column(
                children: [
                  _Tip(icon: Icons.wb_sunny_outlined, text: 'Daylight works best. At night, turn the flash on in the scanner.'),
                  _Tip(icon: Icons.crop_free_rounded, text: 'Fit the whole bill in the frame — the top half has units, amount and due date.'),
                  _Tip(icon: Icons.layers_outlined, text: 'Put the bill on a dark surface so the edges stand out.'),
                  _Tip(icon: Icons.flip_rounded, text: 'Readings are on the back of some bills — scan both sides.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              onTap: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const BillFormScreen()),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ArtTile(Art.memo, size: 40),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Type the bill details instead')),
                  Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.art, required this.n, required this.text});

  final String art;
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        children: [
          ArtImage(art, size: 40),
          const SizedBox(height: 8),
          Text('Step $n', style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(height: 1.3)),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.amberDeep),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
