import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/data/session_models.dart';
import 'package:gymflow/features/sessions/domain/session_engine.dart';

final _t = DateTime.utc(2026, 8, 15, 10);

SessionSet _set(String id, int index, {bool done = false}) => SessionSet(
      id: id,
      sessionExerciseId: '',
      setIndex: index,
      weight: null,
      reps: null,
      rir: null,
      durationSeconds: null,
      completedAt: done ? _t : null,
      createdAt: _t,
      updatedAt: _t,
      deletedAt: null,
    );

SessionExerciseWithSets _ex(
  String id,
  String name, {
  required int sortOrder,
  required List<SessionSet> sets,
  int restSeconds = 90,
}) {
  return SessionExerciseWithSets(
    exercise: SessionExercise(
      id: id,
      sessionId: 's',
      exerciseId: null,
      name: name,
      description: null,
      notes: null,
      imagePath: null,
      loggingType: LoggingType.strengthWeightRepsRir,
      sortOrder: sortOrder,
      restSeconds: restSeconds,
      targetSets: sets.length,
      sessionNotes: null,
      createdAt: _t,
      updatedAt: _t,
      deletedAt: null,
    ),
    sets: [for (final s in sets) s.copyWith(sessionExerciseId: id)],
  );
}

ActiveSession _session(List<SessionExerciseWithSets> exercises) => ActiveSession(
      session: WorkoutSession(
        id: 's',
        templateId: null,
        name: 'Push',
        weightUnit: 'kg',
        status: SessionStatus.active,
        autoFocusNextSet: true,
        autoFocusNextExercise: true,
        startedAt: _t,
        endedAt: null,
        pausedSeconds: 0,
        notes: null,
        restStatus: RestTimerStatus.idle,
        restEndsAt: null,
        restRemainingSeconds: null,
        restTotalSeconds: null,
        restAfterSetId: null,
        createdAt: _t,
        updatedAt: _t,
        deletedAt: null,
      ),
      exercises: exercises,
    );

