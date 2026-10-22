import 'package:flutter/material.dart';

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
  int _index = 0;

  /// Tabs are built the first time they're opened, not all at start-up, and
  /// hidden tabs don't run animations.
  final Set<int> _opened = {0};

  void _select(int i) => setState(() {
        _index = i;
        _opened.add(i);
      });

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen_rounded),
            label: 'Appliances',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Tools',
          ),
        ],
      ),
    );
  }
}
