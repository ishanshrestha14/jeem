import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/semantic_colors.dart';
import '../../history/providers/history_providers.dart';

/// The You tab: what accumulates *because* you trained (ADR-005, S-005).
///
/// Settings moved off the tab bar and into the top-bar gear here — a whole
/// primary destination spent on settings was the largest gap between this app
/// and the surface it is modelled on.
///
/// History also lost its tab and lives here, behind "Workout log", per the
/// owner's decision: Home is recap, this is the analysis surface, and the full
/// list is one deliberate tap away rather than holding a permanent slot.
///
/// The stats hub itself (trend charts, personal records, measures, photos) is
/// not built yet. Nothing here is faked to stand in for it — the tab shows
/// what genuinely exists and says plainly what does not.
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('You'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: semantic.surfaceHigh,
            child: ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.history),
              title: const Text('Workout log'),
              subtitle: Text(
                history.when(
                  loading: () => 'Loading…',
                  error: (_, _) => 'Could not load history',
                  data: (rows) => rows.isEmpty
                      ? 'No completed workouts yet'
                      : '${rows.length} completed '
                          '${rows.length == 1 ? 'workout' : 'workouts'}',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/history'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Progress charts, personal records, measurements and photos will '
            'live here. They are not built yet, and this tab would rather be '
            'honest about that than show a placeholder.',
            style: theme.textTheme.bodySmall?.copyWith(color: semantic.muted),
          ),
        ],
      ),
    );
  }
}
