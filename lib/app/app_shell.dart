import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/semantic_colors.dart';

/// Hosts the four primary destinations (Workouts / Exercises / History /
/// Settings) behind a [StatefulShellRoute.indexedStack] so each tab keeps
/// its own navigation stack and scroll position across tab switches.
///
/// The bottom nav is hand-built rather than a Material [NavigationBar]: the
/// design system (docs/design/gymflow-design-system.md) explicitly bans the
/// stock pill/blob selection indicator that `NavigationBar` renders by
/// default. Selection here is shown purely by colour (chalk vs muted) plus a
/// 2px chalk rule directly above the selected item's icon.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _AppNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          // Tapping the already-selected tab returns it to its initial
          // location (e.g. pops any local navigation) rather than a no-op.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _destinations = [
  _NavDestination(
    icon: Icons.fitness_center_outlined,
    selectedIcon: Icons.fitness_center,
    label: 'Workouts',
  ),
  _NavDestination(
    icon: Icons.list_alt_outlined,
    selectedIcon: Icons.list_alt,
    label: 'Exercises',
  ),
  _NavDestination(
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
    label: 'History',
  ),
  _NavDestination(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: 'Settings',
  ),
];

class _AppNavigationBar extends StatelessWidget {
  const _AppNavigationBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    return DecoratedBox(
      // A 1px hairline TOP border, not a Material elevation shadow.
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: semantic.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: _destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final color = selected ? AppTheme.chalk : semantic.muted;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        // Each destination clears 48dp; this stretches to the full 58dp bar.
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2px chalk rule above the icon — the sole selection signal,
              // in place of a pill/blob indicator.
              SizedBox(
                height: 2,
                width: 24,
                child: selected
                    ? const DecoratedBox(
                        decoration: BoxDecoration(color: AppTheme.chalk),
                      )
                    : null,
              ),
              const SizedBox(height: 6),
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                destination.label.toUpperCase(),
                style: AppTheme.columnHeader.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
