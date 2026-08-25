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

/// Covers the bottom-nav shell under the Home / Explore / Workout / Library /
/// You IA (ADR-005): the five destinations render (in that order) and switch
/// the visible
/// screen (`StatefulShellRoute.indexedStack` keeps each tab's own
/// navigation/scroll state) and — the guard this whole change exists
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

  testWidgets('five destinations fit a narrow screen without overflowing',
      (tester) async {
    // ADR-005 traded four destinations for five. The nav bar is hand-built
    // (the design system bans NavigationBar's pill indicator), so nothing
    // catches a label that no longer fits — it just overflows.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('HOME'));

    expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
    for (final label in ['HOME', 'EXPLORE', 'WORKOUT', 'LIBRARY', 'YOU']) {
      final size = tester.getSize(find.text(label));
      expect(size.width, greaterThan(0), reason: '$label must still render');
    }

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('the shell renders 5 destinations, in order, and switches tabs on tap',
      (tester) async {
    // Five labels have to fit across the nav bar without truncating, so the
    // surface is set explicitly rather than left at the default.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    // The app boots on Home (`/` -> `/home`); with no templates yet it shows
    // the "point at Workout" empty state.
    await pumpUntilData(tester, until: find.text('Go to Workout'));

    for (final label in ['HOME', 'EXPLORE', 'WORKOUT', 'LIBRARY', 'YOU']) {
      expect(find.text(label), findsOneWidget, reason: '$label destination');
    }

    // Order matters — assert via each label's on-screen x position rather
    // than tree order (which isn't guaranteed to match paint order for
    // arbitrary widgets).
    final xs = [
      for (final label in ['HOME', 'EXPLORE', 'WORKOUT', 'LIBRARY', 'YOU'])
        tester.getTopLeft(find.text(label)).dx,
    ];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i - 1], lessThan(xs[i]), reason: 'destination $i is out of order');
    }

    await tester.tap(find.text('EXPLORE'));
    await pumpUntilData(tester, until: find.widgetWithText(AppBar, 'Exercises'));

    await tester.tap(find.text('WORKOUT'));
    // Since T-013 this tab is S-003's day launchpad: its top bar carries the
    // date, not the word "Workout", so the empty-state heading is what
    // identifies it.
    await pumpUntilData(tester, until: find.text('No workouts today'));
    expect(find.text('No workouts today'), findsOneWidget);

    await tester.tap(find.text('LIBRARY'));
    await pumpUntilData(tester, until: find.widgetWithText(AppBar, 'Library'));
    expect(find.text('Routines'), findsOneWidget);

    await tester.tap(find.text('YOU'));
    await pumpUntilData(tester, until: find.widgetWithText(AppBar, 'You'));
    // History kept its screen but lost its tab: it is reachable from here.
    expect(find.text('Workout log'), findsOneWidget);

    // Switching back to Home preserves its earlier-loaded state rather
    // than re-showing a loading spinner.
    await tester.tap(find.text('HOME'));
    await tester.pump();
    expect(find.text('Go to Workout'), findsOneWidget);

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

  testWidgets('two tabs each with a FAB do not collide on a route push',
      (tester) async {
    // `StatefulShellRoute.indexedStack` keeps every tab alive at once, so
    // Explore's and Workout's FABs are in the tree together. With the default
    // hero tag they are two heroes sharing one tag, and the assertion fires
    // the moment a route transition runs a hero search.
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Go to Workout'));

    await tester.tap(find.text('EXPLORE'));
    await pumpUntilData(tester, until: find.widgetWithText(AppBar, 'Exercises'));
    await tester.tap(find.text('WORKOUT'));
    await pumpUntilData(tester, until: find.text('No workouts today'));

    // Starting an ad-hoc session pushes /session — a real transition, and the
    // cheapest one to reach with no seeded data.
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Start new workout'));
    await pumpUntilSessionData(tester);

    expect(tester.takeException(), isNull);

    // The structural cause, asserted directly: reproducing the runtime
    // assertion depends on hero-search timing during a transition, but two
    // FABs sharing one tag is the defect whatever the timing.
    // `skipOffstage: false` is the point: the inactive tab's Scaffold is
    // offstage, not unmounted, so its FAB is still a hero in this subtree —
    // and invisible to a default finder.
    final tags = tester
        .widgetList<FloatingActionButton>(
            find.byType(FloatingActionButton, skipOffstage: false))
        .map((f) => f.heroTag)
        .toList();
    expect(tags, everyElement(isNotNull),
        reason: 'a null tag is the shared default');
    expect(tags.toSet(), hasLength(tags.length),
        reason: 'every live FAB needs its own hero tag');

    await disposeAndDrainTimers(tester, container: container);
  });
}
