import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../db/app_database.dart' show RestTimerStatus;
import '../../providers/active_session_controller.dart';

/// Expanded rest controls, shown as a modal bottom sheet from [RestBar].
///
/// Per PRD §24.8 this must never stack over another open modal — any
/// currently-open sheet/dialog is popped first.
Future<void> showRestSheet(BuildContext context, WidgetRef ref) {
  final navigator = Navigator.of(context);
  navigator.popUntil((route) => route is! PopupRoute);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _RestSheetContent(),
  );
}

class _RestSheetContent extends ConsumerWidget {
  const _RestSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auto-dismiss the moment rest returns to idle (cancelled, or a new
    // set completed elsewhere while the sheet is open).
    ref.listen(activeSessionControllerProvider, (previous, next) {
      final rest = next.valueOrNull?.rest;
      if (rest != null && rest.status == RestTimerStatus.idle) {
        Navigator.of(context).maybePop();
      }
    });

    final state = ref.watch(activeSessionControllerProvider).valueOrNull;
    if (state == null) return const SizedBox.shrink();
    final rest = state.rest;

    if (rest.isActive) {
      ref.watch(restTickerProvider);
    }

    final colors = Theme.of(context).extension<SemanticColors>()!;
    final controller = ref.read(activeSessionControllerProvider.notifier);
    final now = DateTime.now();
    final isPaused = rest.status == RestTimerStatus.paused;
    final isFinished = rest.status == RestTimerStatus.finished;
    final color =
        isFinished ? colors.success : (isPaused ? colors.warning : colors.rest);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    key: const Key('restRing'),
                    width: 240,
                    height: 240,
                    child: CustomPaint(
                      painter: _RestRingPainter(
                        progress: rest.progressAt(now).clamp(0.0, 1.0),
                        color: color,
                        track: colors.line,
                        animated: !reduceMotion,
                      ),
                    ),
                  ),
                  if (isFinished)
                    Text(
                      'REST COMPLETE',
                      key: const Key('restSheetCountdownText'),
                      style: AppTheme.columnHeader.copyWith(color: color),
                    )
                  else
                    Text(
                      mmss(rest.remainingAt(now)),
                      key: const Key('restSheetCountdownText'),
                      style: AppTheme.restCountdownSheet.copyWith(color: color),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                    style: AppTheme.exerciseName.copyWith(color: AppTheme.chalk),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _ButtonRow(children: [
              _SheetButton(
                label: '-15s',
                onPressed: () =>
                    controller.adjustRest(const Duration(seconds: -15)),
              ),
              _SheetButton(
                label: '+15s',
                onPressed: () =>
                    controller.adjustRest(const Duration(seconds: 15)),
              ),
            ]),
            const SizedBox(height: 12),
            _ButtonRow(children: [
              _SheetButton(
                label: isPaused ? 'Resume' : 'Pause',
                onPressed: () =>
                    isPaused ? controller.resumeRest() : controller.pauseRest(),
              ),
              _SheetButton(
                label: 'Skip',
                onPressed: () => controller.skipRest(),
              ),
            ]),
            const SizedBox(height: 12),
            _ButtonRow(children: [
              _SheetButton(
                label: 'Cancel rest',
                onPressed: () => controller.cancelRest(),
              ),
              _SheetButton(
                label: 'Undo last set',
                onPressed: rest.afterSetId == null
                    ? null
                    : () {
                        controller.uncompleteSet(rest.afterSetId!);
                        Navigator.of(context).maybePop();
                      },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// A 240px ring (design system): `line` track, progress in the running/
/// paused/finished tint, 2px stroke, round cap, starting at 12 o'clock —
/// replaces the default `CircularProgressIndicator`.
class _RestRingPainter extends CustomPainter {
  _RestRingPainter({
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
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 2) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const start = -math.pi / 2; // 12 o'clock
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RestRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(side: BorderSide(color: semantic.line)),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
