import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymflow/core/services/haptics_service.dart';
import 'package:gymflow/core/services/notification_service.dart';
import 'package:gymflow/core/services/sound_service.dart';
import 'package:gymflow/core/services/wakelock_service.dart';

/// Records what [ActiveSessionController] requested instead of driving a
/// real platform channel. `flutter_local_notifications` has no host
/// implementation in this test environment, and even the plain-Dart
/// `HapticFeedback`/`SystemSound` calls need a live `ServicesBinding` that
/// most of these suites never initialise (they use bare `test()`, not
/// `testWidgets()`). Every test file that exercises
/// `ActiveSessionController` overrides `notificationServiceProvider` /
/// `hapticsServiceProvider` / `soundServiceProvider` with one of these three
/// so the controller's side effects are observable without touching a
/// channel — this is the same shape as `_RecordingWakelockService` in
/// `session_restore_test.dart`.
class RecordingNotificationService implements NotificationService {
  final List<({DateTime at, String nextLabel})> scheduled = [];
  int cancelCalls = 0;
  int requestPermissionCalls = 0;

  @override
  Future<void> scheduleRestComplete({
    required DateTime at,
    required String nextLabel,
  }) async {
    // Mirrors the real `NotificationService.scheduleRestComplete`, which
    // cancels any previously-pending notification before scheduling the new
    // one — that's what makes "completing another set while resting cancels
    // the old notification and schedules a new one" observable through
    // [cancelCalls] rather than needing separate bookkeeping.
    await cancelRestComplete();
    scheduled.add((at: at, nextLabel: nextLabel));
  }

  @override
  Future<void> cancelRestComplete() async {
    cancelCalls++;
  }

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls++;
    return true;
  }

  @override
  Future<bool> hasPermission() async => true;
}

/// Throws from every method — used by the C1 regression test proving a
/// platform-channel failure in [NotificationService] can't strand
/// `ActiveSessionController.completeSet` (or its siblings) before they reach
/// `_reload`/`saveRestState`/`_emit`. Real `flutter_local_notifications`
/// calls can throw a `PlatformException`/`MissingPluginException` on-device;
/// this simulates that.
class ThrowingNotificationService implements NotificationService {
  @override
  Future<void> scheduleRestComplete({
    required DateTime at,
    required String nextLabel,
  }) async =>
      throw Exception('boom: scheduleRestComplete');

  @override
  Future<void> cancelRestComplete() async =>
      throw Exception('boom: cancelRestComplete');

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async =>
      throw Exception('boom: requestPermission');

  @override
  Future<bool> hasPermission() async => throw Exception('boom: hasPermission');
}

/// Throws from every method — the haptics counterpart of
/// [ThrowingNotificationService], for the same C1 regression test.
class ThrowingHapticsService implements HapticsService {
  @override
  Future<void> setCompleted() async => throw Exception('boom: setCompleted');

  @override
  Future<void> restFinished() async => throw Exception('boom: restFinished');
}

/// Throws on every call — the sound counterpart of [ThrowingHapticsService],
/// for the `_onRestFinished` regression test (same C1-class defect, fixed
/// alongside it: `_onRestFinished`'s haptics/sound calls now route through
/// `_safe` too).
class ThrowingSoundService implements SoundService {
  @override
  Future<void> restComplete() async => throw Exception('boom: restComplete');
}

class RecordingHapticsService implements HapticsService {
  int setCompletedCalls = 0;
  int restFinishedCalls = 0;

  @override
  Future<void> setCompleted() async {
    setCompletedCalls++;
  }

  @override
  Future<void> restFinished() async {
    restFinishedCalls++;
  }
}

class RecordingSoundService implements SoundService {
  int restCompleteCalls = 0;

  @override
  Future<void> restComplete() async {
    restCompleteCalls++;
  }
}

/// A no-op stand-in for `WakelockService` — `ActiveSessionScreen` reads
/// `keepScreenOnSettingProvider` (`shared_preferences`-backed) via a
/// `listenManual(..., fireImmediately: true)` in `initState`, which now that
/// `shared_preferences` is mocked (see [sessionFeedbackOverrides]) resolves
/// and unconditionally calls into `WakelockService` on every mount. Not
/// overriding this crashes with a `wakelock_plus` platform-channel error the
/// same way an un-overridden `NotificationService` would.
class NoopWakelockService implements WakelockService {
  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}

/// The full set of overrides any `ActiveSessionScreen`-mounting (or
/// `ActiveSessionController`-exercising) test needs so nothing in this
/// suite touches a real platform channel:
/// `NotificationService`/`HapticsService`/`SoundService` (Task 18) plus
/// `WakelockService` (Task 17), which is otherwise reached transitively the
/// moment `shared_preferences` is mocked and its settings actually resolve.
/// Callers still need their own `SharedPreferences.setMockInitialValues`
/// call — this only covers the provider overrides.
List<Override> sessionFeedbackOverrides() => [
      notificationServiceProvider
          .overrideWithValue(RecordingNotificationService()),
      hapticsServiceProvider.overrideWithValue(RecordingHapticsService()),
      soundServiceProvider.overrideWithValue(RecordingSoundService()),
      wakelockServiceProvider.overrideWithValue(NoopWakelockService()),
    ];
