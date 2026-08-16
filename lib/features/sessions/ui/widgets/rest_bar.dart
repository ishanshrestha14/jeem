import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../db/app_database.dart' show RestTimerStatus;
import '../../providers/active_session_controller.dart';
import 'rest_sheet.dart';

/// Compact, always-tappable rest indicator that lives in the active session
/// screen's `bottomNavigationBar` slot. Visible whenever a rest is running,
/// paused, or has just finished (PRD §9.5) — must be readable at a glance,
/// mid-set, from arm's length, so the countdown uses tabular figures and a
/// large text style.
///
/// Mounted only when `rest.isActive || restJustFinished` (see
/// `ActiveSessionScreen._buildScaffold`), so this widget doesn't need to
/// handle the fully-idle case itself.
class RestBar extends ConsumerWidget {
  const RestBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeSessionControllerProvider).valueOrNull;
    if (state == null) return const SizedBox.shrink();
    final rest = state.rest;

    // Rebuild on the 500ms ticker only while actually running/paused — never
    // while idle or merely finished-and-waiting, so nothing repaints for no
    // reason once the countdown has nothing left to show.
    if (rest.isActive) {
      ref.watch(restTickerProvider);
    }

    final colors = Theme.of(context).extension<SemanticColors>()!;
    final controller = ref.read(activeSessionControllerProvider.notifier);

    if (state.restJustFinished) {
      return _FinishedBar(colors: colors, rest: rest, controller: controller);
    }

    if (!rest.isActive) return const SizedBox.shrink();

    final now = DateTime.now();
    final isPaused = rest.status == RestTimerStatus.paused;
    final color = isPaused ? colors.warning : colors.rest;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => showRestSheet(context, ref),
        child: SizedBox(
          height: 72,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    mmss(rest.remainingAt(now)),
                    key: const Key('restCountdownText'),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.merge(AppTheme.tabularFigures)
                        .copyWith(color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next: ${rest.nextTarget?.label ?? "Finish workout"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: rest.progressAt(now),
                          color: color,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => controller
                        .adjustRest(const Duration(seconds: -15)),
                    child: const Text('-15s'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () =>
                        controller.adjustRest(const Duration(seconds: 15)),
                    child: const Text('+15s'),
                  ),
                  IconButton(
                    iconSize: 28,
                    onPressed: () => isPaused
                        ? controller.resumeRest()
                        : controller.pauseRest(),
                    icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                  ),
                  IconButton(
                    iconSize: 28,
                    onPressed: () => controller.skipRest(),
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rendered once rest has reached [RestTimerStatus.finished] and
/// `restJustFinished` is still set. Task 15 owns auto-focus; this widget
/// only supplies the manual fallback: a single button that focuses the next
/// target and clears the flag.
class _FinishedBar extends StatelessWidget {
  const _FinishedBar({
    required this.colors,
    required this.rest,
    required this.controller,
  });

  final SemanticColors colors;
  final RestTimerState rest;
  final ActiveSessionController controller;

  @override
  Widget build(BuildContext context) {
    final target = rest.nextTarget;
    final label = target == null
        ? 'Continue'
        : (target.kind == TargetKind.sameExercise
            ? 'Next set'
            : 'Next exercise');

    return Material(
      color: colors.success.withValues(alpha: 0.18),
      child: SizedBox(
        height: 72,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: colors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rest complete',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: colors.success),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    if (target != null) controller.focusSet(target.setId);
                    controller.clearRestFinished();
                  },
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
