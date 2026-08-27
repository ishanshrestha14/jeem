import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/programs/data/program_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';

/// T-024: `deleteTemplate` becomes a soft delete, matching sessions. A routine
/// is the thing your logged history was built from, so dropping the row
/// outright is the one delete here that destroys context you might want back.
void main() {
  late AppDatabase db;
  late TemplateRepository templates;
  late ExerciseRepository exercises;

  setUp(() {
    db = testDatabase();
    templates = TemplateRepository(db);
    exercises = ExerciseRepository(db);
  });
  tearDown(() => db.close());

  Future<WorkoutTemplate> aRoutine({String name = 'Pull'}) async {
    final t = await templates.createTemplate(name: name);
    final e = await exercises.create(
        name: 'Row', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(templateId: t.id, exerciseId: e.id);
    return t;
  }

  test('the row survives, stamped deletedAt', () async {
    final t = await aRoutine();

    await templates.deleteTemplate(t.id);

    final row = await (db.select(db.workoutTemplates)
          ..where((x) => x.id.equals(t.id)))
        .getSingleOrNull();
    expect(row, isNotNull, reason: 'soft, not dropped');
    expect(row!.deletedAt, isNotNull);
  });

  test('it leaves the routine list', () async {
    final t = await aRoutine();
    expect(await templates.watchSummaries().first, hasLength(1));

    await templates.deleteTemplate(t.id);

    expect(await templates.watchSummaries().first, isEmpty);
  });

  test('it can no longer be opened', () async {
    final t = await aRoutine();

    await templates.deleteTemplate(t.id);

    expect(await templates.watchTemplate(t.id).first, isNull);
  });

  test('starting it still fails loudly rather than silently', () async {
    // T-016's defence must survive the change: the lookup filters deletedAt,
    // so a soft-deleted routine is as absent as a dropped one.
    final t = await aRoutine();
    await templates.deleteTemplate(t.id);

    expect(
      () => SessionRepository(db).startFromTemplate(t.id, weightUnit: 'kg'),
      throwsA(isA<RoutineNotFound>()),
    );
  });

  test('a program stops listing it', () async {
    final programs = ProgramRepository(db);
    final t = await aRoutine();
    final p = await programs.create(name: 'PPL');
    await programs.addRoutine(programId: p.id, templateId: t.id);
    expect((await programs.watchProgram(p.id).first)!.routines, hasLength(1));

    await templates.deleteTemplate(t.id);

    expect((await programs.watchProgram(p.id).first)!.routines, isEmpty);
  });

  test('a workout already logged from it is untouched', () async {
    // The whole point of soft-deleting: a session snapshots the routine, so
    // history was never at risk — but the routine row is now recoverable too.
    final t = await aRoutine();
    final sessions = SessionRepository(db);
    final s = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    await sessions.finishSession(s.id);

    await templates.deleteTemplate(t.id);

    final history = await sessions.watchCompletedSessions().first;
    expect(history, hasLength(1));
    expect(history.single.exercises.single.exercise.name, 'Row');
  });

  test('deleting twice is harmless', () async {
    final t = await aRoutine();

    await templates.deleteTemplate(t.id);
    await templates.deleteTemplate(t.id);

    expect(await templates.watchSummaries().first, isEmpty);
  });
}
