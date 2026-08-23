import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/ui/home_screen.dart';
import '../features/exercises/ui/exercise_editor_screen.dart';
import '../features/exercises/ui/exercise_list_screen.dart';
import '../features/history/ui/history_screen.dart';
import '../features/sessions/ui/active_session_screen.dart';
import '../features/sessions/ui/session_reorder_screen.dart';
import '../features/sessions/ui/session_summary_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../features/templates/ui/template_editor_screen.dart';
import '../features/templates/ui/workout_screen.dart';
import 'app_shell.dart';

/// Builds a fresh [GoRouter]. A factory (rather than a bare top-level
/// singleton) so tests can get an isolated router per test instead of
/// sharing navigation state through [appRouter] across the whole suite.
///
/// `/home`, `/workout`, `/history`, `/profile` live inside a
/// [StatefulShellRoute.indexedStack] so each tab keeps its own navigation
/// state and scroll position when switching away and back (PRD §16.1/§16.3:
/// the four primary destinations must be thumb-reachable bottom nav, not
/// AppBar corner actions). `/` redirects to `/home` so
/// `initialLocation: '/'` and any existing deep links keep working.
///
/// `/session`, everything under `/templates`, and `/exercises`/`/exercises/...`
/// (list, new, edit) stay OUTSIDE the shell as pushed full-screen routes.
/// The exercise library used to be its own shell branch; it is now reached
/// from the Workout tab's `EXERCISES` header action, because exercises are
/// material for building workouts rather than a peer destination. `/session`
/// in particular must never show the bottom nav (its `bottomNavigationBar`
/// slot is already the rest timer bar, and mid-workout the user needs the
/// fewest possible ways to accidentally tap away). `/session/reorder` is
/// pushed from `/session` for the "machine is occupied" drag-reorder flow
/// and inherits the same no-bottom-nav rule. `/session/summary/:id` is
/// pushed from `/session`'s Finish flow — and, read-only via `?readOnly=true`,
/// from history — to show the finish/detail screen; it stays outside the
/// shell for the same reason.
GoRouter createAppRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          redirect: (_, _) => '/home',
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const HomeScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/workout',
                builder: (_, _) => const WorkoutScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/history',
                builder: (_, _) => const HistoryScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const SettingsScreen(),
              ),
            ]),
          ],
        ),
        GoRoute(
          path: '/exercises',
          builder: (_, _) => const ExerciseListScreen(),
        ),
        GoRoute(
          path: '/exercises/new',
          builder: (_, _) => const ExerciseEditorScreen(),
        ),
        GoRoute(
          path: '/exercises/:id',
          builder: (_, s) =>
              ExerciseEditorScreen(exerciseId: s.pathParameters['id']),
        ),
        GoRoute(
          path: '/templates/new',
          builder: (_, _) => const TemplateEditorScreen(),
        ),
        GoRoute(
          path: '/templates/:id',
          builder: (_, s) =>
              TemplateEditorScreen(templateId: s.pathParameters['id']),
        ),
        GoRoute(
          path: '/session',
          // Slides up from the bottom on entry and back down on exit, so
          // minimising reads as the session collapsing into the
          // Workout-in-Progress bar rather than as navigating backwards.
          // The default horizontal push would imply the session is somewhere
          // you left, not something still running underneath.
          pageBuilder: (_, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: const ActiveSessionScreen(),
            transitionDuration: const Duration(milliseconds: 260),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            transitionsBuilder: (context, animation, _, child) {
              // Honour the platform's reduce-motion setting: the session is
              // entered and left constantly, so this is the single most
              // repeated animation in the app.
              if (MediaQuery.disableAnimationsOf(context)) return child;
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: '/session/reorder',
          builder: (_, _) => const SessionReorderScreen(),
        ),
        GoRoute(
          path: '/session/summary/:id',
          builder: (_, s) => SessionSummaryScreen(
            sessionId: s.pathParameters['id']!,
            readOnly: s.uri.queryParameters['readOnly'] == 'true',
          ),
        ),
      ],
    );

final appRouter = createAppRouter();
