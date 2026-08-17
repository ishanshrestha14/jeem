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
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings:
          const InitializationSettings(android: androidInit, iOS: iosInit),
    );
  }

  Future<bool> requestPermission() async {
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
  Future<void> cancelRestComplete() =>
      _plugin.cancel(id: _restNotificationId);
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
