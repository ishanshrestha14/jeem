import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/exercises/ui/exercise_editor_screen.dart';
import '../features/exercises/ui/exercise_list_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Workouts')),
        body: const SizedBox.shrink(),
      ),
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
  ],
);
