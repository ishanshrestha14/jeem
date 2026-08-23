import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/dashboard/ui/home_screen.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';
import 'pump_helpers.dart';

/// The Home dashboard renders only real data: a quick-start list ordered by
/// `TemplateSummary.lastPerformedAt` (most recent first, nulls last), and a
/// last-workout section. No hardcoded streak/metric ever appears here, and
/// since T-001 no resume card either — a live session belongs to the shell's
/// `WorkoutInProgressBar`, on every tab rather than just this one.
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

  testWidgets(
      'Home does not surface a live session: that moved to the shell bar',
      (tester) async {
    // T-001 moved the resume affordance out of Home and into
    // `WorkoutInProgressBar`, which the shell shows above the nav on every
    // tab. Home must not keep a second, Home-only copy of it — covered by
    // workout_in_progress_bar_test.dart instead.
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
    await pumpUntilData(tester, until: find.text('Quick start'));

    expect(find.text('IN PROGRESS'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Resume'), findsNothing);
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
