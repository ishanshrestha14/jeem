import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymflow/app/app_shell.dart';
import 'package:gymflow/app/router.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';
import 'active_session_test.dart' show pumpUntilSessionData;
import 'pump_helpers.dart';

/// Covers the bottom-nav shell: the four destinations render and switch the
/// visible screen (`StatefulShellRoute.indexedStack` keeps each tab's own
/// navigation/scroll state), and — the guard this whole change exists for —
/// the pushed, full-screen active session route does NOT show the shell's
/// nav bar. That absence was deletion-verified by temporarily nesting
/// `/session` inside the shell in `lib/app/router.dart`, confirming the
/// second test below failed, then reverting (see nav-report.md).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    db = testDatabase();
    // A fresh router per test — `appRouter` is a shared top-level singleton
    // and would otherwise leak navigation state (current tab, pushed
    // routes) across tests.
    router = createAppRouter();
  });
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
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    );
  }

  testWidgets('the shell renders 4 destinations and switches tabs on tap',
      (tester) async {
    await tester.pumpWidget(harness());
    await pumpUntilData(tester,
        until: find.text('Create your first workout'));

    expect(find.text('WORKOUTS'), findsOneWidget);
    expect(find.text('EXERCISES'), findsOneWidget);
    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);

    await tester.tap(find.text('EXERCISES'));
    await pumpUntilData(tester, until: find.text('Create an exercise'));
    expect(find.widgetWithText(AppBar, 'Exercises'), findsOneWidget);

    await tester.tap(find.text('HISTORY'));
    await pumpUntilData(tester,
        until: find.text('No completed sessions yet'));
    expect(find.widgetWithText(AppBar, 'History'), findsOneWidget);

    await tester.tap(find.text('SETTINGS'));
    await tester.pump();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.text('GymFlow'), findsOneWidget);

    // Switching back to Workouts preserves its earlier-loaded state rather
    // than re-showing a loading spinner.
    await tester.tap(find.text('WORKOUTS'));
    await tester.pump();
    expect(find.text('Create your first workout'), findsOneWidget);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets(
      'the active session screen (a pushed full-screen route) does not show the bottom nav',
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
    // Home shows a resume banner for the session already running in the DB.
    await pumpUntilData(tester, until: find.text('Resume "Legs A"'));

    // Sanity check: Workouts really is rendered inside the shell (so the
    // negative assertion below is checking something meaningful, not a
    // vacuously-true "AppShell never appears anywhere" fact).
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('WORKOUTS'), findsOneWidget);

    await tester.tap(find.text('Resume "Legs A"'));
    await pumpUntilSessionData(tester);

    // The pushed `/session` route must NOT be nested inside the shell — it
    // is a full-screen route on the root Navigator, not a shell branch.
    // (Flutter's Navigator keeps the obscured Workouts route's widgets
    // mounted-but-unpainted underneath the new route, so a plain
    // `find.text('WORKOUTS')` would still find it there; the ancestor
    // check below is what actually proves ActiveSessionScreen isn't a
    // descendant of AppShell / its nav bar.)
    expect(
      find.ancestor(
        of: find.byType(ActiveSessionScreen),
        matching: find.byType(AppShell),
      ),
      findsNothing,
    );
    // And confirm the nav labels aren't painted/reachable from the current
    // (session) screen either.
    expect(find.text('WORKOUTS').hitTestable(), findsNothing);
    expect(find.text('EXERCISES').hitTestable(), findsNothing);
    expect(find.text('HISTORY').hitTestable(), findsNothing);
    expect(find.text('SETTINGS').hitTestable(), findsNothing);

    await disposeAndDrainTimers(tester, container: container);
  });
}
