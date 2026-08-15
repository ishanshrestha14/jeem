import 'package:go_router/go_router.dart';

import '../features/exercises/ui/exercise_editor_screen.dart';
import '../features/exercises/ui/exercise_list_screen.dart';
import '../features/sessions/ui/active_session_screen.dart';
import '../features/templates/ui/home_screen.dart';
import '../features/templates/ui/template_editor_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const HomeScreen(),
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
      builder: (_, _) => const ActiveSessionScreen(),
    ),
  ],
);
