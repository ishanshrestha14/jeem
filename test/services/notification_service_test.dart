import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/services/notification_service.dart';

/// Regression for a **native** crash, not a Dart one.
///
/// `initialize()` throws when the running platform's settings are missing
/// (macOS had none). `main` catches that and starts the app anyway — correct;
/// a missing notification must never block launch. But the plugin is then
/// half-built, and calling into it force-unwraps nil in Swift:
///
///   FlutterLocalNotificationsPlugin.swift:420: Fatal error: Unexpectedly
///   found nil while unwrapping an Optional value
///
/// That kills the process; no `try`/`catch` in Dart can contain it. So the
/// guard below is the actual fix: an uninitialised service must call nothing.
void main() {
  test('does nothing at all until init has succeeded', () async {
    // Never initialised — exactly the state `main` leaves it in when
    // `init()` throws. In a plain `test()` there is no platform channel, so
    // any real call would also fail loudly here.
    final service = NotificationService();

    expect(service.isAvailable, isFalse);

    // None of these may reach the plugin.
    await service.scheduleRestComplete(
      at: DateTime.now().add(const Duration(minutes: 2)),
      nextLabel: 'Back Squat',
    );
    await service.cancelRestComplete();
    expect(await service.requestPermission(), isFalse);
    expect(await service.hasPermission(), isFalse);
  });
}
