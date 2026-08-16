import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../db/app_database.dart';
import '../data/exercise_repository.dart';
import '../providers/exercise_providers.dart';
import 'exercise_info_sheet.dart';

class ExerciseListScreen extends ConsumerWidget {
  const ExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(filteredExercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/exercises/new'),
        icon: const Icon(Icons.add),
        label: const Text('New exercise'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) =>
                  ref.read(exerciseSearchQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: exercises.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return EmptyState(
                    icon: Icons.fitness_center,
                    title: 'No exercises yet',
                    message:
                        'Add the movements you train so you can drop them into workouts.',
                    actionLabel: 'Create an exercise',
                    onAction: () => context.push('/exercises/new'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _ExerciseTile(exercise: rows[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends ConsumerWidget {
  const _ExerciseTile({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(exercise.name),
      subtitle: Text([
        if (exercise.category != null) exercise.category!,
        exercise.loggingType == LoggingType.durationOnly
            ? 'Duration'
            : 'Strength',
      ].join(' · ')),
      onTap: () => context.push('/exercises/${exercise.id}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Exercise info',
            onPressed: () => showExerciseInfoSheet(
              context,
              name: exercise.name,
              loggingType: exercise.loggingType,
              description: exercise.description,
              notes: exercise.notes,
              imagePath: exercise.imagePath,
              category: exercise.category,
              isArchived: exercise.isArchived,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archive',
            onPressed: () async {
              final repo = ref.read(exerciseRepositoryProvider);
              await repo.archive(exercise.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${exercise.name} archived'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => repo.unarchive(exercise.id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
