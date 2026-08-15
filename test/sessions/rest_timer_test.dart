import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/domain/rest_timer.dart';

final t0 = DateTime.utc(2026, 8, 15, 10, 0, 0);

void main() {
  test('start anchors an end timestamp rather than a countdown', () {
    final s = RestTimer.start(seconds: 90, now: t0, afterSetId: 'a');

    expect(s.status, RestTimerStatus.running);
    expect(s.endsAt, t0.add(const Duration(seconds: 90)));
    expect(s.totalSeconds, 90);
    expect(s.afterSetId, 'a');
    expect(s.remainingAt(t0), const Duration(seconds: 90));
    expect(s.remainingAt(t0.add(const Duration(seconds: 30))),
        const Duration(seconds: 60));
  });

  test('remaining never goes negative and progress caps at 1', () {
    final s = RestTimer.start(seconds: 60, now: t0, afterSetId: 'a');
    final late = t0.add(const Duration(minutes: 5));

    expect(s.remainingAt(late), Duration.zero);
    expect(s.progressAt(late), 1.0);
    expect(s.progressAt(t0.add(const Duration(seconds: 30))), closeTo(0.5, 0.01));
  });

  test('pause freezes the remaining time', () {
    final running = RestTimer.start(seconds: 90, now: t0, afterSetId: 'a');
    final paused = RestTimer.pause(running, t0.add(const Duration(seconds: 20)));

    expect(paused.status, RestTimerStatus.paused);
    expect(paused.remainingSeconds, 70);
    // Time passing while paused changes nothing.
    expect(paused.remainingAt(t0.add(const Duration(minutes: 10))),
        const Duration(seconds: 70));
  });

  test('resume re-anchors endsAt from the frozen remainder', () {
    final running = RestTimer.start(seconds: 90, now: t0, afterSetId: 'a');
    final paused = RestTimer.pause(running, t0.add(const Duration(seconds: 20)));
    final resumeAt = t0.add(const Duration(minutes: 5));
    final resumed = RestTimer.resume(paused, resumeAt);

    expect(resumed.status, RestTimerStatus.running);
    expect(resumed.endsAt, resumeAt.add(const Duration(seconds: 70)));
    expect(resumed.remainingAt(resumeAt), const Duration(seconds: 70));
  });

  test('+15s and -15s shift the end timestamp and the total', () {
    final s = RestTimer.start(seconds: 90, now: t0, afterSetId: 'a');

    final plus = RestTimer.adjust(s, const Duration(seconds: 15), t0);
    expect(plus.remainingAt(t0), const Duration(seconds: 105));
    expect(plus.totalSeconds, 105);

    final minus = RestTimer.adjust(s, const Duration(seconds: -15), t0);
    expect(minus.remainingAt(t0), const Duration(seconds: 75));
  });

  test('-15s cannot push remaining below zero; it finishes instead', () {
    final s = RestTimer.start(seconds: 10, now: t0, afterSetId: 'a');
    final minus = RestTimer.adjust(s, const Duration(seconds: -15), t0);

    expect(minus.remainingAt(t0), Duration.zero);
    expect(minus.status, RestTimerStatus.finished);
  });

  test('adjust while paused shifts the frozen remainder', () {
    final paused = RestTimer.pause(
      RestTimer.start(seconds: 90, now: t0, afterSetId: 'a'),
      t0.add(const Duration(seconds: 20)),
    );
    final plus = RestTimer.adjust(paused, const Duration(seconds: 15), t0);

    expect(plus.status, RestTimerStatus.paused);
    expect(plus.remainingSeconds, 85);
  });

  test('settle flips a running timer to finished once the deadline passes', () {
    final s = RestTimer.start(seconds: 60, now: t0, afterSetId: 'a');

    expect(RestTimer.settle(s, t0.add(const Duration(seconds: 59))).status,
        RestTimerStatus.running);
    expect(RestTimer.settle(s, t0.add(const Duration(seconds: 60))).status,
        RestTimerStatus.finished);
    // Survives a long backgrounding: still finished, not restarted (PRD §18.3).
    expect(RestTimer.settle(s, t0.add(const Duration(hours: 2))).status,
        RestTimerStatus.finished);
  });

  test('settle leaves a paused timer alone', () {
    final paused = RestTimer.pause(
      RestTimer.start(seconds: 60, now: t0, afterSetId: 'a'),
      t0.add(const Duration(seconds: 10)),
    );
    expect(RestTimer.settle(paused, t0.add(const Duration(hours: 1))).status,
        RestTimerStatus.paused);
  });

  test('skip finishes immediately, cancel returns to idle', () {
    final s = RestTimer.start(seconds: 60, now: t0, afterSetId: 'a');

    final skipped = RestTimer.skip(s);
    expect(skipped.status, RestTimerStatus.finished);
    expect(skipped.remainingAt(t0), Duration.zero);
    expect(skipped.afterSetId, 'a');

    final cancelled = RestTimer.cancel();
    expect(cancelled.status, RestTimerStatus.idle);
    expect(cancelled.isActive, isFalse);
    expect(cancelled.afterSetId, isNull);
  });

  test('starting with zero seconds yields a finished timer, never a running one',
      () {
    final s = RestTimer.start(seconds: 0, now: t0, afterSetId: 'a');
    expect(s.status, RestTimerStatus.finished);
  });
}
