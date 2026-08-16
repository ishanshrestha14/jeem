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
/// mid-set, from arm's length, so the countdown uses tabular condensed
/// figures at 34/700 (design system "scoreboard clock", not a Material
/// progress bar).
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
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Material(
      color: AppTheme.surface,
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
                    style: AppTheme.restCountdownBar.copyWith(color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'NEXT',
                              style: AppTheme.columnHeader.copyWith(color: colors.muted),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                rest.nextTarget?.label ?? 'Finish workout',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.body
                                    .copyWith(color: AppTheme.chalk),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _DrainRule(
                          progress: rest.progressAt(now),
                          color: color,
                          track: colors.line,
                          animated: !reduceMotion,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => controller.adjustRest(const Duration(seconds: -15)),
                    child: Text('-15s', style: AppTheme.setNumber.copyWith(fontSize: 17)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => controller.adjustRest(const Duration(seconds: 15)),
                    child: Text('+15s', style: AppTheme.setNumber.copyWith(fontSize: 17)),
                  ),
                  IconButton(
                    iconSize: 28,
                    onPressed: () =>
                        isPaused ? controller.resumeRest() : controller.pauseRest(),
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

/// A 1px hairline rule spanning full width that drains left-to-right, with a
/// 6px round cap at the leading edge — not a `LinearProgressIndicator` with
/// a track. Respects `MediaQuery.disableAnimations`.
class _DrainRule extends StatelessWidget {
  const _DrainRule({
    required this.progress,
    required this.color,
    required this.track,
    required this.animated,
  });

  final double progress;
  final Color color;
  final Color track;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: 6,
      child: CustomPaint(
        painter: _DrainPainter(progress: progress.clamp(0.0, 1.0), color: color, track: track),
      ),
    );
    if (!animated) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: progress, end: progress),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, _) => SizedBox(
        height: 6,
        child: CustomPaint(
          painter: _DrainPainter(progress: value.clamp(0.0, 1.0), color: color, track: track),
        ),
      ),
    );
  }
}

class _DrainPainter extends CustomPainter {
  _DrainPainter({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final trackPaint = Paint()
      ..color = track
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), trackPaint);

    final traveled = size.width * progress;
    if (traveled <= 0) return;
    final fillPaint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(traveled, y), fillPaint);
    canvas.drawCircle(Offset(traveled, y), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DrainPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

/// Rendered once rest has reached [RestTimerStatus.finished] and
/// `restJustFinished` is still set. Task 15 owns auto-focus; this widget
/// only supplies the manual fallback: `REST COMPLETE` as an 11px
/// letterspaced micro-label above a single full-width primary action.
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
        : (target.kind == TargetKind.sameExercise ? 'Next set' : 'Next exercise');

    return Material(
      color: AppTheme.surface,
      child: SizedBox(
        height: 72,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'REST COMPLETE',
                    style: AppTheme.columnHeader.copyWith(color: AppTheme.chalk),
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
