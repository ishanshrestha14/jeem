import '../../../db/app_database.dart';
import 'session_engine.dart';

class RestTimerState {
  const RestTimerState({
    required this.status,
    required this.totalSeconds,
    this.endsAt,
    this.remainingSeconds,
    this.afterSetId,
    this.nextTarget,
  });

  const RestTimerState.idle()
      : status = RestTimerStatus.idle,
        totalSeconds = 0,
        endsAt = null,
        remainingSeconds = null,
        afterSetId = null,
        nextTarget = null;

  final RestTimerStatus status;
  final int totalSeconds;

  /// Wall-clock deadline. Authoritative while running — this is what makes the
  /// countdown survive process death.
  final DateTime? endsAt;

  /// Authoritative only while paused or finished.
  final int? remainingSeconds;

  final String? afterSetId;
  final SessionTarget? nextTarget;

  bool get isActive =>
      status == RestTimerStatus.running || status == RestTimerStatus.paused;

  Duration remainingAt(DateTime now) {
    switch (status) {
      case RestTimerStatus.running:
        final end = endsAt;
        if (end == null) return Duration.zero;
        final left = end.difference(now);
        return left.isNegative ? Duration.zero : left;
      case RestTimerStatus.paused:
        return Duration(seconds: remainingSeconds ?? 0);
      case RestTimerStatus.finished:
      case RestTimerStatus.idle:
        return Duration.zero;
    }
  }

  double progressAt(DateTime now) {
    if (totalSeconds <= 0) return 1;
    final elapsed = totalSeconds - remainingAt(now).inSeconds;
    return (elapsed / totalSeconds).clamp(0.0, 1.0);
  }

  RestTimerState copyWith({
    RestTimerStatus? status,
    int? totalSeconds,
    DateTime? endsAt,
    bool clearEndsAt = false,
    int? remainingSeconds,
    bool clearRemaining = false,
    String? afterSetId,
    SessionTarget? nextTarget,
  }) {
    return RestTimerState(
      status: status ?? this.status,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      remainingSeconds:
          clearRemaining ? null : (remainingSeconds ?? this.remainingSeconds),
      afterSetId: afterSetId ?? this.afterSetId,
      nextTarget: nextTarget ?? this.nextTarget,
    );
  }
}

abstract final class RestTimer {
  static RestTimerState start({
    required int seconds,
    required DateTime now,
    required String afterSetId,
    SessionTarget? nextTarget,
  }) {
    if (seconds <= 0) {
      return RestTimerState(
        status: RestTimerStatus.finished,
        totalSeconds: 0,
        remainingSeconds: 0,
        afterSetId: afterSetId,
        nextTarget: nextTarget,
      );
    }
    return RestTimerState(
      status: RestTimerStatus.running,
      totalSeconds: seconds,
      endsAt: now.add(Duration(seconds: seconds)),
      afterSetId: afterSetId,
      nextTarget: nextTarget,
    );
  }

  static RestTimerState pause(RestTimerState s, DateTime now) {
    if (s.status != RestTimerStatus.running) return s;
    return s.copyWith(
      status: RestTimerStatus.paused,
      remainingSeconds: s.remainingAt(now).inSeconds,
      clearEndsAt: true,
    );
  }

  static RestTimerState resume(RestTimerState s, DateTime now) {
    if (s.status != RestTimerStatus.paused) return s;
    final left = s.remainingSeconds ?? 0;
    if (left <= 0) return s.copyWith(status: RestTimerStatus.finished);
    return s.copyWith(
      status: RestTimerStatus.running,
      endsAt: now.add(Duration(seconds: left)),
      clearRemaining: true,
    );
  }

  static RestTimerState adjust(RestTimerState s, Duration delta, DateTime now) {
    final newTotal = (s.totalSeconds + delta.inSeconds).clamp(0, 3600);

    if (s.status == RestTimerStatus.paused) {
      final left = (s.remainingSeconds ?? 0) + delta.inSeconds;
      if (left <= 0) {
        return s.copyWith(
          status: RestTimerStatus.finished,
          remainingSeconds: 0,
          totalSeconds: newTotal,
        );
      }
      return s.copyWith(remainingSeconds: left, totalSeconds: newTotal);
    }

    if (s.status != RestTimerStatus.running) return s;

    final left = s.remainingAt(now) + delta;
    if (left <= Duration.zero) {
      return s.copyWith(
        status: RestTimerStatus.finished,
        remainingSeconds: 0,
        totalSeconds: newTotal,
        clearEndsAt: true,
      );
    }
    return s.copyWith(endsAt: now.add(left), totalSeconds: newTotal);
  }

  /// Recomputes status from the wall clock. Called on every tick and on every
  /// app resume — it is what turns "the deadline passed while backgrounded"
  /// into a finished state rather than a stuck countdown.
  static RestTimerState settle(RestTimerState s, DateTime now) {
    if (s.status != RestTimerStatus.running) return s;
    if (s.remainingAt(now) > Duration.zero) return s;
    return s.copyWith(
      status: RestTimerStatus.finished,
      remainingSeconds: 0,
      clearEndsAt: true,
    );
  }

  static RestTimerState skip(RestTimerState s) => s.copyWith(
        status: RestTimerStatus.finished,
        remainingSeconds: 0,
        clearEndsAt: true,
      );

  static RestTimerState cancel() => const RestTimerState.idle();
}
