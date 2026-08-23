import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/services/backup_service.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/programs/data/program_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';

void main() {
  late AppDatabase dbA;
  late AppDatabase dbB;

  setUp(() {
    dbA = testDatabase();
    dbB = testDatabase();
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  /// Seeds db A with 2 exercises, 1 template with 2 template exercises, and
  /// 1 completed session with a single session exercise carrying 3 sets
  /// (weight/reps/rir values, one of them completed).
  Future<String> seedAndExport() async {
    final now = DateTime.utc(2026, 8, 15, 10, 30, 45, 123, 456);

    await dbA.into(dbA.exercises).insert(ExercisesCompanion.insert(
          id: 'ex-1',
          name: 'Bench Press',
          loggingType: LoggingType.strengthWeightRepsRir,
          createdAt: now,
          updatedAt: now,
        ));
    await dbA.into(dbA.exercises).insert(ExercisesCompanion.insert(
          id: 'ex-2',
          name: 'Squat',
          loggingType: LoggingType.strengthWeightRepsRir,
          createdAt: now,
          updatedAt: now,
        ));

    await dbA.into(dbA.workoutTemplates).insert(WorkoutTemplatesCompanion.insert(
          id: 'tpl-1',
          name: 'Push Day',
          createdAt: now,
          updatedAt: now,
        ));
    await dbA.into(dbA.templateExercises).insert(TemplateExercisesCompanion.insert(
          id: 'te-1',
          templateId: 'tpl-1',
          exerciseId: 'ex-1',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ));
    await dbA.into(dbA.templateExercises).insert(TemplateExercisesCompanion.insert(
          id: 'te-2',
          templateId: 'tpl-1',
          exerciseId: 'ex-2',
          sortOrder: 1,
          createdAt: now,
          updatedAt: now,
        ));

    await dbA.into(dbA.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          id: 'sess-1',
          name: 'Push Day',
          status: SessionStatus.completed,
          startedAt: now,
          endedAt: Value(now.add(const Duration(hours: 1))),
          createdAt: now,
          updatedAt: now,
        ));
    await dbA.into(dbA.sessionExercises).insert(SessionExercisesCompanion.insert(
          id: 'se-1',
          sessionId: 'sess-1',
          exerciseId: const Value('ex-1'),
          name: 'Bench Press',
          loggingType: LoggingType.strengthWeightRepsRir,
          sortOrder: 0,
          restSeconds: 90,
          targetSets: 3,
          createdAt: now,
          updatedAt: now,
        ));

    await dbA.into(dbA.sessionSets).insert(SessionSetsCompanion.insert(
          id: 'set-0',
          sessionExerciseId: 'se-1',
          setIndex: 0,
          weight: const Value(80.0),
          reps: const Value(8),
          rir: const Value(2.0),
          completedAt: Value(now.add(const Duration(minutes: 5))),
          createdAt: now,
          updatedAt: now,
        ));
    await dbA.into(dbA.sessionSets).insert(SessionSetsCompanion.insert(
          id: 'set-1',
          sessionExerciseId: 'se-1',
          setIndex: 1,
          weight: const Value(82.5),
          reps: const Value(7),
          rir: const Value(1.5),
          completedAt: Value(now.add(const Duration(minutes: 8))),
          createdAt: now,
          updatedAt: now,
        ));
    await dbA.into(dbA.sessionSets).insert(SessionSetsCompanion.insert(
          id: 'set-2',
          sessionExerciseId: 'se-1',
          setIndex: 2,
          weight: const Value(85.0),
          reps: const Value(6),
          rir: const Value(1.0),
          completedAt: Value(now.add(const Duration(minutes: 11))),
          createdAt: now,
          updatedAt: now,
        ));

    return BackupService(dbA).exportJson();
  }

  test('export then import into a fresh database reproduces everything',
      () async {
    final json = await seedAndExport();

    await BackupService(dbB).importJson(json);

    expect(await dbB.select(dbB.exercises).get(), hasLength(2));
    expect(await dbB.select(dbB.workoutTemplates).get(), hasLength(1));
    expect(await dbB.select(dbB.templateExercises).get(), hasLength(2));
    expect(await dbB.select(dbB.workoutSessions).get(), hasLength(1));
    expect(await dbB.select(dbB.sessionExercises).get(), hasLength(1));

    final sets = await dbB.select(dbB.sessionSets).get();
    expect(sets, hasLength(3));
    final first = sets.firstWhere((s) => s.setIndex == 0);
    expect(first.weight, 80.0);
    expect(first.reps, 8);
    expect(first.rir, 2.0);
    expect(first.completedAt, isNotNull);
  });

  test('import replaces existing data rather than merging', () async {
    final json = await seedAndExport();
    await ExerciseRepository(dbB).create(
        name: 'Stale', loggingType: LoggingType.strengthWeightRepsRir);

    await BackupService(dbB).importJson(json);

    final names = (await dbB.select(dbB.exercises).get()).map((e) => e.name);
    expect(names, isNot(contains('Stale')));
    expect(names, containsAll(['Bench Press', 'Squat']));
  });

  test('a payload with the wrong version is rejected before anything is deleted',
      () async {
    await ExerciseRepository(dbB)
        .create(name: 'Keep me', loggingType: LoggingType.durationOnly);

    await expectLater(
      () => BackupService(dbB).importJson('{"version": 99, "exercises": []}'),
      throwsA(isA<FormatException>()),
    );
    expect(await dbB.select(dbB.exercises).get(), hasLength(1));
  });

  test(
      'a payload that violates a foreign key mid-insert rolls back the '
      'whole transaction rather than leaving a half-deleted database',
      () async {
    await ExerciseRepository(dbB)
        .create(name: 'Keep me', loggingType: LoggingType.durationOnly);

    final now = DateTime.utc(2026, 8, 15, 10).toIso8601String();
    // Hand-written payload: `templateExercises` references an
    // `exerciseId` ('missing-ex') that doesn't exist in its own
    // `exercises` list. The delete phase (all six tables) runs first, then
    // the insert phase hits this dangling FK on `templateExercises` and
    // Drift surfaces it as an exception (PRAGMA foreign_keys = ON in
    // AppDatabase) — proving the whole transaction rolls back.
    final badJson = jsonEncode({
      'version': BackupService.backupVersion,
      'exportedAt': now,
      'exercises': [
        {
          'id': 'ex-1',
          'name': 'Bench Press',
          'category': null,
          'loggingType': 'strengthWeightRepsRir',
          'description': null,
          'notes': null,
          'imagePath': null,
          'isArchived': false,
          'createdAt': now,
          'updatedAt': now,
          'deletedAt': null,
        },
      ],
      'workoutTemplates': [
        {
          'id': 'tpl-1',
          'name': 'Push Day',
          'notes': null,
          'defaultRestSeconds': 90,
          'autoFocusNextSet': true,
          'autoFocusNextExercise': true,
          'createdAt': now,
          'updatedAt': now,
          'deletedAt': null,
        },
      ],
      'templateExercises': [
        {
          'id': 'te-1',
          'templateId': 'tpl-1',
          'exerciseId': 'missing-ex',
          'sortOrder': 0,
          'targetSets': 3,
          'restSeconds': 90,
          'defaultRir': null,
          'defaultDurationSeconds': null,
          'notes': null,
          'createdAt': now,
          'updatedAt': now,
          'deletedAt': null,
        },
      ],
      'workoutSessions': [],
      'sessionExercises': [],
      'sessionSets': [],
    });

    await expectLater(
      () => BackupService(dbB).importJson(badJson),
      throwsA(isA<Exception>()),
    );

    final names = (await dbB.select(dbB.exercises).get()).map((e) => e.name);
    expect(names, contains('Keep me'));
  });

  test('ids and timestamps round-trip exactly', () async {
    final json = await seedAndExport();

    await BackupService(dbB).importJson(json);

    final exercise = await (dbB.select(dbB.exercises)
          ..where((t) => t.id.equals('ex-1')))
        .getSingle();
    expect(exercise.id, 'ex-1');
    expect(exercise.createdAt, DateTime.utc(2026, 8, 15, 10, 30, 45, 123, 456));

    final session = await (dbB.select(dbB.workoutSessions)
          ..where((t) => t.id.equals('sess-1')))
        .getSingle();
    expect(session.id, 'sess-1');
    expect(session.endedAt,
        DateTime.utc(2026, 8, 15, 10, 30, 45, 123, 456).add(const Duration(hours: 1)));
  });

  test('exportToFile creates the target directory if it does not exist',
      () async {
    // Regression: on macOS `getTemporaryDirectory()` returns
    // Library/Caches/<bundle-id>, a path the OS does not create for a freshly
    // installed sandboxed app, so the export died with PathNotFoundException
    // (errno 2) before writing a single byte.
    final root = await Directory.systemTemp.createTemp('gymflow-export-test');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final missing = Directory('${root.path}/not/created/yet');
    expect(await missing.exists(), isFalse);

    final service = BackupService(dbA);
    final file = await service.exportToFile(directory: missing);

    expect(await file.exists(), isTrue);
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(decoded['version'], isNotNull);
  });

  test('round-trips programs and their routines, in order', () async {
    final templates = TemplateRepository(dbA);
    final programs = ProgramRepository(dbA);
    final program = await programs.create(name: 'Upper / Lower');
    final upper = await templates.createTemplate(name: 'Upper A');
    final lower = await templates.createTemplate(name: 'Lower A');
    await programs.addRoutine(programId: program.id, templateId: upper.id);
    await programs.addRoutine(programId: program.id, templateId: lower.id);
    await programs.reorder(program.id, 1, 0);

    await BackupService(dbB).importJson(await BackupService(dbA).exportJson());

    final restored = await ProgramRepository(dbB).watchProgram(program.id).first;
    expect(restored, isNotNull);
    expect([for (final r in restored!.routines) r.template.name],
        ['Lower A', 'Upper A'], reason: 'order must survive the round trip');
  });

  test('a backup written before programs existed still imports', () async {
    final json = jsonDecode(await BackupService(dbA).exportJson())
        as Map<String, dynamic>;
    // Exactly the shape of a pre-v5 file: the keys simply are not there.
    json.remove('workoutPrograms');
    json.remove('programRoutines');

    await BackupService(dbB).importJson(jsonEncode(json));

    expect(await ProgramRepository(dbB).watchSummaries().first, isEmpty);
  });
}
