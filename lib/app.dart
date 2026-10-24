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
import 'core/navigation/app_nav.dart';

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
      navigatorKey: AppNav.navigatorKey,
      home: const _RootGate(),
    );
  }
}

/// Decides between splash, onboarding and the main app.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  /// The splash stays up at least this long on a cold start so its short
  /// intro can finish; loading usually takes about as long anyway.
  static const _minSplash = Duration(milliseconds: 1200);

  bool _introDone = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_minSplash, () {
      if (mounted) setState(() => _introDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final Widget child;
    if ((state.loading && !state.hasTariff) || !_introDone) {
      child = const _Splash(key: ValueKey('splash'));
    } else if (state.error != null) {
      child = _ErrorView(key: const ValueKey('error'), message: state.error!);
    } else if (!state.onboardingDone) {
      child = const OnboardingScreen(key: ValueKey('onboarding'));
    } else {
      child = const HomeShell(key: ValueKey('home'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: child);
  }
}

/// Picks up where the Android splash leaves off: the same dial mark at the
/// same size and place on the same navy, so there is no jump. Then a soft
/// glow, the name in both languages, the tagline and the credit come in.
class _Splash extends StatefulWidget {
  const _Splash({super.key});

  /// Matches the mark in the native splash_icon (about 126 dp wide).
  static const double markSize = 148;

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Part of the intro between [from] and [to] (0–1), eased.
  Animation<double> _part(double from, double to) =>
      CurvedAnimation(parent: _c, curve: Interval(from, to, curve: Curves.easeOutCubic));

  Widget _rise(Animation<double> a, Widget child) => AnimatedBuilder(
        animation: a,
        builder: (context, child) => Opacity(
          opacity: a.value,
          child: Transform.translate(offset: Offset(0, 14 * (1 - a.value)), child: child),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glow = _part(0, 0.6);
    final name = _part(0.15, 0.6);
    final tagline = _part(0.35, 0.8);
    final footer = _part(0.55, 1);
    final faint = Colors.white.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Soft amber light behind the mark.
          AnimatedBuilder(
            animation: glow,
            builder: (context, _) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.75,
                  colors: [
                    Color.lerp(AppColors.navy, AppColors.navySoft, glow.value)!,
                    AppColors.navy,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: glow,
              builder: (context, child) => Container(
                width: _Splash.markSize * 1.6,
                height: _Splash.markSize * 1.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.amber.withValues(alpha: 0.16 * glow.value),
                      blurRadius: 90,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: child,
              ),
              child: const Image(
                image: AssetImage(Art.brandBolt),
                width: _Splash.markSize,
                height: _Splash.markSize,
              ),
            ),
          ),
          // Name, tagline and a slim loading line under the mark.
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: _Splash.markSize + 120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _rise(
                    name,
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        UrduText(
                          AppConstants.appNameUrdu,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(color: AppColors.amber),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _rise(
                    tagline,
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Your units. Your slab. Your bill.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: faint, letterSpacing: 0.2),
                        ),
                        UrduText(
                          'آپ کے یونٹ۔ آپ کا سلیب۔ آپ کا بل۔',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: faint),
                        ),
                        const SizedBox(height: 22),
                        const _LoadingLine(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Credit.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 28),
              child: FadeTransition(
                opacity: footer,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 28, height: 2, color: AppColors.amber.withValues(alpha: 0.8)),
                    const SizedBox(height: 12),
                    Text(
                      'By SAAD IKRAM',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A short amber line sliding along a faint track while the app loads.
class _LoadingLine extends StatefulWidget {
  const _LoadingLine();

  @override
  State<_LoadingLine> createState() => _LoadingLineState();
}

class _LoadingLineState extends State<_LoadingLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const width = 96.0;
    const segment = 32.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: width,
        height: 3,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.12)),
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) => Positioned(
                left: -segment + (width + segment) * Curves.easeInOut.transform(_c.value),
                width: segment,
                top: 0,
                bottom: 0,
                child: child!,
              ),
              child: Container(color: AppColors.amber),
            ),
          ],
        ),
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
