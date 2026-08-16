import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/app/router.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/dashboard/ui/home_screen.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';
import 'active_session_test.dart' show pumpUntilSessionData;
import 'pump_helpers.dart';

/// The Home dashboard renders only real data: a resume card when (and only
/// when) `activeSessionProvider` yields a session, and a quick-start list
/// ordered by `TemplateSummary.lastPerformedAt` (most recent first, nulls
/// last). No hardcoded streak/metric ever appears here.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = testDatabase());
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget harness() {
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.dark(), home: const HomeScreen()),
    );
  }

  testWidgets('shows the empty state when there are no templates at all',
      (tester) async {
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('No workouts yet'));
    expect(find.text('Go to Workout'), findsOneWidget);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('does not render a resume card when no session is active',
      (tester) async {
    await TemplateRepository(db).createTemplate(name: 'Push');

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Push'));

    expect(find.text('IN PROGRESS'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Resume'), findsNothing);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('renders a resume card with name and Resume action when a session is active',
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
    await pumpUntilData(tester, until: find.text('IN PROGRESS'));

    expect(find.text('Legs A'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets(
      'a running session stays reachable via the resume card even when the '
      'template list is empty', (tester) async {
    // Regression test: TemplateRepository.deleteTemplate does not block on
    // a running session, and `/session` is only reachable from this resume
    // card, `startWorkout`, or the template editor. Deleting the last
    // template mid-workout must not strand the live session behind the
    // "No workouts yet" empty state with no way back to it.
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 1);
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    await templates.deleteTemplate(t.id);

    // The plain `harness()` above wraps `HomeScreen` directly with no
    // `GoRouter`, which is enough for the other tests in this file, but
    // "tappable" here specifically means the resume card's `context.push`
    // actually navigates — so this test uses the real app router instead,
    // same as `shell_navigation_test.dart`.
    final router = createAppRouter();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await pumpUntilData(tester, until: find.text('IN PROGRESS'));

    // The empty-state copy must not have taken over the screen instead.
    expect(find.text('No workouts yet'), findsNothing);
    expect(find.text('Legs A'), findsWidgets);
    final resumeButton = find.widgetWithText(FilledButton, 'Resume');
    expect(resumeButton, findsOneWidget);

    // Tappable: the resume affordance must actually navigate, not just be
    // present and inert.
    await tester.tap(resumeButton);
    await tester.pump();
    await pumpUntilSessionData(tester);
    expect(find.byType(ActiveSessionScreen), findsOneWidget);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets(
      'quick start lists templates ordered by most recently performed, nulls last',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);

    final never = await templates.createTemplate(name: 'Never Done');
    final e1 = await exercises.create(
        name: 'Ex1', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(templateId: never.id, exerciseId: e1.id);

    final older = await templates.createTemplate(name: 'Older');
    final e2 = await exercises.create(
        name: 'Ex2', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(templateId: older.id, exerciseId: e2.id);
    final olderSession =
        await sessions.startFromTemplate(older.id, weightUnit: 'kg');
    await sessions.finishSession(olderSession.id);

    final recent = await templates.createTemplate(name: 'Recent');
    final e3 = await exercises.create(
        name: 'Ex3', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(templateId: recent.id, exerciseId: e3.id);
    final recentSession =
        await sessions.startFromTemplate(recent.id, weightUnit: 'kg');
    await sessions.finishSession(recentSession.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Recent'));

    // All three appear (only 3 templates exist, so the top-3 cap doesn't
    // exclude any of them) but in recency order: Recent, Older, then the
    // never-performed template last. "Recent" is also the most recent
    // completed session, so it additionally shows up in the "Last workout"
    // line below the quick-start list — `.first` picks the topmost (quick
    // start) occurrence, which is the one whose position this test cares
    // about.
    final recentY = tester.getTopLeft(find.text('Recent').first).dy;
    final olderY = tester.getTopLeft(find.text('Older')).dy;
    final neverY = tester.getTopLeft(find.text('Never Done')).dy;
    expect(recentY, lessThan(olderY));
    expect(olderY, lessThan(neverY));

    await disposeAndDrainTimers(tester, container: container);
  });
}
