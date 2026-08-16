import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../sessions/data/session_models.dart';
import '../providers/history_providers.dart';

/// A basic real listing of completed sessions (date, workout name, duration,
/// completed/total sets). This is deliberately minimal — the read-only
/// session detail screen and the duplicate-template action are a later
/// task; this screen exists so the History tab never leads to a
/// "coming soon" placeholder.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(completedSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No completed sessions yet',
              message: 'Finish a workout and it will show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => _HistoryRow(session: rows[i]),
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.extension<SemanticColors>()!.muted;
    final workout = session.session;
    final endedAt = workout.endedAt;

    final duration = endedAt == null
        ? null
        : endedAt.difference(workout.startedAt) -
            Duration(seconds: workout.pausedSeconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  endedAt == null
                      ? DateFormat.yMMMd().format(workout.startedAt)
                      : DateFormat.yMMMd().format(endedAt),
                  style: AppTheme.columnHeader.copyWith(color: muted),
                ),
                const SizedBox(height: 4),
                Text(workout.name, style: AppTheme.exerciseName.copyWith(
                  color: theme.colorScheme.onSurface,
                )),
                const SizedBox(height: 2),
                Text(
                  '${session.completedSets}/${session.totalSets} sets',
                  style: AppTheme.body.copyWith(color: muted),
                ),
              ],
            ),
          ),
          if (duration != null)
            Text(
              _formatDuration(duration),
              style: AppTheme.elapsedTime.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final totalMinutes = d.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
