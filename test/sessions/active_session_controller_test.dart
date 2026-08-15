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
}
