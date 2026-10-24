import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/navigation/app_nav.dart';
import '../../services/notification_service.dart';
import '../../services/reminders/reminder_planner.dart';
import '../../shared/widgets/app_nav_bar.dart';
import '../../state/app_state.dart';
import '../appliances/appliances_screen.dart';
import '../bills/history_screen.dart';
import '../readings/add_reading_screen.dart';
import '../settings/tools_screen.dart';
import '../settings/widgets/notification_permission.dart';
import 'dashboard_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int get _index => AppNav.tab.value;

  /// Tabs are built the first time they're opened, not all at start-up, and
  /// hidden tabs don't run animations.
  final Set<int> _opened = {0};

  void _select(int i) => AppNav.tab.value = i;

  /// Tabs can also be switched by the assistant (AppNav.goTab).
  void _onTab() => setState(() => _opened.add(_index));

  @override
  void initState() {
    super.initState();
    AppNav.tab.value = 0;
    AppNav.tab.addListener(_onTab);
    NotificationService.instance.tapped.addListener(_onNotificationTap);
    // Taps on the home-screen widgets ("+ Add reading", or the widget itself).
    _widgetTaps = HomeWidget.widgetClicked.listen(_onWidgetTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The app may have been opened by tapping a notification or a widget.
      _onNotificationTap();
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetTap, onError: (_) {});
      _askForNotificationsOnce();
    });
  }

  @override
  void dispose() {
    AppNav.tab.removeListener(_onTab);
    NotificationService.instance.tapped.removeListener(_onNotificationTap);
    _widgetTaps?.cancel();
    super.dispose();
  }

  StreamSubscription<Uri?>? _widgetTaps;

  void _onWidgetTap(Uri? uri) {
    if (uri == null || !mounted) return;
    AppNav.goTab(0);
    if (uri.host == 'add_reading') AppNav.push(const AddReadingScreen());
  }

  static const _askedFlag = 'notification_prompt_shown';

  /// First visit to Home after setup: explain, then ask (Android 13+).
  Future<void> _askForNotificationsOnce() async {
    final state = context.read<AppState>();
    if (state.uiFlag(_askedFlag) || !state.remindersEnabled) return;
    if (await NotificationService.instance.notificationsAllowed) return;
    await state.setUiFlag(_askedFlag, true);
    if (mounted) await NotificationPermission.ensure(context);
  }

  /// Opens the screen a tapped notification is about.
  void _onNotificationTap() {
    final payload = NotificationService.instance.tapped.value;
    if (payload == null) return;
    NotificationService.instance.tapped.value = null;
    final type = ReminderType.values.where((t) => t.name == payload).firstOrNull;
    switch (type) {
      case ReminderType.readingDay || ReminderType.noReading || ReminderType.closeToSlab:
        AppNav.goTab(0);
        AppNav.push(const AddReadingScreen());
      case ReminderType.billDue:
        AppNav.goTab(1);
      case ReminderType.weeklySummary || ReminderType.peakHours:
        AppNav.goTab(0);
      case null:
        if (payload == NotificationService.slabPayload) {
          AppNav.goTab(0);
        }
    }
  }

  Widget _tab(int i, Widget Function() build) => TickerMode(
        enabled: i == _index,
        child: _opened.contains(i) ? build() : const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _tab(0, () => DashboardScreen(onOpenTab: _select)),
          _tab(1, () => const HistoryScreen()),
          _tab(2, () => const AppliancesScreen()),
          _tab(3, () => ToolsScreen(onOpenTab: _select)),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        index: _index,
        onSelect: _select,
        items: [
          AppNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'.tr),
          AppNavItem(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart_rounded, label: 'History'.tr),
          AppNavItem(icon: Icons.kitchen_outlined, selectedIcon: Icons.kitchen_rounded, label: 'Appliances'.tr),
          AppNavItem(icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: 'Tools'.tr),
        ],
      ),
    );
  }
}
