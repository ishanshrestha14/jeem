import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../providers/active_session_controller.dart';

/// A strip pinned directly above the bottom nav whenever a session is live,
/// so the workout stays reachable from every tab rather than only from Home
/// (CMP-001, T-001).
///
/// It **occupies layout** rather than floating: the shell places it in a
/// `Column` above `bottomNavigationBar`, so tab content is shortened by its
/// height and nothing ends up hidden underneath it.
///
/// Deliberately carries no elapsed time. The reference app's equivalent shows
/// only a label and two actions, and a live clock here would mean a second
/// ticker to keep in step with the session screen's own — a cost with no
/// payoff on a bar whose entire job is "your workout is still going, tap to
/// get back to it".
///
/// Not shown on `/session` itself, which needs no explanation: that route sits
/// outside the shell entirely, so this widget is never built there.
class WorkoutInProgressBar extends ConsumerWidget {
  const WorkoutInProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionProvider);
    final session = active.valueOrNull;
    // Renders nothing while the stream is loading or errored, so a transient
    // read cannot flash a bar for a session that may not exist.
    if (session == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    return Material(
      color: semantic.surfaceHigh,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: semantic.line)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Workout in Progress',
                style: AppTheme.columnHeader.copyWith(color: semantic.rest),
              ),
              const SizedBox(height: 2),
              Text(
                session.session.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      // 48dp minimum: this is tapped mid-workout, often
                      // one-handed, and it is the path back to the session.
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: semantic.rest,
                      ),
                      onPressed: () => context.push('/session'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Resume'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: semantic.danger,
                      ),
                      onPressed: () => _confirmDiscard(context, ref),
                      icon: const Icon(Icons.close),
                      label: const Text('Discard'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Discard workout?',
      message:
          'Everything logged in this session will be lost. This cannot be undone.',
      confirmLabel: 'Discard workout',
      // Names the safe option after what the user is actually doing, rather
      // than "Cancel" — which, next to "Discard", reads ambiguously as
      // "cancel the workout".
      cancelLabel: 'Keep working out',
    );
    if (!confirmed) return;

    await ref.read(activeSessionControllerProvider.notifier).cancelSession();
  }
}
