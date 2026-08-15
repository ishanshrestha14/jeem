import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'test_database.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository exercises;
  late TemplateRepository templates;

  setUp(() {
    db = testDatabase();
    exercises = ExerciseRepository(db);
    templates = TemplateRepository(db);
  });
  tearDown(() => db.close());

  Future<String> makeExercise(String name) async {
    final e = await exercises.create(
        name: name, loggingType: LoggingType.strengthWeightRepsRir);
    return e.id;
  }

  test('adds exercises with default sets and rest, in insertion order',
      () async {
    final t = await templates.createTemplate(name: 'Push');
    await templates.addExercise(
        templateId: t.id, exerciseId: await makeExercise('Bench Press'));
    await templates.addExercise(
        templateId: t.id, exerciseId: await makeExercise('Overhead Press'));

    final loaded = (await templates.watchTemplate(t.id).first)!;

    expect(loaded.exercises.map((e) => e.name),
        ['Bench Press', 'Overhead Press']);
    expect(loaded.exercises.first.config.targetSets, 3);
    expect(loaded.exercises.first.config.restSeconds, 90);
    expect(loaded.totalSets, 6);
  });

  test('reorderExercises moves an exercise and renumbers sortOrder densely',
      () async {
    final t = await templates.createTemplate(name: 'Pull');
    for (final n in ['A', 'B', 'C']) {
      await templates.addExercise(
          templateId: t.id, exerciseId: await makeExercise(n));
    }

    await templates.reorderExercises(t.id, 2, 0);

    final loaded = (await templates.watchTemplate(t.id).first)!;
    expect(loaded.exercises.map((e) => e.name), ['C', 'A', 'B']);
    expect(loaded.exercises.map((e) => e.config.sortOrder), [0, 1, 2]);
  });

  test('duplicateTemplate copies exercises but produces new ids', () async {
    final t = await templates.createTemplate(name: 'Legs A');
    await templates.addExercise(
      templateId: t.id,
      exerciseId: await makeExercise('Back Squat'),
      targetSets: 5,
      restSeconds: 180,
    );

    final copy = await templates.duplicateTemplate(t.id);

    expect(copy.id, isNot(t.id));
    expect(copy.name, 'Legs A (copy)');

    final loaded = (await templates.watchTemplate(copy.id).first)!;
    expect(loaded.exercises.single.config.targetSets, 5);
    expect(loaded.exercises.single.config.restSeconds, 180);
    expect(
        loaded.exercises.single.config.id,
        isNot((await templates.watchTemplate(t.id).first)!
            .exercises
            .single
            .config
            .id));
  });

  test('removing an exercise renumbers the remaining sortOrder', () async {
    final t = await templates.createTemplate(name: 'Ab Circuit');
    final ids = <String>[];
    for (final n in ['A', 'B', 'C']) {
      final te = await templates.addExercise(
          templateId: t.id, exerciseId: await makeExercise(n));
      ids.add(te.id);
    }

    await templates.removeTemplateExercise(ids[1]);

    final loaded = (await templates.watchTemplate(t.id).first)!;
    expect(loaded.exercises.map((e) => e.name), ['A', 'C']);
    expect(loaded.exercises.map((e) => e.config.sortOrder), [0, 1]);
  });

  test('deleting a template cascades to its template exercises', () async {
    final t = await templates.createTemplate(name: 'Temp');
    await templates.addExercise(
        templateId: t.id, exerciseId: await makeExercise('X'));

    await templates.deleteTemplate(t.id);

    expect(await db.select(db.templateExercises).get(), isEmpty);
  });

  test('watchTemplate still returns an exercise that has been archived',
      () async {
    final t = await templates.createTemplate(name: 'Arm Day');
    final exerciseId = await makeExercise('Curl');
    await templates.addExercise(templateId: t.id, exerciseId: exerciseId);

    await exercises.archive(exerciseId);

    final loaded = (await templates.watchTemplate(t.id).first)!;
    expect(loaded.exercises.single.name, 'Curl');
    expect(loaded.exercises.single.isArchived, isTrue);
  });
}
