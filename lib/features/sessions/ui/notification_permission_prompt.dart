import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/services/session_feedback_settings.dart';

/// Asks for notification permission the first time a session starts —
/// never on app launch, never a second time (PRD FR-119). A one-line
/// rationale plus a "Not now" option; the "asked once" flag is persisted
/// regardless of which button the user taps, so declining doesn't leave the
/// prompt reappearing on the next workout.
///
/// Called from [startWorkout] — the single place a session actually begins.
Future<void> maybeRequestNotificationPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final alreadyAsked =
      await ref.read(notificationAskedSettingProvider.future);
  if (alreadyAsked) return;
  if (!context.mounted) return;

  final allow = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Rest reminders'),
      content: const Text(
        "So GymFlow can tell you when your rest is up while you're on "
        'another app.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );

  await ref.read(notificationAskedSettingProvider.notifier).markAsked();
  if (allow == true) {
    await ref.read(notificationServiceProvider).requestPermission();
  }
}
