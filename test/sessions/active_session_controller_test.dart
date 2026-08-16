import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> seedAndStart({int restSeconds = 90, int sets = 2}) async {
    final exercises = ExerciseRepository(db);
    final templates = TemplateRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    for (final n in ['Bench Press', 'Lat Pulldown']) {
      final e = await exercises.create(
          name: n, loggingType: LoggingType.strengthWeightRepsRir);
      await templates.addExercise(
          templateId: t.id, exerciseId: e.id,
          targetSets: sets, restSeconds: restSeconds);
    }
    await container.read(sessionRepositoryProvider)
        .startFromTemplate(t.id, weightUnit: 'kg');

    // Keep the autoDispose provider alive for the rest of the test. Without
    // an active listener, `container.read(...)` alone doesn't prevent
    // disposal, so a real-time gap (`Future.delayed`, used below to exercise
    // elapsed-time behaviour) can let the container dispose and silently
    // recreate the controller between statements — dropping the in-memory
    // -only `focusedSetId`/`restJustFinished` fields even though the
    // persisted DB state is untouched. `container.invalidate(...)` (used by
    // "rest state is persisted so it survives a controller rebuild") still
    // forces a fresh rebuild despite this listener. Listening only after
    // the session exists (rather than in `setUp`) avoids caching a
    // premature "no active session" build.
    container.listen(activeSessionControllerProvider, (_, _) {});
  }

  setUp(() {
    db = testDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  Future<ActiveSessionState> state() async {
    final ActiveSessionState? value =
        await container.read(activeSessionControllerProvider.future);
    return value!;
  }

  test('completing a set stamps it and starts rest for that exercise', () async {
    await seedAndStart(restSeconds: 120);
    final controller = container.read(activeSessionControllerProvider.notifier);

    final firstSetId = (await state()).session.exercises.first.sets.first.id;
    await controller.completeSet(firstSetId);

    final s = await state();
    expect(s.session.setById(firstSetId)!.completedAt, isNotNull);
    expect(s.rest.status, RestTimerStatus.running);
    expect(s.rest.totalSeconds, 120);
    expect(s.rest.nextTarget!.setIndex, 1);
  });

  test('rest of zero seconds never starts a timer', () async {
    await seedAndStart(restSeconds: 0);
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.completeSet((await state()).session.exercises.first.sets.first.id);

    final s = await state();
    expect(s.rest.isActive, isFalse);
    // isActive alone is also true for RestTimerStatus.finished (which is what
    // RestTimer.start(seconds: 0, ...) itself returns), so this would pass
    // even if the controller's own `restSeconds > 0` guard were missing.
    // Assert idle explicitly to pin down the controller's own behaviour.
    expect(s.rest.status, RestTimerStatus.idle);
    expect(s.currentTarget!.setIndex, 1);
  });

  test('the final set of the session starts no rest', () async {
    await seedAndStart(sets: 1);
    final controller = container.read(activeSessionControllerProvider.notifier);

    for (final ex in (await state()).session.exercises) {
      await controller.completeSet(ex.sets.single.id);
    }

    final s = await state();
    expect(s.rest.isActive, isFalse);
    expect(s.currentTarget, isNull);
    expect(s.session.completedSets, 2);
  });

  test('completing another set while resting restarts rest from the new set',
      () async {
    await seedAndStart(restSeconds: 90);
    final controller = container.read(activeSessionControllerProvider.notifier);

    final sets = (await state()).session.exercises.first.sets;
    await controller.completeSet(sets[0].id);
    final firstRestEnd = (await state()).rest.endsAt;

    await controller.completeSet(sets[1].id);
    final s = await state();

    expect(s.rest.status, RestTimerStatus.running);
    expect(s.rest.afterSetId, sets[1].id);
    expect(s.rest.endsAt, isNot(firstRestEnd));
  });

  test('completeSet starting a fresh rest clears a stale restJustFinished',
      () async {
    await seedAndStart(restSeconds: 90);
    final controller = container.read(activeSessionControllerProvider.notifier);
    // Auto-focus off so `skipRest` below actually leaves a stale
    // `restJustFinished: true` to clear — with it on (the default), Task
    // 15's auto-focus consumes the flag itself, which would make this
    // assertion pass vacuously regardless of whether `completeSet` clears
    // anything.
    await controller.setAutoFocusNextSet(false);
    final sets = (await state()).session.exercises.first.sets;

    await controller.completeSet(sets[0].id);
    await controller.skipRest();
    expect((await state()).restJustFinished, isTrue);

    await controller.completeSet(sets[1].id);
    final s = await state();
    expect(s.rest.status, RestTimerStatus.running);
    expect(s.restJustFinished, isFalse);
  });

  test('uncompleting the set that owns the active rest cancels it', () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);
    final setId = (await state()).session.exercises.first.sets.first.id;

    await controller.completeSet(setId);
    expect((await state()).rest.isActive, isTrue);

    await controller.uncompleteSet(setId);
    final s = await state();
    expect(s.rest.status, RestTimerStatus.idle);
    expect(s.session.setById(setId)!.completedAt, isNull);
  });

  test('uncompleting an older set leaves the active rest alone', () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);
    final sets = (await state()).session.exercises.first.sets;

    await controller.completeSet(sets[0].id);
    await controller.completeSet(sets[1].id);
    await controller.uncompleteSet(sets[0].id);

    expect((await state()).rest.status, RestTimerStatus.running);
  });

  test('rest state is persisted so it survives a controller rebuild', () async {
    await seedAndStart(restSeconds: 90);
    final controller = container.read(activeSessionControllerProvider.notifier);
    await controller.completeSet((await state()).session.exercises.first.sets.first.id);
    final endsAt = (await state()).rest.endsAt;

    container.invalidate(activeSessionControllerProvider);
    final restored = await state();

    expect(restored.rest.status, RestTimerStatus.running);
    expect(restored.rest.endsAt, endsAt);
  });

  test('doLater sends the current exercise to the back without touching rest',
      () async {
    await seedAndStart(restSeconds: 90);
    final controller = container.read(activeSessionControllerProvider.notifier);
    final firstId = (await state()).session.exercises.first.exercise.id;
    final firstSetId = (await state()).session.exercises.first.sets.first.id;

    // A genuinely running rest, so cancelling/restarting it in doLater
    // would be observable — completing on an idle rest can't distinguish
    // "left alone" from "touched" (both look idle).
    await controller.completeSet(firstSetId);
    final restBefore = (await state()).rest;
    expect(restBefore.status, RestTimerStatus.running);

    await controller.doLater(firstId);

    final s = await state();
    expect(s.session.exercises.last.exercise.id, firstId);
    expect(s.currentTarget!.exerciseName, 'Lat Pulldown');
    expect(s.rest.status, RestTimerStatus.running);
    expect(s.rest.endsAt, restBefore.endsAt);
    expect(s.rest.afterSetId, restBefore.afterSetId);
  });

  test('editing rest mid-rest extends the running timer', () async {
    await seedAndStart(restSeconds: 60);
    final controller = container.read(activeSessionControllerProvider.notifier);
    final exId = (await state()).session.exercises.first.exercise.id;
    await controller.completeSet((await state()).session.exercises.first.sets.first.id);

    // Let real wall-clock time pass so the edit has a non-trivial elapsed
    // portion to anchor on. Without this, a naive `endsAt = now + newTotal`
    // reset and a correct elapsed-anchored rebuild are indistinguishable —
    // both start from ~0s elapsed.
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    await controller.setExerciseRest(exId, 180);

    final s = await state();
    expect(s.rest.totalSeconds, 180);
    expect(s.session.exercises.first.exercise.restSeconds, 180);

    final remaining = s.rest.remainingAt(DateTime.now()).inSeconds;
    // Correct (elapsed-anchored): ~178s left (180 - ~2s elapsed).
    // Naive reset (`endsAt = now + 180`) would read ~179-180s left.
    expect(remaining, lessThanOrEqualTo(178));
    expect(remaining, greaterThanOrEqualTo(175));
  });

  test(
      'pauseSession pauses the session and any running rest; '
      'resumeSession resumes both', () async {
    await seedAndStart(restSeconds: 90);
    final controller = container.read(activeSessionControllerProvider.notifier);
    await controller.completeSet((await state()).session.exercises.first.sets.first.id);
    expect((await state()).rest.status, RestTimerStatus.running);

    await controller.pauseSession();
    final paused = await state();
    expect(paused.session.session.status, SessionStatus.paused);
    expect(paused.rest.status, RestTimerStatus.paused);

    await controller.resumeSession();
    final resumed = await state();
    expect(resumed.session.session.status, SessionStatus.active);
    expect(resumed.rest.status, RestTimerStatus.running);
  });

  test(
      'resumeSession measures the full pause duration even if an unrelated '
      'write happens mid-pause', () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.pauseSession();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    // An unrelated write to the session row while paused (any call that
    // goes through `saveRestState`, e.g. `cancelRest`) restamps
    // `updatedAt` — the buggy `updatedAt`-based version of resumeSession
    // would measure the pause from here instead of from the real
    // `pausedAt`, undercounting it.
    await controller.cancelRest();
    // Force a fresh rehydration from the DB row so the next read reflects
    // the `updatedAt` that `cancelRest`'s `saveRestState` just wrote,
    // rather than the controller's in-memory (stale) session snapshot.
    container.invalidate(activeSessionControllerProvider);
    await state();
    final controller2 = container.read(activeSessionControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 700));

    await controller2.resumeSession();
    final s = await state();
    // ~1.4s really elapsed since pauseSession; the `updatedAt`-based bug
    // would only see the ~0.7s since the mid-pause write and round to 0.
    expect(s.session.session.pausedSeconds, greaterThanOrEqualTo(1));
    expect(s.session.session.pausedAt, isNull);
  });

  test(
      'shrinking rest below the elapsed portion finishes it through the '
      'same path as skipRest/settle', () async {
    await seedAndStart(restSeconds: 60);
    final controller = container.read(activeSessionControllerProvider.notifier);
    // Auto-focus off, so Task 15's auto-focus doesn't consume
    // `restJustFinished` and this test can assert the finish path fired at
    // all, independent of the toggle.
    await controller.setAutoFocusNextSet(false);
    final exId = (await state()).session.exercises.first.exercise.id;
    await controller.completeSet((await state()).session.exercises.first.sets.first.id);
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    // Shrinking the total to less than what's already elapsed should behave
    // exactly like the rest completing naturally: finished status, and
    // restJustFinished set (so Task 14's "rest complete" banner and Task
    // 15's auto-focus both fire), not a silent plain state update.
    await controller.setExerciseRest(exId, 1);

    final s = await state();
    expect(s.rest.status, RestTimerStatus.finished);
    expect(s.restJustFinished, isTrue);
  });

  test('finishing a session clears it from the active provider', () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.finish(notes: 'Done');

    expect(await container.read(activeSessionControllerProvider.future), isNull);
  });

  test('auto-focus next set moves focus when rest finishes mid-exercise',
      () async {
    await seedAndStart(restSeconds: 1, sets: 3);
    final controller = container.read(activeSessionControllerProvider.notifier);
    final sets = (await state()).session.exercises.first.sets;

    await controller.completeSet(sets[0].id);
    await controller.skipRest(); // finishes rest immediately
    await controller.settle();

    final s = await state();
    expect(s.currentTarget!.setId, sets[1].id);
    expect(s.restJustFinished, isFalse); // consumed by the auto-focus
  });

  test('with auto-focus off, rest completion parks in a finished state',
      () async {
    await seedAndStart(restSeconds: 1, sets: 3);
    final controller = container.read(activeSessionControllerProvider.notifier);
    await controller.setAutoFocusNextSet(false);
    final sets = (await state()).session.exercises.first.sets;

    await controller.completeSet(sets[0].id);
    await controller.skipRest();
    await controller.settle();

    final s = await state();
    expect(s.restJustFinished, isTrue);
    expect(s.rest.status, RestTimerStatus.finished);

    controller.goToNextTarget();
    final after = await state();
    expect(after.currentTarget!.setId, sets[1].id);
    expect(after.restJustFinished, isFalse);
  });

  test('auto-focus next exercise applies only across an exercise boundary',
      () async {
    // sets: 1 means completing Bench Press's only set makes Lat Pulldown's
    // first set the next pending target regardless of auto-focus — that's
    // just `firstPendingTarget`. The original assertion here
    // (`currentTarget.exerciseName == 'Lat Pulldown'`) passed even with
    // auto-focus deleted entirely, since `currentTarget` falls back to
    // `firstPendingTarget` whenever `focusedSetId` is unset. Assert
    // `focusedSetId` directly instead — that field is only ever set by the
    // auto-focus path — so this genuinely proves it ran.
    await seedAndStart(restSeconds: 1, sets: 1);
    final controller = container.read(activeSessionControllerProvider.notifier);
    await controller.setAutoFocusNextSet(false);
    await controller.setAutoFocusNextExercise(true);

    final latPulldownFirstSetId =
        (await state()).session.exercises[1].sets.first.id;

    await controller.completeSet(
        (await state()).session.exercises.first.sets.single.id);
    await controller.skipRest();
    await controller.settle();

    final s = await state();
    expect(s.focusedSetId, latPulldownFirstSetId);
    expect(s.currentTarget!.exerciseName, 'Lat Pulldown');
    expect(s.restJustFinished, isFalse); // consumed by the auto-focus
  });

  test(
      'auto-focus next exercise does NOT apply within the same exercise '
      '("only across an exercise boundary")', () async {
    // Same toggle configuration as the test above (autoFocusNextExercise:
    // true, autoFocusNextSet: false) but sets: 2, so the target after the
    // first set's rest finishes is the *same* exercise's next set — a
    // same-exercise boundary, which only `autoFocusNextSet` governs.
    // `autoFocusNextExercise` must have no effect here: focus must stay
    // unset and the rest must park in the finished state waiting on the
    // user, exactly like "with auto-focus off, rest completion parks in a
    // finished state" above.
    await seedAndStart(restSeconds: 1, sets: 2);
    final controller = container.read(activeSessionControllerProvider.notifier);
    await controller.setAutoFocusNextSet(false);
    await controller.setAutoFocusNextExercise(true);
    final sets = (await state()).session.exercises.first.sets;

    await controller.completeSet(sets[0].id);
    await controller.skipRest();
    await controller.settle();

    final s = await state();
    expect(s.focusedSetId, isNull);
    expect(s.restJustFinished, isTrue);
    expect(s.currentTarget!.setId, sets[1].id);
  });

  test('neither toggle auto-completes anything', () async {
    await seedAndStart(restSeconds: 1, sets: 3);
    final controller = container.read(activeSessionControllerProvider.notifier);
    final sets = (await state()).session.exercises.first.sets;

    await controller.completeSet(sets[0].id);
    await controller.skipRest();
    await controller.settle();

    expect((await state()).session.setById(sets[1].id)!.completedAt, isNull);
  });

  // The old "reordering during active rest does not cancel it, and the next
  // target is recomputed from the new order" test is deleted rather than
  // fixed: it seeded a single pending exercise and called
  // `controller.reorder(0, 0)` (a no-op — nothing was reordered) and never
  // actually asserted a recomputed target, so it passed vacuously even with
  // that recompute logic deleted. The very next test below,
  // "reordering during active rest changes which exercise the finished rest
  // auto-focuses into", already does everything this one claimed to: a
  // genuine multi-exercise reorder mid-rest, plus an assertion
  // (`currentTarget.sessionExerciseId == squatId` after the rest finishes)
  // that depends on the reorder having actually taken effect. Keeping both
  // would just be a second, weaker copy of the same coverage.

  test(
      'reordering during active rest changes which exercise the finished '
      'rest auto-focuses into', () async {
    // A 3-exercise session so a mid-rest reorder actually changes what
    // "next" resolves to: [Bench Press, Lat Pulldown, Squat]. Completing
    // Bench Press's only set targets Lat Pulldown next; reordering Lat
    // Pulldown behind Squat mid-rest must redirect the finished rest's
    // auto-focus to Squat instead — proving `_handleRestFinished` recomputes
    // from current order rather than the target captured when rest started.
    final exercisesRepo = ExerciseRepository(db);
    final templates = TemplateRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    for (final n in ['Bench Press', 'Lat Pulldown', 'Squat']) {
      final e = await exercisesRepo.create(
          name: n, loggingType: LoggingType.strengthWeightRepsRir);
      await templates.addExercise(
          templateId: t.id, exerciseId: e.id, targetSets: 1, restSeconds: 1);
    }
    await container
        .read(sessionRepositoryProvider)
        .startFromTemplate(t.id, weightUnit: 'kg');
    container.listen(activeSessionControllerProvider, (_, _) {});

    final controller = container.read(activeSessionControllerProvider.notifier);
    await controller.setAutoFocusNextExercise(true);

    final exercises = (await state()).session.exercises;
    final latId = exercises[1].exercise.id;
    final squatId = exercises[2].exercise.id;

    await controller.completeSet(exercises[0].sets.single.id);
    expect((await state()).rest.nextTarget!.sessionExerciseId, latId);

    // Reorder pending exercises [Lat Pulldown, Squat] -> [Squat, Lat
    // Pulldown] while the rest for Bench Press is still running.
    // `reorderPending`'s `newIndex` follows `ReorderableListView` semantics
    // (pre-removal index), so moving index 0 to the end of a 2-item list is
    // `reorder(0, 2)`, not `reorder(0, 1)` (which is a no-op here).
    await controller.reorder(0, 2);
    expect((await state()).rest.status, RestTimerStatus.running);

    await controller.skipRest();
    await controller.settle();

    final s = await state();
    expect(s.currentTarget!.sessionExerciseId, squatId);
  });
}
