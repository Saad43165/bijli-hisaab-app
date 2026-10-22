import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/loading_button.dart';
import '../../state/app_state.dart';
import '../meters/widgets/meter_form.dart';
import '../settings/backup_screen.dart';
import 'widgets/consent_page.dart';
import 'widgets/welcome_page.dart';
import '../../core/l10n/l10n.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  final _formKey = GlobalKey<MeterFormState>();
  int _index = 0;
  bool _consent = false;
  bool _saving = false;

  static const _count = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) {
    FocusScope.of(context).unfocus();
    _pages.animateToPage(i, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    final result = _formKey.currentState?.submit();
    if (result == null) return;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().completeOnboarding(
            meter: result.meter,
            analyticsConsent: _consent,
            lastReading: result.reading,
            lastReadingDate: result.readingDate,
          );
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _count - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Step {n} of {c}'.trf({'n': _index + 1, 'c': _count}),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(width: 12),
                  for (var i = 0; i < _count; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _index
                              ? AppColors.amber
                              : Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Language first, so Urdu readers can switch before anything else.
            if (_index == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SegmentedButton<String>(
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'ur', label: Text('اردو')),
                    ],
                    selected: {context.watch<AppState>().language},
                    onSelectionChanged: (s) => context.read<AppState>().setLanguage(s.first),
                  ),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  const WelcomePage(),
                  ConsentPage(
                    consent: _consent,
                    onChanged: (v) => setState(() => _consent = v),
                  ),
                  _MeterPage(formKey: _formKey),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_index > 0) ...[
                    SizedBox(
                      width: 110,
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _go(_index - 1),
                        child: Text('Back'.tr),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: LoadingButton(
                      loading: _saving,
                      onPressed: isLast ? _finish : () => _go(_index + 1),
                      label: isLast ? 'Start tracking'.tr : (_index == 0 ? 'Get started'.tr : 'Continue'.tr),
                      icon: isLast ? Icons.bolt_rounded : null,
                    ),
                  ),
                ],
              ),
            ),
            if (_index == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const BackupScreen(restoreOnly: true)),
                  ),
                  icon: const Icon(Icons.restore_rounded, size: 20),
                  label: Text('Have a backup? Restore it'.tr),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MeterPage extends StatelessWidget {
  const _MeterPage({required this.formKey});

  final GlobalKey<MeterFormState> formKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text('Add your meter'.tr, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Keep your latest bill nearby — most of this is printed on it.'.tr,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        MeterForm(key: formKey, askForReading: true),
      ],
    );
  }
}
