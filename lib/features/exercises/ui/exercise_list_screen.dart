import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../db/app_database.dart';
import '../data/exercise_repository.dart';
import '../providers/exercise_providers.dart';
import 'exercise_info_sheet.dart';

class ExerciseListScreen extends ConsumerStatefulWidget {
  const ExerciseListScreen({super.key});

  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  // Owned here (rather than left implicit on the TextField) so the
  // no-search-results empty state can offer a real "Clear search" CTA that
  // actually empties the visible box, not just the provider behind it.
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(exerciseSearchQueryProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(exerciseSearchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(filteredExercisesProvider);
    final query = ref.watch(exerciseSearchQueryProvider).trim();

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
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                      ),
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
                if (rows.isEmpty && query.isNotEmpty) {
                  // A search that matched nothing is a different situation
                  // from an empty library: telling the user to "add the
                  // movements you train" when they have fifty of them and
                  // simply mistyped one is wrong, and the useful next
                  // action is to widen the search, not to create.
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No matches',
                    message:
                        'Nothing in your library matches "$query". Try a shorter '
                        'search, or create this exercise.',
                    actionLabel: 'Clear search',
                    onAction: _clearSearch,
                  );
                }
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
