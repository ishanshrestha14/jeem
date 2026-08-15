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

  test('doLater sends the current exercise to the back', () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);
    final firstId = (await state()).session.exercises.first.exercise.id;

    await controller.doLater(firstId);

    final s = await state();
    expect(s.session.exercises.last.exercise.id, firstId);
    expect(s.currentTarget!.exerciseName, 'Lat Pulldown');
  });

  test('editing rest mid-rest extends the running timer', () async {
    await seedAndStart(restSeconds: 60);
    final controller = container.read(activeSessionControllerProvider.notifier);
    final exId = (await state()).session.exercises.first.exercise.id;
    await controller.completeSet((await state()).session.exercises.first.sets.first.id);

    await controller.setExerciseRest(exId, 180);

    final s = await state();
    expect(s.rest.totalSeconds, 180);
    expect(s.session.exercises.first.exercise.restSeconds, 180);
  });

  test('finishing a session clears it from the active provider', () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.finish(notes: 'Done');

    expect(await container.read(activeSessionControllerProvider.future), isNull);
  });
}
