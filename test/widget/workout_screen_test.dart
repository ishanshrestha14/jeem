import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:gymflow/features/templates/ui/workout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/test_database.dart';
import 'pump_helpers.dart';

/// S-003: the day launchpad, answering *what am I doing today?* — not a
/// routine list. Routines live in the Library (S-004) since T-011; this tab
/// is about the day.
void main() {
  late AppDatabase db;

  setUp(() {
    db = testDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const WorkoutScreen(),
        ),
      );

  Future<String> seedRoutine(String name) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: name);
    final e = await exercises.create(
        name: '$name move', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: e.id, targetSets: 1);
    return t.id;
  }

  testWidgets('with nothing logged it says so and offers a start',
      (tester) async {
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('No workouts today'));

    expect(find.text('No workouts today'), findsOneWidget);
    expect(find.text('Start new workout'), findsWidgets);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('suggests routines, never-performed first', (tester) async {
    final doneId = await seedRoutine('Done');
    await seedRoutine('Fresh');
    final sessions = SessionRepository(db);
    // Never await a Drift stream's `.first` inside a widget-test body: it
    // needs real async turns the fake clock does not provide, and the run
    // wedges rather than failing. `seedRoutine` hands back the id directly.
    final done = await sessions.startFromTemplate(doneId, weightUnit: 'kg');
    await sessions.finishSession(done.id);
    // Backdated: a session finished *today* would count as today's workout
    // and hide the suggestions entirely, which is the behaviour the next test
    // covers. Here 'Done' just needs a past performance to rank against.
    await (db.update(db.workoutSessions)
          ..where((t) => t.id.equals(done.id)))
        .write(WorkoutSessionsCompanion(
      endedAt: Value(DateTime.now().subtract(const Duration(days: 3))),
    ));

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Fresh'));

    final yFresh = tester.getTopLeft(find.text('Fresh')).dy;
    final yDone = tester.getTopLeft(find.text('Done')).dy;
    expect(yFresh, lessThan(yDone),
        reason: 'a routine you have never done is the most neglected');

    await disposeAndDrainTimers(tester);
  });

  testWidgets('a workout logged today is listed, and suggestions go away',
      (tester) async {
    final id = await seedRoutine('Pull B');
    final sessions = SessionRepository(db);
    final s = await sessions.startFromTemplate(id, weightUnit: 'kg');
    await sessions.finishSession(s.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Workouts'));

    expect(find.text('Workouts'), findsOneWidget);
    expect(find.text('No workouts today'), findsNothing);
    // The reference drops the "do this next" prompt once you have trained —
    // fewer decisions after the work is done.
    expect(find.text('Suggested routines'), findsNothing);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('the routine list and its edit menu are gone', (tester) async {
    await seedRoutine('Pull B');

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('No workouts today'));

    // Routines are the Library's job now (T-011). This tab may *suggest* one,
    // but it does not manage them.
    expect(find.text('Duplicate'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('a logged workout can be deleted from the day list',
      (tester) async {
    final id = await seedRoutine('Pull B');
    final sessions = SessionRepository(db);
    final s = await sessions.startFromTemplate(id, weightUnit: 'kg');
    await sessions.finishSession(s.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Workouts'));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Destructive and irreversible from the UI, so it asks first.
    expect(find.textContaining('Delete this workout'), findsOneWidget);
    await tester.tap(find.text('Delete workout'));
    await pumpUntilData(tester, until: find.text('No workouts today'));

    expect(find.text('No workouts today'), findsOneWidget);
  });

  testWidgets('backing out of the confirmation keeps the workout',
      (tester) async {
    final id = await seedRoutine('Pull B');
    final sessions = SessionRepository(db);
    final s = await sessions.startFromTemplate(id, weightUnit: 'kg');
    await sessions.finishSession(s.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Workouts'));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Workouts'), findsOneWidget);
    expect(find.text('No workouts today'), findsNothing);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('many workouts in one day scroll rather than overflow',
      (tester) async {
    // A short surface, so anything that lays out without scrolling overflows
    // here even if it fits a tall window.
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final id = await seedRoutine('Pull B');
    final sessions = SessionRepository(db);
    for (var i = 0; i < 12; i++) {
      final s = await sessions.startFromTemplate(id, weightUnit: 'kg');
      await sessions.finishSession(s.id);
    }

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Workouts'));

    expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');

    // And it genuinely scrolls: the start row sits below twelve cards, out of
    // view until dragged to.
    expect(find.text('Log another workout'), findsNothing);
    await tester.drag(find.text('Workouts'), const Offset(0, -1200));
    await tester.pump();
    expect(find.text('Log another workout'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });
}
