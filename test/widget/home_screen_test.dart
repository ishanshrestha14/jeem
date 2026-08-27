import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/dashboard/ui/home_screen.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/test_database.dart';
import 'pump_helpers.dart';

/// S-001, with the social layer stripped: a weekly summary over a short list
/// of recent workouts. Not a routine list — the Workout tab is the launchpad
/// (S-003) and the Library owns routines (S-004).
void main() {
  late AppDatabase db;
  String? sharedExerciseId;

  setUp(() {
    db = testDatabase();
    SharedPreferences.setMockInitialValues({});
    // Each test gets a fresh database, so an id cached from the last one
    // points at nothing.
    sharedExerciseId = null;
  });
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const HomeScreen(),
        ),
      );

  Future<String> aLoggedWorkout({String name = 'Push', double weight = 100}) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: name);
    // One exercise across workouts, so their records actually compete.
    final e = sharedExerciseId == null
        ? await exercises.create(
            name: 'Bench', loggingType: LoggingType.strengthWeightRepsRir)
        : (await exercises.findById(sharedExerciseId!))!;
    sharedExerciseId = e.id;
    await templates.addExercise(
        templateId: t.id, exerciseId: e.id, targetSets: 1);
    final s = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    final set = (await db.select(db.sessionSets).get()).last;
    await sessions.updateSet(set.copyWith(
      weight: Value(weight),
      reps: const Value(5),
      completedAt: Value(DateTime.now()),
    ));
    await sessions.finishSession(s.id);
    return s.id;
  }

  testWidgets('shows the weekly summary with all three metrics',
      (tester) async {
    await aLoggedWorkout();

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Your weekly summary'));

    expect(find.text('Workouts'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
  });

  testWidgets('with no history the summary reads zero, not blank',
      (tester) async {
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Your weekly summary'));

    // A scoreboard showing 0 is meaningful; a blank one is not.
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('with no history it invites the first workout', (tester) async {
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Your weekly summary'));

    expect(find.textContaining('first workout'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
  });

  testWidgets('lists recent workouts once there are some', (tester) async {
    await aLoggedWorkout(name: 'Push');
    await aLoggedWorkout(name: 'Pull');

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Recent workouts'));

    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Pull'), findsOneWidget);
    expect(find.textContaining('first workout'), findsNothing);
  });

  testWidgets('caps the list and links to the full history', (tester) async {
    for (var i = 0; i < 7; i++) {
      await aLoggedWorkout(name: 'W$i');
    }

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Recent workouts'));

    // Home is a recap; History is the archive. Showing everything here would
    // make the two screens the same screen.
    expect(find.text('W0'), findsNothing, reason: 'oldest is past the cap');
    expect(find.text('W6'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
  });

  testWidgets('no longer lists routines to start', (tester) async {
    final templates = TemplateRepository(db);
    await templates.createTemplate(name: 'Legs A');

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Your weekly summary'));

    // Routines live in the Library (S-004); the Workout tab suggests them
    // (S-003). A third list here was the duplication T-011 and T-013 removed.
    expect(find.text('Quick start'), findsNothing);
    expect(find.text('Legs A'), findsNothing);
  });

  testWidgets('Home does not surface a live session: that moved to the shell bar',
      (tester) async {
    // T-001 moved the resume affordance out of Home and into
    // `WorkoutInProgressBar`, which the shell shows above the nav on every
    // tab. Home must not keep a second, Home-only copy of it — covered by
    // workout_in_progress_bar_test.dart instead. Carried over from the
    // retired dashboard_home_test.dart, since it guards a rule the S-001
    // rebuild does not change.
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
    await pumpUntilData(tester, until: find.text('Your weekly summary'));

    expect(find.text('IN PROGRESS'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Resume'), findsNothing);
  });

  testWidgets('a workout holding a standing record shows a badge (S-001)',
      (tester) async {
    await aLoggedWorkout(name: 'Push');

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Recent workouts'));

    expect(find.textContaining('1 record'), findsOneWidget);
  });

  testWidgets('a workout whose record was beaten shows none', (tester) async {
    // The badge means "this still stands" (owner-confirmed), so it goes away
    // when you beat it — the number can fall as you get stronger.
    await aLoggedWorkout(name: 'Old', weight: 60);
    await aLoggedWorkout(name: 'New', weight: 100);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Recent workouts'));

    expect(find.textContaining('record'), findsOneWidget);
  });
}
