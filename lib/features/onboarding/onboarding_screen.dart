import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/companies.dart';
import '../../core/theme/app_colors.dart';
import '../../services/online_bill_service.dart';
import '../../shared/widgets/art.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/hero_style.dart';
import '../../shared/widgets/loading_button.dart';
import '../../shared/widgets/unofficial_notice.dart';
import '../../shared/widgets/urdu_text.dart';
import '../../state/app_state.dart';
import '../meters/widgets/bill_lookup.dart';
import '../meters/widgets/meter_form.dart';
import '../settings/backup_screen.dart';
import '../../core/l10n/l10n.dart';

enum _Stage { find, found, manual }

/// First run in one step: type the reference number, we find the company and
/// the bill, show it, done. Filling in by hand is the fallback.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<MeterFormState>();
  _Stage _stage = _Stage.find;
  bool _busy = false;
  bool _consent = false;
  PowerCompany? _company;
  OnlineBill? _bill;

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await context.read<AppState>().setupFromOnlineBill(_company!, _bill!, analyticsConsent: _consent);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: {0}'.trf({'0': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishManual() async {
    final result = _formKey.currentState?.submit();
    if (result == null) return;
    final state = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await state.completeOnboarding(
        meter: result.meter,
        analyticsConsent: _consent,
        lastReading: result.reading,
        lastReadingDate: result.readingDate,
      );
      if (result.onlineBill != null) await state.importOnlineBill(result.onlineBill!);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: {0}'.trf({'0': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return PopScope(
      canPop: _stage == _Stage.find,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _stage = _Stage.find);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 0),
                child: Row(
                  children: [
                    if (_stage != _Stage.find)
                      IconButton(
                        tooltip: 'Back'.tr,
                        onPressed: _busy ? null : () => setState(() => _stage = _Stage.find),
                        icon: const BackButtonIcon(),
                      ),
                    const Spacer(),
                    SegmentedButton<String>(
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('English')),
                        ButtonSegment(value: 'ur', label: Text('اردو')),
                      ],
                      selected: {state.language},
                      onSelectionChanged: (s) => state.setLanguage(s.first),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: switch (_stage) {
                    _Stage.find => _findPage(context),
                    _Stage.found => _foundPage(context),
                    _Stage.manual => _manualPage(context),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _findPage(BuildContext context) {
    final theme = Theme.of(context);
    final h = HeroStyle.of(context);
    return ListView(
      key: const ValueKey('find'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: h.gradient),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                  child: const ArtImage(Art.brandBolt, size: 48),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppConstants.appName, style: theme.textTheme.headlineSmall?.copyWith(color: h.fg)),
                      UrduText(
                        AppConstants.appNameUrdu,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: h.dark ? AppColors.amber : AppColors.amberDeep,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your bill, history and due date — in one place'.tr,
                        style: theme.textTheme.bodySmall?.copyWith(color: h.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('Find your bill'.tr, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Type the 14-digit reference number from the top of your electricity bill. We\'ll find your company and bills.'
              .tr,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        ReferenceLookup(
          onFound: (c, b) => setState(() {
            _company = c;
            _bill = b;
            _stage = _Stage.found;
          }),
        ),
        const SizedBox(height: 10),
        Text(
          'Works for LESCO, IESCO, FESCO, GEPCO, MEPCO, PESCO, HAZECO, TESCO, HESCO, SEPCO and QESCO.'.tr,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or'.tr, style: theme.textTheme.labelMedium),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() => _stage = _Stage.manual),
          icon: const Icon(Icons.edit_note_rounded),
          label: Text('K-Electric, or no reference number? Set up by hand'.tr, textAlign: TextAlign.center),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const BackupScreen(restoreOnly: true))),
          icon: const Icon(Icons.restore_rounded, size: 20),
          label: Text('Have a backup? Restore it'.tr),
        ),
        const SizedBox(height: 16),
        const UnofficialNotice(),
      ],
    );
  }

  Widget _foundPage(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey('found'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        FadeSlideIn(
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppPalette.of(context).safe, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text('Found your bill'.tr, style: theme.textTheme.headlineSmall)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          index: 1,
          child: FoundBillCard(company: _company!, bill: _bill!),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          index: 2,
          child: Text(
            'We\'ll save these bills, remind you before the due date and check for your next bill by ourselves.'.tr,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _consent,
          onChanged: (v) => setState(() => _consent = v ?? false),
          title: Text('Allow anonymous data export (optional)'.tr, style: theme.textTheme.bodySmall),
        ),
        const SizedBox(height: 8),
        LoadingButton(loading: _busy, onPressed: _start, label: 'Start'.tr, icon: Icons.bolt_rounded),
        TextButton(onPressed: _busy ? null : () => setState(() => _stage = _Stage.find), child: Text('Not my bill'.tr)),
      ],
    );
  }

  Widget _manualPage(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey('manual'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text('Add your meter'.tr, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Keep your latest bill nearby — most of this is printed on it.'.tr,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        MeterForm(key: _formKey, askForReading: true),
        const SizedBox(height: 20),
        LoadingButton(loading: _busy, onPressed: _finishManual, label: 'Start'.tr, icon: Icons.bolt_rounded),
      ],
    );
  }
}
