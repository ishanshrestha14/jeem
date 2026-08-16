import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../data/session_models.dart';

/// Pinned strip under the app bar: sets and exercises completed, plus a
/// hairline progress rule on the set ratio. No `LinearProgressIndicator`
/// track — the untravelled portion is `line`, the travelled portion is
/// `chalk` (this header tracks overall completion, not a running rest
/// timer, so it stays quiet rather than using the one saturated `rest`
/// colour).
class SessionProgressHeader extends StatelessWidget {
  const SessionProgressHeader({super.key, required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final totalSets = session.totalSets;
    final ratio = totalSets == 0 ? 0.0 : session.completedSets / totalSets;
    final labelStyle = AppTheme.body.copyWith(color: theme.colorScheme.onSurface);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${session.completedSets} / $totalSets sets',
                  style: labelStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  '${session.completedExercises} / ${session.totalExercises} exercises',
                  style: labelStyle,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                children: [
                  Container(height: 1, width: width, color: semantic.line),
                  Container(
                    height: 1,
                    width: width * ratio.clamp(0.0, 1.0),
                    color: theme.colorScheme.onSurface,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
