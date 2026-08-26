import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:gymflow/features/templates/ui/routine_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/test_database.dart';
import 'pump_helpers.dart';

/// S-030: the read-only view between finding a routine and doing it. Starting
/// is the primary action; editing is demoted to the overflow menu, because you
/// start a routine many times for every time you edit it.
void main() {
  late AppDatabase db;

  setUp(() {
    db = testDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => db.close());

  /// A plain [ProviderScope], not `UncontrolledProviderScope` with a
  /// container disposed in `tearDown`. This screen is backed by the
  /// `templateProvider` *family*, whose drift subscription schedules a
  /// cleanup timer when it is cancelled; disposing the container after the
  /// last pump leaves that timer pending and wedges the test runner. Letting
  /// the scope own the container means `disposeAndDrainTimers`'s own
  /// `pumpWidget` disposes it while frames can still be pumped — the same
  /// reason `template_editor_test` (the other `templateProvider` test) is
  /// written this way.
  Widget harness(String templateId) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: RoutineDetailScreen(templateId: templateId),
        ),
      );

  /// A routine named [name] holding one prescribed exercise.
  Future<String> seedRoutine({
    String name = 'Pull B',
    String exerciseName = 'Barbell Deadlift',
    double weight = 60,
    int reps = 6,
    int sets = 3,
  }) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: name);
    final e = await exercises.create(
        name: exerciseName, loggingType: LoggingType.strengthWeightRepsRir);
    final te = await templates.addExercise(
        templateId: t.id, exerciseId: e.id, targetSets: sets);
    for (final s in await templates.setsFor(te.id)) {
      await templates.updateSet(s.id,
          weight: Value(weight), reps: Value(reps));
    }
    return t.id;
  }

  testWidgets('shows the routine name and its exercises with prescriptions',
      (tester) async {
    final id = await seedRoutine();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Pull B'));

    expect(find.text('Barbell Deadlift'), findsOneWidget);
    expect(find.text('3 sets · 6 reps · 60kg'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('counts the total planned sets', (tester) async {
    final id = await seedRoutine(sets: 3);

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Pull B'));

    expect(find.text('Total sets'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('a routine never performed says so', (tester) async {
    final id = await seedRoutine();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Pull B'));

    expect(find.text('Never performed'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('a performed routine shows when it was last done',
      (tester) async {
    final id = await seedRoutine();
    final sessions = SessionRepository(db);
    final s = await sessions.startFromTemplate(id, weightUnit: 'kg');
    await sessions.finishSession(s.id);

    await tester.pumpWidget(harness(id));
    // Waits on the line itself, not the name: `lastPerformedAt` rides the
    // summaries stream, which lands a frame after the routine's own.
    await pumpUntilData(tester, until: find.textContaining('Last performed'));

    expect(find.textContaining('Last performed'), findsOneWidget);
    expect(find.textContaining('Today'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('an empty routine cannot be started', (tester) async {
    final templates = TemplateRepository(db);
    final t = await templates.createTemplate(name: 'Empty');

    await tester.pumpWidget(harness(t.id));
    await pumpUntilData(tester, until: find.text('Empty'));

    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start workout'),
    );
    expect(start.onPressed, isNull,
        reason: 'a routine with no exercises has nothing to start');
    await disposeAndDrainTimers(tester);
  });

  testWidgets('a routine with exercises can be started', (tester) async {
    final id = await seedRoutine();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Pull B'));

    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start workout'),
    );
    expect(start.onPressed, isNotNull);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('editing is in the overflow menu, not the primary action',
      (tester) async {
    final id = await seedRoutine();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Pull B'));

    // Not on the surface — the screen is for starting, not editing.
    expect(find.text('Edit'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('a long routine scrolls, and Start stays reachable',
      (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Long');
    for (var i = 0; i < 15; i++) {
      final e = await exercises.create(
          name: 'Move $i', loggingType: LoggingType.strengthWeightRepsRir);
      await templates.addExercise(
          templateId: t.id, exerciseId: e.id, targetSets: 3);
    }

    await tester.pumpWidget(harness(t.id));
    await pumpUntilData(tester, until: find.text('Long'));

    expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
    // Start is pinned outside the scroll view, so it is reachable however
    // long the routine is.
    expect(find.widgetWithText(FilledButton, 'Start workout'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Move 14'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Move 14'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('the ⋮ menu carries Edit, Duplicate and Delete', (tester) async {
    final id = await seedRoutine();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Pull B'));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // T-013 retired the Workout tab that used to carry Duplicate and Delete,
    // leaving them homeless. This screen is where a single routine is managed.
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('Delete asks first, and backing out keeps the routine',
      (tester) async {
    final id = await seedRoutine();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Pull B'));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Pull B'), findsOneWidget);
    expect(await TemplateRepository(db).setsFor('x'), isEmpty);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('Duplicate copies the routine and its prescription',
      (tester) async {
    final id = await seedRoutine();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Pull B'));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    // Two routines now, and the copy kept the numbers — the point of
    // duplicating a routine (T-002).
    final all = await db.select(db.workoutTemplates).get();
    expect(all, hasLength(2));
    final copy = all.firstWhere((t) => t.id != id);
    final copyExercises = await (db.select(db.templateExercises)
          ..where((t) => t.templateId.equals(copy.id)))
        .get();
    final copySets = await TemplateRepository(db)
        .setsFor(copyExercises.single.id);
    // All three planned sets come across with their numbers intact — carrying
    // the prescription is the point of duplicating a routine (T-002).
    expect(copySets, hasLength(3));
    expect(copySets.every((s) => s.weight == 60 && s.reps == 6), isTrue);

    await disposeAndDrainTimers(tester);
  });
}
