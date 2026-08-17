import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../sessions/data/session_repository.dart';
import '../../sessions/ui/notification_permission_prompt.dart';

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
  final repo = ref.read(sessionRepositoryProvider);
  final active = await repo.watchActiveSession().first;
  if (active != null) {
    if (!context.mounted) return;
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
    if (choice == null) return;
    if (choice == _StartChoice.resume) {
      if (context.mounted) context.push('/session');
      return;
    }
    await repo.cancelSession(active.session.id);
  }
  await repo.startFromTemplate(templateId, weightUnit: 'kg');
  if (context.mounted) {
    await maybeRequestNotificationPermission(context, ref);
  }
  if (context.mounted) context.push('/session');
}
