import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

class AppNavItem {
  const AppNavItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Floating bottom bar: the selected tab is an amber pill with icon + name,
/// the others are icons with a small name underneath. Compact, works in
/// right-to-left (Urdu) because it's a plain Row.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.items, required this.index, required this.onSelect});

  final List<AppNavItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.border.withValues(alpha: p.isDark ? 1 : 0.7)),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: p.isDark ? 0.35 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                flex: i == index ? 14 : 10,
                child: _Item(
                  item: items[i],
                  selected: i == index,
                  onTap: () {
                    if (i != index) HapticFeedback.selectionClick();
                    onSelect(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.selected, required this.onTap});

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPalette.of(context);
    final fg = selected ? (p.isDark ? AppColors.amber : AppColors.navy) : p.muted;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.amber.withValues(alpha: p.isDark ? 0.18 : 0.30) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: selected
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.selectedIcon, size: 22, color: fg),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: theme.textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 22, color: fg),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: theme.textTheme.labelSmall?.copyWith(color: fg, fontSize: 10.5, letterSpacing: 0, height: 1.2),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
