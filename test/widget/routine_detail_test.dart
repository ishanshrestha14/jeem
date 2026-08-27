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

  // ---------------------------------------------------------------------
  // T-025 — the stats tile's other two slots, deferred since T-011.
  // ---------------------------------------------------------------------

  /// A completed session for [templateId] that really took [ran], inserted
  /// directly rather than driven through `startFromTemplate`/`finishSession`:
  /// those run against the wall clock, so a session started and finished in
  /// the same test takes zero time and is dropped as corrupt.
  Future<void> aLoggedSession({
    required String templateId,
    required Duration ran,
    int daysAgo = 0,
  }) async {
    final startedAt = DateTime.now().subtract(Duration(days: daysAgo, hours: 2));
    await db.into(db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            id: 'logged-$daysAgo-${ran.inSeconds}',
            name: 'Pull B',
            status: SessionStatus.completed,
            startedAt: startedAt,
            createdAt: startedAt,
            updatedAt: startedAt,
            templateId: Value(templateId),
            endedAt: Value(startedAt.add(ran)),
          ),
        );
  }

  testWidgets('a routine never performed estimates its duration from the plan',
      (tester) async {
    // 3 sets x 45s work, plus rest after the first two only.
    final id = await seedRoutine(sets: 3);

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Pull B'));

    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('~5 min'), findsOneWidget);
    expect(find.text('estimated'), findsOneWidget,
        reason: 'the guess is labelled as one');
    expect(find.text('your average'), findsNothing);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('a performed routine averages what it actually took',
      (tester) async {
    final id = await seedRoutine(sets: 3);
    await aLoggedSession(
        templateId: id, ran: const Duration(minutes: 50), daysAgo: 1);
    await aLoggedSession(
        templateId: id, ran: const Duration(minutes: 60), daysAgo: 2);

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('your average'));

    expect(find.text('~55 min'), findsOneWidget);
    expect(find.text('estimated'), findsNothing,
        reason: 'one real run beats the formula');
    await disposeAndDrainTimers(tester);
  });

  testWidgets('the body parts a routine works read as one line', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Push A');
    final bench = await exercises.create(
        name: 'Bench Press',
        loggingType: LoggingType.strengthWeightRepsRir,
        bodyParts: [BodyPart.chest, BodyPart.arms]);
    final press = await exercises.create(
        name: 'Overhead Press',
        loggingType: LoggingType.strengthWeightRepsRir,
        bodyParts: [BodyPart.shoulders, BodyPart.chest]);
    await templates.addExercise(templateId: t.id, exerciseId: bench.id);
    await templates.addExercise(templateId: t.id, exerciseId: press.id);

    await tester.pumpWidget(harness(t.id));
    await pumpUntilData(tester, until: find.text('Chest · Shoulders · Arms'));

    // Deduped, and in enum order rather than alphabetical, so the same
    // routine always reads the same way.
    expect(find.text('Chest · Shoulders · Arms'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('untagged exercises leave no empty body-part line',
      (tester) async {
    final id = await seedRoutine();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Pull B'));

    expect(find.text('Muscles worked'), findsNothing);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('an empty routine keeps the tile as a single stat',
      (tester) async {
    final templates = TemplateRepository(db);
    final t = await templates.createTemplate(name: 'Empty');

    await tester.pumpWidget(harness(t.id));
    await pumpUntilData(tester, until: find.text('Empty'));

    // Nothing to time and nothing to work: `~0 min` and a bare label are both
    // worse than today's single centred column.
    expect(find.text('Total sets'), findsOneWidget);
    expect(find.text('Duration'), findsNothing);
    expect(find.text('Muscles worked'), findsNothing);
    await disposeAndDrainTimers(tester);
  });
}
