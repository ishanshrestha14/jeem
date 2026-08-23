import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/semantic_colors.dart';
import '../../exercises/providers/exercise_providers.dart';
import '../../templates/providers/template_providers.dart';

/// The Library tab: **your** content — routines you have built and exercises
/// you have added (ADR-005).
///
/// Deliberately a hub of real entry points with real counts rather than a
/// second copy of the Workout tab's routine list. The two tabs answer
/// different questions — Workout is "what am I doing today", Library is
/// "what have I got" — and duplicating the list before Workout is redesigned
/// would make them look like the same screen twice.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templateSummariesProvider);
    final exercises = ref.watch(exerciseListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          _LibraryTile(
            icon: Icons.list_alt_outlined,
            title: 'Routines',
            // Counts come from the real providers; a hardcoded number here
            // would be exactly the placeholder metric the dashboard avoids.
            subtitle: templates.when(
              loading: () => 'Loading…',
              error: (_, _) => 'Could not load routines',
              data: (rows) => _count(rows.length, 'routine'),
            ),
            onTap: () => context.go('/workout'),
          ),
          _LibraryTile(
            icon: Icons.fitness_center_outlined,
            title: 'Exercises',
            subtitle: exercises.when(
              loading: () => 'Loading…',
              error: (_, _) => 'Could not load exercises',
              data: (rows) =>
                  _count(rows.length, 'exercise', plural: 'exercises'),
            ),
            onTap: () => context.go('/explore'),
          ),
          _LibraryTile(
            icon: Icons.add,
            title: 'New routine',
            subtitle: 'Build a routine from your exercises',
            onTap: () => context.push('/templates/new'),
          ),
          _LibraryTile(
            icon: Icons.add_box_outlined,
            title: 'New exercise',
            subtitle: 'Add a movement you train',
            onTap: () => context.push('/exercises/new'),
          ),
        ],
      ),
    );
  }

  static String _count(int n, String singular, {String? plural}) {
    if (n == 0) return 'None yet';
    return '$n ${n == 1 ? singular : (plural ?? '${singular}s')}';
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: semantic.surfaceHigh,
      child: ListTile(
        minTileHeight: 64,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
