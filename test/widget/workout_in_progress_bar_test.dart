import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/app/router.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/sessions/ui/widgets/workout_in_progress_bar.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';
import 'active_session_test.dart' show pumpUntilSessionData;
import 'pump_helpers.dart';

/// T-001 / CMP-001: while a session is live, a "Workout in Progress" strip
/// sits above the bottom nav on **every** tab, so the workout is never more
/// than one tap away. It replaced Home's resume card, which was only visible
/// on one of four tabs.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = testDatabase());
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// The real router, because the bar lives in the shell and "Resume" has to
  /// actually navigate — a bare widget harness could not show either.
  Widget harness() {
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: createAppRouter(),
      ),
    );
  }

  Future<void> startSession({String name = 'Legs A'}) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: name);
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 1);
    await SessionRepository(db).startFromTemplate(t.id, weightUnit: 'kg');
  }

  testWidgets('is absent when no session is active', (tester) async {
    await TemplateRepository(db).createTemplate(name: 'Push');
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Quick start'));

    expect(find.text('Workout in Progress'), findsNothing);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('shows the session name plus Resume and Discard when active',
      (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Workout in Progress'));

    expect(find.text('Legs A'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Resume'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Discard'), findsOneWidget);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('stays visible after switching tabs', (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Workout in Progress'));

    // The whole point of moving this out of Home: it must survive navigation
    // to a tab that knows nothing about sessions.
    await tester.tap(find.text('HISTORY'));
    await tester.pumpAndSettle();

    expect(find.text('Workout in Progress'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Resume'), findsOneWidget);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('Resume opens the full-screen session', (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Workout in Progress'));

    await tester.tap(find.widgetWithText(TextButton, 'Resume'));
    await tester.pump();
    await pumpUntilSessionData(tester);

    expect(find.byType(ActiveSessionScreen), findsOneWidget);
    // `/session` sits outside the shell, so the bar is not built there. Tested
    // by ancestry, not by `find.text`: Navigator keeps the obscured shell
    // mounted underneath, so the bar's text is still findable in the tree even
    // though nothing paints it.
    expect(
      find.ancestor(
        of: find.byType(ActiveSessionScreen),
        matching: find.byType(WorkoutInProgressBar),
      ),
      findsNothing,
    );
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('Discard confirms first, and "Keep working out" changes nothing',
      (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Workout in Progress'));

    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Discard workout?'), findsOneWidget);
    // Not "Cancel": next to "Discard workout" that reads as cancelling the
    // workout rather than the dialog.
    expect(find.text('Keep working out'), findsOneWidget);

    await tester.tap(find.text('Keep working out'));
    await tester.pumpAndSettle();

    expect(find.text('Workout in Progress'), findsOneWidget);
    final row = await (db.select(db.workoutSessions)).getSingle();
    expect(row.status, SessionStatus.active);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('confirming Discard cancels the session and clears the bar',
      (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Workout in Progress'));

    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard workout'));
    // `cancelSession` is not awaited by the tap, and it hits the database, so
    // fake-time pumps alone will not let it finish: `runAsync` gives the real
    // event loop a turn before the stream can emit the cleared state.
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await pumpUntilGone(tester, find.text('Workout in Progress'));

    final row = await (db.select(db.workoutSessions)).getSingle();
    expect(row.status, SessionStatus.cancelled, reason: 'DB state first');
    expect(find.text('Workout in Progress'), findsNothing);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('keeps a session reachable when its template has been deleted',
      (tester) async {
    // Regression, inherited from the old Home resume-card test:
    // `deleteTemplate` does not block on a running session, so deleting the
    // last template mid-workout used to strand the live session behind Home's
    // "No workouts yet" empty state with no way back. The shell bar now
    // carries that guarantee on every tab.
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 1);
    await SessionRepository(db).startFromTemplate(t.id, weightUnit: 'kg');
    await templates.deleteTemplate(t.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Workout in Progress'));

    // The empty state is allowed to be on screen — what matters is that it no
    // longer traps the user.
    await tester.tap(find.widgetWithText(TextButton, 'Resume'));
    await tester.pump();
    await pumpUntilSessionData(tester);
    expect(find.byType(ActiveSessionScreen), findsOneWidget);
    await disposeAndDrainTimers(tester, container: container);
  });
}
