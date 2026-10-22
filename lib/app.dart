import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_shell.dart';
import 'shared/widgets/art.dart';
import 'shared/widgets/urdu_text.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'state/app_state.dart';
import './core/l10n/l10n.dart';

class BijliBachaoApp extends StatelessWidget {
  const BijliBachaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild everything when the language changes (text and direction).
    final language = context.select<AppState, String>((s) => s.language);
    return MaterialApp(
      key: ValueKey(language),
      title: AppConstants.appName,
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: context.select<AppState, ThemeMode>((s) => s.themeMode),
      home: const _RootGate(),
    );
  }
}

/// Decides between splash, onboarding and the main app.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final Widget child;
    if (state.loading && !state.hasTariff) {
      child = const _Splash(key: ValueKey('splash'));
    } else if (state.error != null) {
      child = _ErrorView(key: const ValueKey('error'), message: state.error!);
    } else if (!state.onboardingDone) {
      child = const OnboardingScreen(key: ValueKey('onboarding'));
    } else {
      child = const HomeShell(key: ValueKey('home'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: child);
  }
}

/// Picks up where the system splash leaves off: the same mark in the same
/// place, then the name and tagline fade in while the data loads.
class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          const Center(child: Image(image: AssetImage(Art.brandBolt), width: 112, height: 112)),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 200),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 2),
                    UrduText(
                      AppConstants.appNameUrdu,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(color: AppColors.amber),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Text(
                'Your units. Your slab. Your bill.'.tr,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.55)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 56),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.read<AppState>().init(),
                child: Text('Try again'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
