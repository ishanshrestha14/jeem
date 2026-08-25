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
}
