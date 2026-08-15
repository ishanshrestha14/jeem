import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/sessions/ui/widgets/duration_set_row.dart';
import 'package:gymflow/features/sessions/ui/widgets/strength_set_row.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';
import 'pump_helpers.dart';

/// Both `ActiveSessionController.build()` and every one of its mutators
/// (`completeSet`, `updateSetValues`, ...) reload the post-write session via
/// `SessionRepository.watchSession(id).first` / `.watchActiveSession().first`.
/// `Stream.first` awaits its subscription's `cancel()` before completing, and
/// `SessionRepository`'s hand-rolled `_watchAggregate` cancellation needs a
/// genuine event-loop turn to settle — which plain `tester.pump()` calls
/// never provide (confirmed by isolating the hang to exactly this `.first`
/// call: swapping it for a manual, non-awaited-cancel subscription resolved
/// immediately under the same pump loop that otherwise stalled indefinitely,
/// even across 300 pumps). `pumpUntilData` alone therefore hangs on this
/// screen. `tester.runAsync` is flutter_test's sanctioned escape hatch for
/// exactly this — it briefly runs real (non-simulated) async code so pending
/// Future chains like this one can actually resolve — so every wait on this
/// screen goes through it instead. No production code changes were needed
/// or made; this is purely a test-environment characteristic of the
/// `.first`-based reload pattern.
Future<void> pumpUntilSessionData(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ActiveSessionScreen(),
        ),
      );

  testWidgets('an exercise with 3 target sets renders 3 rows', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 3);
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    expect(find.byType(StrengthSetRow), findsNWidgets(3));
    final rows = find.byType(StrengthSetRow);
    expect(
      find.descendant(of: rows.at(0), matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rows.at(2), matching: find.text('3')),
      findsOneWidget,
    );

    await disposeAndDrainTimers(tester);
  });

  testWidgets('a duration exercise renders duration rows, not weight/reps',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Core');
    final plank = await exercises.create(
        name: 'Plank', loggingType: LoggingType.durationOnly);
    await templates.addExercise(
        templateId: t.id, exerciseId: plank.id, targetSets: 2);
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    expect(find.byType(DurationSetRow), findsNWidgets(2));
    expect(find.byType(StrengthSetRow), findsNothing);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('the progress header counts sets and exercises', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Full Body');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 3);
    await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 3);
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    expect(find.text('0 / 6 sets'), findsOneWidget);
    expect(find.text('0 / 2 exercises'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('tapping the complete button marks the set done', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    // 2 target sets: completing the first must not complete the whole
    // exercise (which would collapse the card into the "Completed" section
    // and hide the row this test is asserting on).
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 2);
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await pumpUntilSessionData(tester);

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    final rows = await (db.select(db.sessionSets)
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .get();
    expect(rows.first.completedAt, isNotNull);
    expect(rows.last.completedAt, isNull);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('typing a weight persists it to the database', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 1);
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    // Weight is the first (leftmost) of the two empty TextFields in a
    // strength row — weight, then reps.
    final weightField = find.widgetWithText(TextField, '').first;
    await tester.enterText(weightField, '80');
    await pumpUntilSessionData(tester);

    final row = await (db.select(db.sessionSets)).getSingle();
    expect(row.weight, 80);

    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'a set with empty weight/reps/rir can still be completed (PRD §18.7)',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 1);
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    // Nothing typed into weight/reps/RIR — complete must still be enabled.
    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await pumpUntilSessionData(tester);

    final row = await (db.select(db.sessionSets)).getSingle();
    expect(row.completedAt, isNotNull);
    expect(row.weight, isNull);
    expect(row.reps, isNull);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('a completed set stays editable, not disabled (PRD §17)',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    // 2 target sets, same reasoning as the "tapping the complete button"
    // test: completing the only set would complete the exercise and
    // collapse the card into the "Completed" section, hiding its fields.
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 2);
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await pumpUntilSessionData(tester);

    final weightField = find.widgetWithText(TextField, '').first;
    final field = tester.widget<TextField>(weightField);
    expect(field.enabled, isNot(false));

    await tester.enterText(weightField, '80');
    await pumpUntilSessionData(tester);

    final rows = await (db.select(db.sessionSets)
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .get();
    expect(rows.first.weight, 80);

    await disposeAndDrainTimers(tester);
  });
}
