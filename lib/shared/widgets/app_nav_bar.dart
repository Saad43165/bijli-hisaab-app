import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

class AppNavItem {
  const AppNavItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Floating bottom bar. Every tab has the same width, the icon on top and
/// the full name underneath (shrunk to fit, never cut off — also in Urdu).
/// The selected tab gets an amber pill behind its icon.
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
        height: 68,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 4),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              width: selected ? 56 : 36,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.amber.withValues(alpha: p.isDark ? 0.22 : 0.38) : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
                    color: fg,
                    fontSize: 11.5,
                    letterSpacing: 0,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  child: Text(item.label, maxLines: 1, softWrap: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
