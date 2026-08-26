import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../sessions/data/session_repository.dart';
import '../../sessions/ui/notification_permission_prompt.dart';
import '../../settings/providers/settings_providers.dart';

enum _StartChoice { resume, discard }

/// Starts a session from [templateId] and navigates to it. If a session is
/// already running, offers to resume it or discard it in favour of the new
/// one, rather than silently starting a second session. Goes through
/// [sessionRepositoryProvider] directly (there is no controller yet before
/// a session exists to drive one).
///
/// Shared by the Workout tab's template list and Home's quick-start section
/// — both start workouts from a [TemplateSummary] and must offer the same
/// already-active-session choice, so the logic lives here once rather than
/// being copy-pasted at each call site.
Future<void> startWorkout(
  BuildContext context,
  WidgetRef ref,
  String templateId,
) async {
  // Captured before the first await: `ScaffoldMessenger.of` must not cross an
  // async gap, and the resume-or-discard dialog below is one.
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(sessionRepositoryProvider);
  if (!await _resolveRunningSession(context, ref, repo)) return;

  final weightUnit = ref.read(settingsProvider).weightUnit;
  try {
    await repo.startFromTemplate(templateId, weightUnit: weightUnit);
  } on RoutineNotFound {
    // The routine was deleted between being listed and being started — from a
    // stale list, or a detail screen left open while it was deleted elsewhere.
    // Say so; crashing on a dead row helps nobody.
    messenger.showSnackBar(
      const SnackBar(content: Text('That routine no longer exists.')),
    );
    return;
  }
  if (context.mounted) {
    await maybeRequestNotificationPermission(context, ref);
  }
  if (context.mounted) context.push('/session');
}

/// Starts a session with no routine behind it (T-012) and navigates to it —
/// S-003's `Start new workout`. Shares [startWorkout]'s already-running-session
/// handling, so starting a workout behaves the same however it began.
Future<void> startAdHocWorkout(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(sessionRepositoryProvider);
  if (!await _resolveRunningSession(context, ref, repo)) return;

  final weightUnit = ref.read(settingsProvider).weightUnit;
  await repo.startAdHoc(weightUnit: weightUnit);
  if (context.mounted) {
    await maybeRequestNotificationPermission(context, ref);
  }
  if (context.mounted) context.push('/session');
}

/// Offers resume-or-discard when a session is already running.
///
/// Returns true when the caller should go ahead and start a new session, and
/// false when it must not — either because the user chose to resume the
/// running one (and has been navigated to it) or because they dismissed the
/// dialog.
Future<bool> _resolveRunningSession(
  BuildContext context,
  WidgetRef ref,
  SessionRepository repo,
) async {
  final active = await repo.watchActiveSession().first;
  if (active == null) return true;
  if (!context.mounted) return false;

  final choice = await showDialog<_StartChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Workout already in progress'),
      content: Text('"${active.session.name}" is still running.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_StartChoice.resume),
          child: const Text('Resume the running session'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(_StartChoice.discard),
          child: const Text('Discard it and start this one'),
        ),
      ],
    ),
  );
  if (choice == null) return false;
  if (choice == _StartChoice.resume) {
    if (context.mounted) context.push('/session');
    return false;
  }
  await repo.cancelSession(active.session.id);
  return true;
}