void main() {
  group('firstPendingTarget', () {
    test('is the first incomplete set of the first incomplete exercise', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [
          _set('a', 0, done: true),
          _set('b', 1),
          _set('c', 2),
        ]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('d', 0)]),
      ]);

      final target = firstPendingTarget(s)!;
      expect(target.setId, 'b');
      expect(target.exerciseName, 'Bench Press');
      expect(target.label, 'Bench Press — Set 2');
    });

    test('skips fully completed exercises', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0, done: true)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('b', 0)]),
      ]);
      expect(firstPendingTarget(s)!.setId, 'b');
    });

    test('is null when everything is done', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0, done: true)]),
      ]);
      expect(firstPendingTarget(s), isNull);
    });
  });

  group('nextTargetAfter', () {
    test('prefers the next pending set inside the same exercise', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [
          _set('a', 0, done: true),
          _set('b', 1),
        ]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('c', 0)]),
      ]);

      final target = nextTargetAfter(s, 'a')!;
      expect(target.setId, 'b');
      expect(target.kind, TargetKind.sameExercise);
    });

    test('moves to the next exercise after the final set', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0, done: true)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('b', 0)]),
      ]);

      final target = nextTargetAfter(s, 'a')!;
      expect(target.setId, 'b');
      expect(target.kind, TargetKind.nextExercise);
      expect(target.label, 'Lat Pulldown — Set 1');
    });

    test('respects the current session order, not the original order', () {
      // e2 has been dragged in front of e1.
      final s = _session([
        _ex('e2', 'Lat Pulldown', sortOrder: 0, sets: [_set('b', 0)]),
        _ex('e1', 'Bench Press', sortOrder: 1, sets: [_set('a', 0, done: true)]),
      ]);

      expect(nextTargetAfter(s, 'a'), isNull);
      expect(firstPendingTarget(s)!.setId, 'b');
    });

    test('skips already-completed sets in a later exercise', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0, done: true)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [
          _set('b', 0, done: true),
          _set('c', 1),
        ]),
      ]);
      expect(nextTargetAfter(s, 'a')!.setId, 'c');
    });

    test('is null when the completed set was the last pending one', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0, done: true)]),
      ]);
      expect(nextTargetAfter(s, 'a'), isNull);
    });

    test(
        'picks the smallest matching setIndex even when the set list is not '
        'sorted by setIndex', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [
          _set('c', 2), // out of order on purpose
          _set('a', 0, done: true),
          _set('b', 1),
        ]),
      ]);
      final target = nextTargetAfter(s, 'a')!;
      expect(target.setId, 'b');
      expect(target.setIndex, 1);
    });
  });

  group('restSecondsAfter', () {
    test('uses the rest of the exercise the completed set belongs to', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, restSeconds: 120, sets: [
          _set('a', 0, done: true),
          _set('b', 1),
        ]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, restSeconds: 60, sets: [_set('c', 0)]),
      ]);
      expect(restSecondsAfter(s, 'a'), 120);
    });

    test('still uses the current exercise rest when crossing into the next',
        () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, restSeconds: 120,
            sets: [_set('a', 0, done: true)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, restSeconds: 60,
            sets: [_set('c', 0)]),
      ]);
      expect(restSecondsAfter(s, 'a'), 120);
    });

    test('is zero after the final set of the whole session', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, restSeconds: 120,
            sets: [_set('a', 0, done: true)]),
      ]);
      expect(restSecondsAfter(s, 'a'), 0);
      expect(isLastSetOfSession(s, 'a'), isTrue);
    });
  });

  group('reordering', () {
    test('moveToEnd sends the exercise behind every other pending one', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('b', 0)]),
        _ex('e3', 'Row', sortOrder: 2, sets: [_set('c', 0)]),
      ]);
      expect(moveToEnd(s, 'e1'), ['e2', 'e3', 'e1']);
    });

    test('moveToEnd keeps completed exercises anchored at the front', () {
      final s = _session([
        _ex('e0', 'Warmup', sortOrder: 0, sets: [_set('z', 0, done: true)]),
        _ex('e1', 'Bench Press', sortOrder: 1, sets: [_set('a', 0)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 2, sets: [_set('b', 0)]),
      ]);
      expect(moveToEnd(s, 'e1'), ['e0', 'e2', 'e1']);
    });

    test('reorderPending indexes into the pending sublist only', () {
      final s = _session([
        _ex('e0', 'Warmup', sortOrder: 0, sets: [_set('z', 0, done: true)]),
        _ex('e1', 'Bench Press', sortOrder: 1, sets: [_set('a', 0)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 2, sets: [_set('b', 0)]),
        _ex('e3', 'Row', sortOrder: 3, sets: [_set('c', 0)]),
      ]);
      // Drag "Row" (pending index 2) to the front of the pending list.
      expect(reorderPending(s, 2, 0), ['e0', 'e3', 'e1', 'e2']);
    });

    test(
        'reorderPending normalises a downward drag using RAW '
        'ReorderableListView.onReorder indices', () {
      final s = _session([
        _ex('e0', 'Warmup', sortOrder: 0, sets: [_set('z', 0, done: true)]),
        _ex('e1', 'Bench Press', sortOrder: 1, sets: [_set('a', 0)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 2, sets: [_set('b', 0)]),
        _ex('e3', 'Row', sortOrder: 3, sets: [_set('c', 0)]),
        _ex('e4', 'Curl', sortOrder: 4, sets: [_set('d', 0)]),
      ]);
      // Drag "Bench Press" (pending index 0) past two items.
      // ReorderableListView.onReorder reports newIndex BEFORE removal, i.e.
      // oldIndex: 0, newIndex: 2 — since this doesn't land at the very end,
      // it can only produce ['e0','e2','e1','e3','e4'] if `target -= 1` runs;
      // without it, clamping does NOT save the result (unlike a drag-to-end),
      // so this is the case that actually proves the normalisation fires.
      expect(reorderPending(s, 0, 2), ['e0', 'e2', 'e1', 'e3', 'e4']);
    });

    test('a partially completed exercise still counts as pending', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [
          _set('a', 0, done: true),
          _set('b', 1),
        ]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('c', 0)]),
      ]);
      expect(pendingExercises(s).map((e) => e.exercise.id), ['e1', 'e2']);
      expect(moveToEnd(s, 'e1'), ['e2', 'e1']);
    });

    test(
        'a zero-set exercise is vacuously complete, so it never blocks the '
        'finish gate or desyncs from firstPendingTarget/isLastSetOfSession',
        () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0, done: true)]),
        _ex('e2', 'Empty', sortOrder: 1, sets: []),
      ]);
      expect(s.exercises[1].isComplete, isTrue);
      expect(pendingExercises(s), isEmpty);
      expect(firstPendingTarget(s), isNull);
      expect(isLastSetOfSession(s, 'a'), isTrue);
    });
  });

  group('volume', () {
    test('sums weight x reps over completed strength sets only', () {
      final done = _set('a', 0, done: true)
          .copyWith(weight: const Value(80), reps: const Value(8));
      final pending = _set('b', 1)
          .copyWith(weight: const Value(80), reps: const Value(8));
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [done, pending]),
      ]);
      expect(s.completedVolume, 640);
    });
  });
}
