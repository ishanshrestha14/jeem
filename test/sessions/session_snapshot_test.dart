import 'package:async/async.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository exercises;
  late TemplateRepository templates;
  late SessionRepository sessions;

  setUp(() {
    db = testDatabase();
    exercises = ExerciseRepository(db);
    templates = TemplateRepository(db);
    sessions = SessionRepository(db);
  });
  tearDown(() => db.close());

  Future<String> pushTemplate() async {
    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
      name: 'Bench Press',
      loggingType: LoggingType.strengthWeightRepsRir,
      description: 'Flat barbell press.',
      notes: 'Pause on the chest.',
    );
    final plank = await exercises.create(
        name: 'Plank', loggingType: LoggingType.durationOnly);
    await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 3, restSeconds: 120,
        defaultRir: 2);
    await templates.addExercise(
        templateId: t.id, exerciseId: plank.id, targetSets: 2, restSeconds: 45,
        defaultDurationSeconds: 45);
    return t.id;
  }

  test('generates one set row per target set, in order', () async {
    final id = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    final session = (await sessions.watchSession(id.id).first)!;

    expect(session.exercises.map((e) => e.exercise.name),
        ['Bench Press', 'Plank']);
    expect(session.exercises[0].sets, hasLength(3));
    expect(session.exercises[1].sets, hasLength(2));
    expect(session.exercises[0].sets.map((s) => s.setIndex), [0, 1, 2]);
    expect(session.totalSets, 5);
    expect(session.completedSets, 0);
  });

  test('snapshots exercise description, notes and logging type', () async {
    final id = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    final session = (await sessions.watchSession(id.id).first)!;
    final bench = session.exercises.first.exercise;

    expect(bench.description, 'Flat barbell press.');
    expect(bench.notes, 'Pause on the chest.');
    expect(bench.loggingType, LoggingType.strengthWeightRepsRir);
    expect(bench.restSeconds, 120);
    expect(bench.targetSets, 3);
  });

  test('seeds default RIR and default duration into the generated sets',
      () async {
    final id = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    final session = (await sessions.watchSession(id.id).first)!;

    expect(session.exercises[0].sets.every((s) => s.rir == 2), isTrue);
    expect(session.exercises[0].sets.every((s) => s.weight == null), isTrue);
    expect(
        session.exercises[1].sets.every((s) => s.durationSeconds == 45), isTrue);
  });

  test('editing the session never touches the template', () async {
    final templateId = await pushTemplate();
    final started = await sessions.startFromTemplate(templateId, weightUnit: 'kg');
    var session = (await sessions.watchSession(started.id).first)!;

    await sessions.updateSessionExercise(
      session.exercises.first.exercise.copyWith(restSeconds: 300),
    );
    await sessions.reorderSessionExercises(started.id, [
      session.exercises[1].exercise.id,
      session.exercises[0].exercise.id,
    ]);

    final template = (await templates.watchTemplate(templateId).first)!;
    expect(template.exercises.map((e) => e.name), ['Bench Press', 'Plank']);
    expect(template.exercises.first.config.restSeconds, 120);

    session = (await sessions.watchSession(started.id).first)!;
    expect(session.exercises.map((e) => e.exercise.name), ['Plank', 'Bench Press']);
  });

  test('watchActiveSession finds the active session and drops finished ones',
      () async {
    final started = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    expect((await sessions.watchActiveSession().first)?.session.id, started.id);

    await sessions.finishSession(started.id, notes: 'Felt strong');

    expect(await sessions.watchActiveSession().first, isNull);
    final finished = (await sessions.watchSession(started.id).first)!;
    expect(finished.session.status, SessionStatus.completed);
    expect(finished.session.notes, 'Felt strong');
    expect(finished.session.endedAt, isNotNull);
  });

  test(
      'renaming the library exercise or editing the template after a session '
      'has started never changes what the running session shows '
      '(PRD §12.5: history stays valid even when the library changes)',
      () async {
    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
      name: 'Bench Press',
      loggingType: LoggingType.strengthWeightRepsRir,
    );
    final te = await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 2, restSeconds: 120);

    final started = await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    // Mutate the library exercise and the template config AFTER the
    // snapshot was taken.
    await exercises.update(bench.copyWith(name: 'Incline Bench Press'));
    await templates.updateTemplateExercise(te.copyWith(restSeconds: 200));

    final session = (await sessions.watchSession(started.id).first)!;
    expect(session.exercises.single.exercise.name, 'Bench Press');
    expect(session.exercises.single.exercise.restSeconds, 120);
  });

  // --- Live-subscription tests -------------------------------------------
  //
  // Every test above uses `.first`, which spins up a fresh controller and
  // subscription per call and is satisfied by the single emission that
  // `onListen` schedules — it would pass identically even if the
  // `tableUpdates` listener inside `_watchAggregate` were wired to the
  // wrong tables, or never fired at all. These tests instead subscribe
  // once, consume an initial emission, mutate through the SAME
  // subscription, and assert a LATER emission reflects the mutation —
  // the only way to prove the reactive path (not just the initial fetch)
  // actually works. This mirrors the Task 6 lesson: identically-shaped
  // code there hid a `cancel()` that hung forever.

  test('watchSession emits again when a set is updated', () async {
    final id = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    final queue = StreamQueue(sessions.watchSession(id.id));
    addTearDown(queue.cancel);

    final first = await queue.next;
    final targetSet = first!.exercises.first.sets.first;
    expect(targetSet.weight, isNull);

    await sessions.updateSet(targetSet.copyWith(weight: const Value(62.5)));

    final updated = await queue.next;
    final updatedSet =
        updated!.exercises.first.sets.firstWhere((s) => s.id == targetSet.id);
    expect(updatedSet.weight, 62.5);
  });

  test('watchSession emits again when a set is added', () async {
    final id = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    final queue = StreamQueue(sessions.watchSession(id.id));
    addTearDown(queue.cancel);

    final first = await queue.next;
    final sessionExerciseId = first!.exercises.first.exercise.id;
    expect(first.exercises.first.sets, hasLength(3));

    await sessions.addSet(sessionExerciseId);

    final updated = await queue.next;
    expect(updated!.exercises.first.sets, hasLength(4));
    expect(updated.exercises.first.sets.last.setIndex, 3);
  });

  test('watchActiveSession emits null again after the session finishes',
      () async {
    final started = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    final queue = StreamQueue(sessions.watchActiveSession());
    addTearDown(queue.cancel);

    final first = await queue.next;
    expect(first?.session.id, started.id);

    await sessions.finishSession(started.id, notes: 'Done');

    final after = await queue.next;
    expect(after, isNull);
  });

  test(
      'a live watchSession subscription cancels cleanly instead of hanging '
      '(the Task 6 regression)', () async {
    final id = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    final queue = StreamQueue(sessions.watchSession(id.id));
    await queue.next;

    // If `onCancel` ever hangs again (the exact Task 6 failure mode), this
    // times out and fails the test instead of stalling the whole suite.
    await (queue.cancel() ?? Future<void>.value())
        .timeout(const Duration(seconds: 5));
  });
}
