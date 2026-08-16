import 'package:flutter/material.dart';

import '../../data/session_models.dart';

/// Pinned strip under the app bar: sets and exercises completed, plus a
/// progress bar on the set ratio.
class SessionProgressHeader extends StatelessWidget {
  const SessionProgressHeader({super.key, required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSets = session.totalSets;
    final ratio = totalSets == 0 ? 0.0 : session.completedSets / totalSets;

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${session.completedSets} / $totalSets sets',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${session.completedExercises} / ${session.totalExercises} exercises',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: ratio, minHeight: 6),
          ),
        ],
      ),
    );
  }
}
