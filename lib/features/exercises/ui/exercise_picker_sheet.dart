import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/utils/formatting.dart';
import '../../../db/app_database.dart';
import '../../history/providers/history_providers.dart';
import '../domain/exercise_history.dart';
import '../providers/exercise_providers.dart';
import 'exercise_editor_screen.dart';
import 'exercise_info_sheet.dart';

/// Full-height picker for adding an exercise to a template or a live session.
/// Returns the chosen exercise's id, or null if dismissed without a pick.
///
/// [recentFirst] leads with what you have actually performed, most recent
/// first (S-026). Pass it when adding **mid-session**: what you want then is
/// almost always something you have done before, so recency beats
/// alphabetical. Building a routine is not mid-set, so it stays alphabetical
/// there — a section that appears sometimes is harder to learn than one that
/// appears for a reason.
Future<String?> showExercisePickerSheet(
  BuildContext context, {
  bool recentFirst = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ExercisePickerSheet(recentFirst: recentFirst),
  );
}

class _ExercisePickerSheet extends ConsumerStatefulWidget {
  const _ExercisePickerSheet({this.recentFirst = false});

  final bool recentFirst;

  @override
  ConsumerState<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<_ExercisePickerSheet> {
  // Deliberately local, not `exerciseSearchQueryProvider` — that provider is
  // shared with the standalone Exercise Library screen, and mutating it from
  // here would clobber a filter the user had already typed there.
  String _query = '';

  Future<void> _createExercise(BuildContext context) async {
    final newId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const ExerciseEditorScreen(),
      ),
    );
    if (newId != null && context.mounted) {
      Navigator.of(context).pop(newId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exerciseListProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search exercises',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: exercisesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (allRows) {
                    final query = _query.trim().toLowerCase();
                    final rows = query.isEmpty
                        ? allRows
                        : allRows
                            .where((e) =>
                                e.name.toLowerCase().contains(query))
                            .toList();
                    if (rows.isEmpty) {
                      // Same reasoning as the library screen's
                      // no-search-results state: a search that matched
                      // nothing needs its own icon/title/explanation and a
                      // CTA that moves the user forward. Here the forward
                      // move is creating the exercise they were looking
                      // for, since they are mid-way through building a
                      // template.
                      // Wrapped in a ListView carrying the sheet's own
                      // scrollController: without it, this branch drops the
                      // controller the DraggableScrollableSheet handed us,
                      // and the sheet can no longer be dragged to resize or
                      // dismiss while "no results" is showing.
                      // Wrapped in a ListView carrying the sheet's own
                      // scrollController: without it, this branch drops the
                      // controller the DraggableScrollableSheet handed us,
                      // and the sheet can no longer be dragged to resize or
                      // dismiss while "no results" is showing.
                      return ListView(
                        controller: scrollController,
                        children: [
                          EmptyState(
                            icon: query.isEmpty
                                ? Icons.fitness_center
                                : Icons.search_off,
                            title:
                                query.isEmpty ? 'No exercises yet' : 'No matches',
                            message: query.isEmpty
                                ? 'Add the movements you train so you can drop them '
                                    'into this workout.'
                                : 'Nothing in your library matches "$_query". '
                                    'Create it and it will be added straight to '
                                    'this workout.',
                            actionLabel: 'Create new exercise',
                            onAction: () => _createExercise(context),
                          ),
                        ],
                      );
                    }
                    final bodyParts =
                        ref.watch(bodyPartsByExerciseProvider).valueOrNull ??
                            const <String, List<BodyPart>>{};

                    // Mid-session, lead with what has actually been performed
                    // (S-026). Only while not searching: once you have typed a
                    // query you are looking for a specific thing, and
                    // reordering around recency would fight the search.
                    final recentIds = widget.recentFirst && query.isEmpty
                        ? recentlyPerformedExerciseIds(
                            ref.watch(historyProvider).valueOrNull ?? const [])
                        : const <String>[];
                    final byId = {for (final e in rows) e.id: e};
                    final recent = [
                      for (final id in recentIds)
                        if (byId.containsKey(id)) byId[id]!,
                    ];
                    final rest = [
                      for (final e in rows)
                        if (!recentIds.contains(e.id)) e,
                    ];
                    final sectioned = recent.isEmpty
                        ? <Object>[...rows]
                        : <Object>['Recent', ...recent, 'All exercises', ...rest];

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: sectioned.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return ListTile(
                            leading: const Icon(Icons.add),
                            title: const Text('Create new exercise'),
                            onTap: () => _createExercise(context),
                          );
                        }
                        final item = sectioned[i - 1];
                        if (item is String) {
                          return Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                              item,
                              style: AppTheme.columnHeader.copyWith(
                                color: Theme.of(context)
                                    .extension<SemanticColors>()!
                                    .muted,
                              ),
                            ),
                          );
                        }
                        final exercise = item as Exercise;
                        return ListTile(
                          title: Text(exercise.name),
                          subtitle: Text([
                            if ((bodyParts[exercise.id] ?? const []).isNotEmpty)
                              bodyPartsSubtitle(bodyParts[exercise.id]!),
                            exercise.loggingType == LoggingType.durationOnly
                                ? 'Duration'
                                : 'Strength',
                          ].join(' · ')),
                          onTap: () => Navigator.of(context).pop(exercise.id),
                          trailing: IconButton(
                            icon: const Icon(Icons.info_outline),
                            tooltip: 'Exercise info',
                            onPressed: () => showExerciseInfoSheet(
                              context,
                              name: exercise.name,
                              loggingType: exercise.loggingType,
                              description: exercise.description,
                              notes: exercise.notes,
                              imagePath: exercise.imagePath,
                              equipment: exercise.equipment,
                              exerciseId: exercise.id,
                              isArchived: exercise.isArchived,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
