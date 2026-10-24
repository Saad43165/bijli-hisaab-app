import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/navigation/app_nav.dart';
import '../../shared/widgets/app_nav_bar.dart';
import '../appliances/appliances_screen.dart';
import '../bills/history_screen.dart';
import '../settings/tools_screen.dart';
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
  }

  @override
  void dispose() {
    AppNav.tab.removeListener(_onTab);
    super.dispose();
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
