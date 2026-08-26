import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';

/// S-029's "Replace exercise": swap the exercise, keep its prescribed sets.
/// The gym problem it solves is the machine being taken — you want the same
/// plan against a different movement, not to rebuild it.
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

  /// A routine exercise with two prescribed sets: 70x8 and 60x6.
  Future<(String templateExerciseId, String originalId)> seed({
    LoggingType type = LoggingType.strengthWeightRepsRir,
  }) async {
    final t = await templates.createTemplate(name: 'Pull');
    final original = await exercises.create(name: 'Barbell Row', loggingType: type);
    final te = await templates.addExercise(
        templateId: t.id, exerciseId: original.id, targetSets: 2);
    final sets = await templates.setsFor(te.id);
    await templates.updateSet(sets[0].id,
        weight: const Value(70), reps: const Value(8));
    await templates.updateSet(sets[1].id,
        weight: const Value(60), reps: const Value(6));
    return (te.id, original.id);
  }

  test('the exercise changes and the prescription survives', () async {
    final (teId, _) = await seed();
    final replacement = await exercises.create(
        name: 'Cable Row', loggingType: LoggingType.strengthWeightRepsRir);

    await templates.replaceExercise(teId, replacement.id);

    final row = await (db.select(db.templateExercises)
          ..where((t) => t.id.equals(teId)))
        .getSingle();
    expect(row.exerciseId, replacement.id);

    final sets = await templates.setsFor(teId);
    expect(sets, hasLength(2));
    expect(sets[0].weight, 70);
    expect(sets[0].reps, 8);
    expect(sets[1].weight, 60);
    expect(sets[1].reps, 6);
  });

  test('its position in the routine is unchanged', () async {
    final t = await templates.createTemplate(name: 'Pull');
    final a = await exercises.create(
        name: 'A', loggingType: LoggingType.strengthWeightRepsRir);
    final b = await exercises.create(
        name: 'B', loggingType: LoggingType.strengthWeightRepsRir);
    final c = await exercises.create(
        name: 'C', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(templateId: t.id, exerciseId: a.id);
    final second =
        await templates.addExercise(templateId: t.id, exerciseId: b.id);
    await templates.addExercise(templateId: t.id, exerciseId: c.id);
    final replacement = await exercises.create(
        name: 'B2', loggingType: LoggingType.strengthWeightRepsRir);

    await templates.replaceExercise(second.id, replacement.id);

    final rows = await (db.select(db.templateExercises)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    expect(rows[1].exerciseId, replacement.id,
        reason: 'a replacement takes the place of what it replaced');
  });

  test('swapping strength for duration drops numbers that cannot transfer',
      () async {
    final (teId, _) = await seed();
    final plank = await exercises.create(
        name: 'Plank', loggingType: LoggingType.durationOnly);

    await templates.replaceExercise(teId, plank.id);

    final sets = await templates.setsFor(teId);
    // The set *count* is still what you planned; weight and reps are not
    // meaningful for a duration exercise and would render as nonsense.
    expect(sets, hasLength(2));
    expect(sets.every((s) => s.weight == null && s.reps == null), isTrue);
  });

  test('swapping duration for strength drops the duration', () async {
    final (teId, _) = await seed(type: LoggingType.durationOnly);
    final sets = await templates.setsFor(teId);
    await templates.updateSet(sets[0].id, durationSeconds: const Value(45));
    final row = await exercises.create(
        name: 'Cable Row', loggingType: LoggingType.strengthWeightRepsRir);

    await templates.replaceExercise(teId, row.id);

    final after = await templates.setsFor(teId);
    expect(after.every((s) => s.durationSeconds == null), isTrue);
  });

  test('replacing with the same logging type keeps everything', () async {
    final (teId, _) = await seed();
    final replacement = await exercises.create(
        name: 'Cable Row', loggingType: LoggingType.strengthWeightRepsRir);

    await templates.replaceExercise(teId, replacement.id);

    expect((await templates.setsFor(teId)).first.weight, 70);
  });

  test('replacing with an unknown exercise changes nothing', () async {
    final (teId, originalId) = await seed();

    await expectLater(
      () => templates.replaceExercise(teId, 'no-such-exercise'),
      throwsA(isA<StateError>()),
    );

    final row = await (db.select(db.templateExercises)
          ..where((t) => t.id.equals(teId)))
        .getSingle();
    expect(row.exerciseId, originalId);
  });
}
