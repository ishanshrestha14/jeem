import 'package:go_router/go_router.dart';

import '../features/exercises/ui/exercise_editor_screen.dart';
import '../features/exercises/ui/exercise_list_screen.dart';
import '../features/history/ui/history_screen.dart';
import '../features/sessions/ui/active_session_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../features/templates/ui/home_screen.dart';
import '../features/templates/ui/template_editor_screen.dart';
import 'app_shell.dart';

/// Builds a fresh [GoRouter]. A factory (rather than a bare top-level
/// singleton) so tests can get an isolated router per test instead of
/// sharing navigation state through [appRouter] across the whole suite.
///
/// `/workouts`, `/exercises`, `/history`, `/settings` live inside a
/// [StatefulShellRoute.indexedStack] so each tab keeps its own navigation
/// state and scroll position when switching away and back (PRD §16.1/§16.3:
/// the four primary destinations must be thumb-reachable bottom nav, not
/// AppBar corner actions). `/` redirects to `/workouts` so
/// `initialLocation: '/'` and any existing deep links keep working.
///
/// `/session` and everything under `/templates` and `/exercises/...`
/// (new/edit) stay OUTSIDE the shell as pushed full-screen routes — they are
/// tasks, not destinations, and the active session screen in particular must
/// never show the bottom nav (its `bottomNavigationBar` slot is already the
/// rest timer bar, and mid-workout the user needs the fewest possible ways
/// to accidentally tap away).
GoRouter createAppRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          redirect: (_, _) => '/workouts',
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/workouts',
                builder: (_, _) => const HomeScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/exercises',
                builder: (_, _) => const ExerciseListScreen(),
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
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ]),
          ],
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
          builder: (_, _) => const ActiveSessionScreen(),
        ),
      ],
    );

final appRouter = createAppRouter();
