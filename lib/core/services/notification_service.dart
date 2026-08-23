import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local (device-only) notifications for "your rest is up". The one thing
/// that matters about this class: [scheduleRestComplete] is called when rest
/// **starts**, for the wall-clock moment it's due — never fired from a Dart
/// timer when rest ends. A scheduled OS notification survives the process
/// being killed (the whole point: the user has locked their phone and put it
/// in a pocket); a Dart timer does not, and Task 17 already proved the rest
/// timer itself is timestamp-anchored for exactly this reason.
///
/// Wraps `flutter_local_notifications` directly (rather than exposing it)
/// so tests can override [notificationServiceProvider] with a fake and
/// assert on what was requested — `flutter test` has no host implementation
/// for the real platform channel, and this project runs no Android/iOS
/// build here to exercise one. Same shape as [WakelockService].
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Whether [init] completed. **Every** plugin call is gated on this.
  ///
  /// Not defensive programming for its own sake: when initialisation fails,
  /// the plugin's native side is left with nil internals, and calling into it
  /// anyway is a **hard crash**, not an exception — on macOS,
  /// `FlutterLocalNotificationsPlugin.swift:420: Unexpectedly found nil while
  /// unwrapping an Optional value`, which no Dart `try`/`catch` can contain.
  /// A caller that swallows an init failure and carries on (as `main` does,
  /// correctly — a missing notification must never stop the app starting)
  /// would otherwise take the whole process down at the first completed set.
  bool _initialised = false;

  /// Exposed for the notification-permission prompt, which has nothing to
  /// offer when notifications could not be set up at all.
  bool get isAvailable => _initialised;

  /// A single, well-known id: there is only ever one rest running at a time,
  /// so re-scheduling always means "replace the pending one", never "add
  /// another".
  static const _restNotificationId = 1001;

  Future<void> init() async {
    // `timezone` arrives as a transitive dependency of
    // `flutter_local_notifications` (needed for `zonedSchedule`) — this is
    // not a new package.
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    await _plugin.initialize(
      // macOS was missing here, and the plugin *requires* settings for the
      // platform it is running on — so `initialize` threw on every desktop
      // run, leaving the plugin half-built. Android is the shipping target,
      // but the Mac build is what UI changes get checked on, so it has to
      // survive a completed set.
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
    );
    _initialised = true;
  }

  Future<bool> requestPermission() async {
    if (!_initialised) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<bool> hasPermission() async {
    if (!_initialised) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final settings = await ios.checkPermissions();
      return settings?.isEnabled ?? false;
    }
    return false;
  }

  /// Cancels any previously-scheduled rest notification, then schedules a
  /// fresh one for [at]. The cancel-first is what makes calling this again
  /// for a brand-new rest (a set completed while already resting) correct
  /// without a separate explicit cancel at every call site.
  ///
  /// Deliberately no exact-alarm permission and no foreground service — the
  /// MVP PRD (§10.5) stays out of that, hence `inexactAllowWhileIdle`.
  Future<void> scheduleRestComplete({
    required DateTime at,
    required String nextLabel,
  }) async {
    if (!_initialised) return;
    await cancelRestComplete();
    await _plugin.zonedSchedule(
      id: _restNotificationId,
      title: 'Rest complete',
      body: 'Next: $nextLabel',
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_timer',
          'Rest timer',
          channelDescription: 'Fires when a rest period ends',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Harmless to call when nothing is pending (it already fired, or the
  /// user was in-app the whole time) — every call site relies on that.
  Future<void> cancelRestComplete() async {
    if (!_initialised) return;
    await _plugin.cancel(id: _restNotificationId);
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
