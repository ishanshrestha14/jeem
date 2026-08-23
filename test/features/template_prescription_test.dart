import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_models.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';

/// T-002: a routine prescribes each set individually, and a session starts
/// carrying that plan without confusing it for what was actually lifted.
void main() {
  late AppDatabase db;
  late TemplateRepository templates;
  late ExerciseRepository exercises;
  late SessionRepository sessions;

  setUp(() {
    db = testDatabase();
    templates = TemplateRepository(db);
    exercises = ExerciseRepository(db);
    sessions = SessionRepository(db);
  });
  tearDown(() => db.close());

  Future<({String templateId, String templateExerciseId})> routine() async {
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    final te = await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 2);
    return (templateId: t.id, templateExerciseId: te.id);
  }

  test('two sets of one exercise can be prescribed differently', () async {
    final r = await routine();
    final sets = await templates.setsFor(r.templateExerciseId);

    // A top set, then a back-off — the case a single per-exercise weight
    // could never express, which is why the schema moved to rows.
    await templates.updateSet(sets[0].id,
        weight: const Value(70), reps: const Value(8));
    await templates.updateSet(sets[1].id,
        weight: const Value(60), reps: const Value(6));

    final loaded = (await templates.watchTemplate(r.templateId).first)!;
    final planned = loaded.exercises.single.sets;
    expect([for (final s in planned) '${s.weight}x${s.reps}'],
        ['70.0x8', '60.0x6']);
    expect(loaded.exercises.single.targetSets, 2,
        reason: 'the set count is the row count now');
  });

  test('a rep range is derived from repsMax rather than a mode flag', () async {
    final r = await routine();
    final sets = await templates.setsFor(r.templateExerciseId);
    await templates.updateSet(sets[0].id,
        reps: const Value(8), repsMax: const Value(10));

    final planned = await templates.setsFor(r.templateExerciseId);
    expect(describeTemplateSet(planned[0]), '8-10 reps');
    expect(describeTemplateSet(planned[1]), isNull,
        reason: 'an unprescribed set describes as nothing, not as "0 reps"');
  });

  test('starting a session copies the plan, leaving the logged values empty',
      () async {
    final r = await routine();
    final sets = await templates.setsFor(r.templateExerciseId);
    await templates.updateSet(sets[0].id,
        weight: const Value(70), reps: const Value(8));
    await templates.updateSet(sets[1].id,
        weight: const Value(60), reps: const Value(6), repsMax: const Value(8));

    await sessions.startFromTemplate(r.templateId, weightUnit: 'kg');
    final session = (await sessions.watchActiveSession().first)!;
    final logged = session.exercises.single.sets;

    expect([for (final s in logged) s.plannedWeight], [70, 60]);
    expect([for (final s in logged) s.plannedReps], [8, 6]);
    expect([for (final s in logged) s.plannedRepsMax], [null, 8]);
    // The plan is a suggestion, not a claim that it happened.
    expect(logged.every((s) => s.weight == null && s.reps == null), isTrue);
    expect(logged.every((s) => s.completedAt == null), isTrue);
  });

  test('editing the routine afterwards does not rewrite a running session',
      () async {
    final r = await routine();
    final sets = await templates.setsFor(r.templateExerciseId);
    await templates.updateSet(sets[0].id, weight: const Value(70));

    await sessions.startFromTemplate(r.templateId, weightUnit: 'kg');
    await templates.updateSet(sets[0].id, weight: const Value(100));

    final session = (await sessions.watchActiveSession().first)!;
    expect(session.exercises.single.sets.first.plannedWeight, 70,
        reason: 'a session is a snapshot, not a live view of the routine');
  });

  test('adding a set copies the previous one rather than starting blank',
      () async {
    final r = await routine();
    final sets = await templates.setsFor(r.templateExerciseId);
    await templates.updateSet(sets.last.id,
        weight: const Value(60), reps: const Value(6));

    final added = await templates.addSet(r.templateExerciseId);
    expect(added.weight, 60);
    expect(added.reps, 6);
    expect(added.setIndex, 2);
  });

  test('removing a set resequences the rest', () async {
    final r = await routine();
    await templates.addSet(r.templateExerciseId);
    var sets = await templates.setsFor(r.templateExerciseId);
    expect(sets, hasLength(3));

    await templates.removeSet(sets[1].id);
    sets = await templates.setsFor(r.templateExerciseId);
    expect([for (final s in sets) s.setIndex], [0, 1]);
  });

  test('duplicating a routine carries its prescription across', () async {
    final r = await routine();
    final sets = await templates.setsFor(r.templateExerciseId);
    await templates.updateSet(sets[0].id,
        weight: const Value(70), reps: const Value(8));

    final copy = await templates.duplicateTemplate(r.templateId);
    final loaded = (await templates.watchTemplate(copy.id).first)!;
    final planned = loaded.exercises.single.sets;

    expect(planned, hasLength(2));
    expect(planned.first.weight, 70,
        reason: 'the numbers are the point of duplicating a routine');
  });
}
