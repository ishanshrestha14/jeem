import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/services/notification_service.dart';
import 'package:gymflow/core/services/session_feedback_settings.dart';
import 'package:gymflow/features/sessions/ui/notification_permission_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../session_feedback_fakes.dart';

/// [maybeRequestNotificationPermission] is called from `startWorkout` (the
/// single place a session actually begins), not from a screen this suite
/// already mounts — so this file drives it directly from a minimal harness
/// (a button whose `onPressed` calls it with the tapped `BuildContext`)
/// rather than pulling in the whole template/workout-start flow.
void main() {
  late ProviderContainer container;
  late RecordingNotificationService notifications;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    notifications = RecordingNotificationService();
  });
  tearDown(() => container.dispose());

  Widget harness() {
    container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => maybeRequestNotificationPermission(context, ref),
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      '"Not now" persists the asked flag without requesting permission, and '
      'the prompt never appears a second time', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("rest is up while you're on another app"),
      findsOneWidget,
    );

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(notifications.requestPermissionCalls, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(notificationPermissionAskedPrefsKey), isTrue);

    // Triggering a second time (e.g. starting a second workout) must NOT
    // show the rationale again — PRD FR-119: ask once, ever, regardless of
    // the user's answer.
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("rest is up while you're on another app"),
      findsNothing,
    );
  });

  testWidgets(
      '"Allow" requests permission through NotificationService and persists '
      'the asked flag', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect(notifications.requestPermissionCalls, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(notificationPermissionAskedPrefsKey), isTrue);
  });

  testWidgets(
      'a session started with the flag already set never shows the prompt',
      (tester) async {
    SharedPreferences.setMockInitialValues(
      {notificationPermissionAskedPrefsKey: true},
    );

    await tester.pumpWidget(harness());
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("rest is up while you're on another app"),
      findsNothing,
    );
    expect(notifications.requestPermissionCalls, 0);
  });
}
