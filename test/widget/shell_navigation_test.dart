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

/// Covers the bottom-nav shell under the Home / Workout / History / Profile
/// IA: the four destinations render (in that order) and switch the visible
/// screen (`StatefulShellRoute.indexedStack` keeps each tab's own
/// navigation/scroll state), the Workout tab's `EXERCISES` header action
/// pushes the exercise library, and — the guard this whole change exists
/// for — the pushed, full-screen active session route does NOT show the
/// shell's nav bar. That absence was deletion-verified by temporarily
/// nesting `/session` inside the shell in `lib/app/router.dart`, confirming
/// the last test below failed, then reverting (see nav-report.md and
/// ia-report.md).
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

  testWidgets('the shell renders 4 destinations, in order, and switches tabs on tap',
      (tester) async {
    // Task 21's Profile/Settings screen now has enough real content
    // (defaults, feedback switches, notification permission, data
    // export/import, About) that its "GymFlow" About text sits below the
    // fold on the default test surface. A taller surface avoids scrolling
    // the ListView just to assert it's there — same `useTallSurface`
    // pattern as `test/widget/exercise_editor_image_test.dart`.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    // The app boots on Home (`/` -> `/home`); with no templates yet it shows
    // the "point at Workout" empty state.
    await pumpUntilData(tester, until: find.text('Go to Workout'));

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('WORKOUT'), findsOneWidget);
    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);

    // Order matters: Home, Workout, History, Profile left-to-right — assert
    // via each label's on-screen x position rather than tree order (which
    // isn't guaranteed to match paint order for arbitrary widgets).
    final xHome = tester.getTopLeft(find.text('HOME')).dx;
    final xWorkout = tester.getTopLeft(find.text('WORKOUT')).dx;
    final xHistory = tester.getTopLeft(find.text('HISTORY')).dx;
    final xProfile = tester.getTopLeft(find.text('PROFILE')).dx;
    expect(xHome, lessThan(xWorkout));
    expect(xWorkout, lessThan(xHistory));
    expect(xHistory, lessThan(xProfile));

    await tester.tap(find.text('WORKOUT'));
    await pumpUntilData(tester, until: find.text('Create your first workout'));
    expect(find.widgetWithText(AppBar, 'Workout'), findsOneWidget);

    await tester.tap(find.text('HISTORY'));
    await pumpUntilData(tester,
        until: find.text('No completed sessions yet'));
    expect(find.widgetWithText(AppBar, 'History'), findsOneWidget);

    await tester.tap(find.text('PROFILE'));
    await tester.pump();
    expect(find.widgetWithText(AppBar, 'Profile'), findsOneWidget);
    expect(find.text('GymFlow'), findsOneWidget);

    // Switching back to Home preserves its earlier-loaded state rather
    // than re-showing a loading spinner.
    await tester.tap(find.text('HOME'));
    await tester.pump();
    expect(find.text('Go to Workout'), findsOneWidget);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets("the Workout tab's EXERCISES action opens the library",
      (tester) async {
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Go to Workout'));

    await tester.tap(find.text('WORKOUT'));
    await pumpUntilData(tester, until: find.text('Create your first workout'));

    await tester.tap(find.text('EXERCISES'));
    await pumpUntilData(tester, until: find.text('Create an exercise'));
    expect(find.widgetWithText(AppBar, 'Exercises'), findsOneWidget);

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
    // Home shows a resume card for the session already running in the DB.
    await pumpUntilData(tester, until: find.text('Legs A'));

    // Sanity check: Home really is rendered inside the shell (so the
    // negative assertion below is checking something meaningful, not a
    // vacuously-true "AppShell never appears anywhere" fact).
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await pumpUntilSessionData(tester);

    // The pushed `/session` route must NOT be nested inside the shell — it
    // is a full-screen route on the root Navigator, not a shell branch.
    // (Flutter's Navigator keeps the obscured Home route's widgets
    // mounted-but-unpainted underneath the new route, so a plain
    // `find.text('HOME')` would still find it there; the ancestor
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
    expect(find.text('HOME').hitTestable(), findsNothing);
    expect(find.text('WORKOUT').hitTestable(), findsNothing);
    expect(find.text('HISTORY').hitTestable(), findsNothing);
    expect(find.text('PROFILE').hitTestable(), findsNothing);

    await disposeAndDrainTimers(tester, container: container);
  });
}
