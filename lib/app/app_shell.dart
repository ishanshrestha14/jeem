import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/semantic_colors.dart';
import '../features/sessions/ui/widgets/workout_in_progress_bar.dart';

/// Hosts the five primary destinations (Home / Explore / Workout / Library /
/// You) — the navigation shape recorded in ADR-005.
/// behind a [StatefulShellRoute.indexedStack] so each tab keeps its own
/// navigation stack and scroll position across tab switches.
///
/// A live session shows a [WorkoutInProgressBar] directly above the nav
/// (CMP-001). It sits inside the `bottomNavigationBar` slot rather than in the
/// body so it occupies layout on every tab at once — each branch keeps its own
/// scroll view, and putting the bar in the body would mean every one of them
/// needing to reserve space for it.
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WorkoutInProgressBar(),
          _AppNavigationBar(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) => navigationShell.goBranch(
              index,
              // Tapping the already-selected tab returns it to its initial
              // location (e.g. pops any local navigation) rather than a no-op.
              initialLocation: index == navigationShell.currentIndex,
            ),
          ),
        ],
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
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
  ),
  _NavDestination(
    icon: Icons.search,
    selectedIcon: Icons.search,
    label: 'Explore',
  ),
  // A circled "+" rather than a dumbbell: training is the app's create
  // action, and the middle slot is the one the thumb reaches first.
  _NavDestination(
    icon: Icons.add_circle_outline,
    selectedIcon: Icons.add_circle,
    label: 'Workout',
  ),
  _NavDestination(
    icon: Icons.view_week_outlined,
    selectedIcon: Icons.view_week,
    label: 'Library',
  ),
  _NavDestination(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'You',
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
              // Five destinations leave roughly 64dp per label on a narrow
              // phone, and the longest ("WORKOUT", letter-spaced) does not
              // always fit. Unconstrained it wrapped to a second line and
              // overflowed the 58dp bar. `scaleDown` shrinks the label only
              // when it has to — wide screens render at full size, and a
              // slightly smaller label beats both a wrapped one and an
              // ellipsised one.
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label.toUpperCase(),
                      maxLines: 1,
                      softWrap: false,
                      style: AppTheme.columnHeader.copyWith(color: color),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
