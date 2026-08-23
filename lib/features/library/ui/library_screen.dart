import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../db/app_database.dart';
import '../../exercises/providers/exercise_providers.dart';
import '../../templates/data/template_models.dart';
import '../../templates/providers/template_providers.dart';

/// The Library tab — "your library": everything you made (S-004).
///
/// Follows the reference layout rather than inventing one: filter chips over a
/// single flat list, where a create row, a Favourites pseudo-item and real
/// items all share one row shape (square tile, title, count subtitle). That
/// sameness is what makes it read as one list instead of a stack of sections.
///
/// Two deliberate departures, both because the model differs, not the design:
///   - **No `Programs` chip.** A program groups routines; our top-level object
///     is the routine, so the chip would filter to nothing.
///   - **Favourites appears only under Exercises.** Exercises carry a
///     favourite flag (T-004); routines do not yet.
enum _LibraryFilter { routines, exercises }

enum _CreateTarget { program, routine, exercise }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _LibraryFilter _filter = _LibraryFilter.routines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your library'),
        actions: [
          // The top-bar `+` is a global create menu, not a shortcut for the
          // selected chip: it offers everything the library can hold, so you
          // do not have to switch filter first just to add the other kind.
          PopupMenuButton<_CreateTarget>(
            icon: const Icon(Icons.add),
            tooltip: 'Add to library',
            onSelected: (target) => _createTarget(target),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _CreateTarget.program,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_view_week_outlined),
                  title: Text('Program'),
                  subtitle: Text('Not built yet'),
                ),
              ),
              const PopupMenuItem(
                value: _CreateTarget.routine,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.list_alt_outlined),
                  title: Text('Routine'),
                ),
              ),
              const PopupMenuItem(
                value: _CreateTarget.exercise,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.fitness_center_outlined),
                  title: Text('Exercise'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final f in _LibraryFilter.values)
                  ChoiceChip(
                    label: Text(_label(f)),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
          ),
          // Section bar. The sort control is present but fixed on "Recent"
          // until there is a second option worth offering — a disabled-looking
          // menu with one entry is worse than a label.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 4),
            child: Row(
              children: [
                Icon(Icons.swap_vert, size: 18, color: semantic.muted),
                const SizedBox(width: 6),
                Text(
                  'Recent',
                  style: AppTheme.columnHeader.copyWith(color: semantic.muted),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filter == _LibraryFilter.routines
                ? _RoutineList(onCreate: _create)
                : _ExerciseList(onCreate: _create),
          ),
        ],
      ),
    );
  }

  String _label(_LibraryFilter f) =>
      f == _LibraryFilter.routines ? 'Routines' : 'Exercises';

  void _create() {
    context.push(_filter == _LibraryFilter.routines
        ? '/templates/new'
        : '/exercises/new');
  }

  void _createTarget(_CreateTarget target) {
    switch (target) {
      case _CreateTarget.routine:
        context.push('/templates/new');
      case _CreateTarget.exercise:
        context.push('/exercises/new');
      case _CreateTarget.program:
        // Listed because the menu is the reference app's, but a program
        // groups routines and we have no object above the routine yet. Saying
        // so beats a menu entry that silently does nothing.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Programs group routines into a plan — not built yet.',
            ),
          ),
        );
    }
  }
}

class _RoutineList extends ConsumerWidget {
  const _RoutineList({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(templateSummariesProvider);
    return summaries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rows) {
        final sorted = [...rows]..sort(_byRecent);
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            LibraryRow(
              tile: const _GlyphTile(icon: Icons.add),
              title: 'Create new routine',
              onTap: onCreate,
            ),
            for (final s in sorted)
              LibraryRow(
                tile: InitialsTile(name: s.template.name),
                title: s.template.name,
                subtitle: '${s.exerciseCount} '
                    '${s.exerciseCount == 1 ? 'exercise' : 'exercises'}',
                onTap: () => context.push('/templates/${s.template.id}'),
              ),
          ],
        );
      },
    );
  }

  /// Most recently performed first; never-performed routines last, since
  /// "Recent" cannot rank what has no date.
  static int _byRecent(TemplateSummary a, TemplateSummary b) {
    final x = a.lastPerformedAt;
    final y = b.lastPerformedAt;
    if (x == null && y == null) return a.template.name.compareTo(b.template.name);
    if (x == null) return 1;
    if (y == null) return -1;
    return y.compareTo(x);
  }
}

class _ExerciseList extends ConsumerWidget {
  const _ExerciseList({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exerciseListProvider);
    final bodyParts =
        ref.watch(bodyPartsByExerciseProvider).valueOrNull ?? const {};
    return exercises.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rows) {
        final favourites = rows.where((e) => e.isFavourite).length;
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            LibraryRow(
              tile: const _GlyphTile(icon: Icons.add),
              title: 'Create new exercise',
              onTap: onCreate,
            ),
            LibraryRow(
              tile: const _GlyphTile(icon: Icons.bookmark_border),
              title: 'Favourites',
              subtitle:
                  '$favourites ${favourites == 1 ? 'exercise' : 'exercises'}',
              onTap: () {
                ref.read(exerciseFavouritesOnlyProvider.notifier).state = true;
                context.go('/explore');
              },
            ),
            for (final e in rows)
              LibraryRow(
                tile: InitialsTile(name: e.name),
                title: e.name,
                subtitle: _subtitleFor(e, bodyParts[e.id] ?? const []),
                onTap: () => context.push('/exercises/${e.id}'),
              ),
          ],
        );
      },
    );
  }

  static String _subtitleFor(Exercise e, List<BodyPart> parts) {
    if (parts.isNotEmpty) return bodyPartsSubtitle(parts);
    return e.loggingType == LoggingType.durationOnly ? 'Duration' : 'Strength';
  }
}

/// One row of the library list: square tile, title, optional count subtitle.
/// Shared by the create row, the Favourites pseudo-item and real items —
/// that shared shape is the point of the design.
class LibraryRow extends StatelessWidget {
  const LibraryRow({
    super.key,
    required this.tile,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final Widget tile;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            tile,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: semantic.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlyphTile extends StatelessWidget {
  const _GlyphTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: semantic.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: theme.colorScheme.onSurface),
    );
  }
}

/// CMP-011: a generated colour plus the item's initials, standing in for the
/// reference app's photography. Cheap, needs no image pipeline, and has no
/// empty state to design — every item has a name.
class InitialsTile extends StatelessWidget {
  const InitialsTile({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _colourFor(name),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _initials(name),
        style: AppTheme.setNumeral.copyWith(fontSize: 20, color: Colors.black),
      ),
    );
  }

  static String _initials(String name) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.characters.take(2).toString().toUpperCase();
    }
    return (words[0].characters.first + words[1].characters.first)
        .toUpperCase();
  }

  /// Deterministic from the name, so a routine keeps its colour across
  /// launches without storing one.
  static Color _colourFor(String name) {
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.45, 0.68).toColor();
  }
}
