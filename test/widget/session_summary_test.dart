import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/sessions/ui/session_summary_screen.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/test_database.dart';
import '../session_feedback_fakes.dart';
import 'pump_helpers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  GoRouter? routerRef;

  setUp(() {
    db = testDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// See `active_session_test.dart`'s `pumpUntilSessionData` for the full
  /// mechanism/rationale (Drift's hand-rolled `.first`-based reload needs a
  /// genuine event-loop turn that the fake clock never provides on its
  /// own) — duplicated here rather than imported to keep this file's
  /// harness self-contained.
  Future<void> pumpUntilSessionData(
    WidgetTester tester, {
    int maxIterations = 50,
  }) async {
    for (var i = 0; i < maxIterations; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    }
  }

  // The summary's content (stat grid + two exercises' worth of set lines)
  // is taller than the default 800x600 test surface, so a plain ListView
  // (not lazily built beyond the viewport) never builds the second
  // exercise's widgets at all — `find.text` then reports 0 matches for
  // content that exists in the model but was never built. Enlarge the
  // surface instead of scrolling, matching the pattern already used in
  // exercise_editor_image_test.dart for the same reason.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget harness(String sessionId, {bool readOnly = false}) {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ...sessionFeedbackOverrides(),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: SessionSummaryScreen(sessionId: sessionId, readOnly: readOnly),
      ),
    );
  }

  /// Seeds a session with two strength exercises (3 target sets each — 6
  /// total) and completes one set on each: 80kg x 8 on the first, 80kg x 6
  /// on the second. 2/6 sets complete, volume 80*8 + 80*6 = 1120.
  ///
  /// Runs entirely inside [WidgetTester.runAsync]: `SessionRepository`'s
  /// `watchSession(id).first` needs a real event-loop turn for its
  /// hand-rolled stream's cancel to settle, which the ambient
  /// `AutomatedTestWidgetsFlutterBinding` fake clock never provides on its
  /// own — see the doc comment on `pumpUntilSessionData` in
  /// `active_session_test.dart` for the full mechanism (confirmed there by
  /// direct reproduction: this exact `.first` shape hangs indefinitely
  /// under plain `tester.pump()`, even across 300 pumps, unless run inside
  /// `runAsync`).
  Future<String> seedPartialSession(WidgetTester tester) async {
    return (await tester.runAsync(() async {
      final templates = TemplateRepository(db);
      final exercises = ExerciseRepository(db);
      final sessions = SessionRepository(db);

      final t = await templates.createTemplate(name: 'Push Day');
      final bench = await exercises.create(
          name: 'Bench Press',
          loggingType: LoggingType.strengthWeightRepsRir);
      final ohp = await exercises.create(
          name: 'Overhead Press',
          loggingType: LoggingType.strengthWeightRepsRir);
      await templates.addExercise(
          templateId: t.id, exerciseId: bench.id, targetSets: 3);
      await templates.addExercise(
          templateId: t.id, exerciseId: ohp.id, targetSets: 3);

      final session = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
      final active = await sessions.watchSession(session.id).first;
      final benchExercise = active!.exercises
          .firstWhere((e) => e.exercise.name == 'Bench Press');
      final ohpExercise = active.exercises
          .firstWhere((e) => e.exercise.name == 'Overhead Press');

      await sessions.updateSet(benchExercise.sets.first.copyWith(
        weight: const Value(80),
        reps: const Value(8),
        completedAt: Value(DateTime.now()),
      ));
      await sessions.updateSet(ohpExercise.sets.first.copyWith(
        weight: const Value(80),
        reps: const Value(6),
        completedAt: Value(DateTime.now()),
      ));

      return session.id;
    }))!;
  }

  testWidgets('summary reports duration, sets, exercises and volume',
      (tester) async {
    final sessionId = await seedPartialSession(tester);

    await tester.pumpWidget(harness(sessionId));
    await pumpUntilData(tester, until: find.text('2 / 6 sets'));

    expect(find.text('2 / 6 sets'), findsOneWidget);
    expect(find.textContaining('1120 kg'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('per-exercise breakdown shows completed and incomplete sets',
      (tester) async {
    useTallSurface(tester);
    final sessionId = await seedPartialSession(tester);

    await tester.pumpWidget(harness(sessionId));
    await pumpUntilData(tester, until: find.text('2 / 6 sets'));

    expect(find.text('Set 1 · 80 kg × 8 · RIR —'), findsOneWidget);
    expect(find.text('Set 1 · 80 kg × 6 · RIR —'), findsOneWidget);

    // The remaining 4 target sets are still incomplete.
    expect(find.text('Set 2 · —'), findsNWidgets(2));
    expect(find.text('Set 3 · —'), findsNWidgets(2));

    await disposeAndDrainTimers(tester);
  });

  testWidgets('Save and Discard are shown when not read-only', (tester) async {
    useTallSurface(tester);
    final sessionId = await seedPartialSession(tester);

    await tester.pumpWidget(harness(sessionId));
    await pumpUntilData(tester, until: find.text('2 / 6 sets'));

    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Discard'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isTrue);

    await disposeAndDrainTimers(tester);
  });

  /// Like [harness], but with a real [GoRouter] wired for `/session`,
  /// `/session/summary/:id` and `/home` — adapted from
  /// `active_session_test.dart`'s `routedHarness` (Task 19's fix round).
  /// Keeping `/session` (`ActiveSessionScreen`) in the route stack matters:
  /// it's the widget that watches `activeSessionControllerProvider`, and
  /// since that provider is `autoDispose`, pushing (never `go`-replacing)
  /// on top of it is what keeps the controller alive and resolved while the
  /// summary screen is also on screen — exactly mirroring the app's one
  /// real entry point to this screen (the active session's own Finish
  /// flow).
  Widget routedHarness() {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ...sessionFeedbackOverrides(),
      ],
    );
    final router = GoRouter(
      initialLocation: '/session',
      routes: [
        GoRoute(
          path: '/session',
          builder: (_, _) => const ActiveSessionScreen(),
        ),
        GoRoute(
          path: '/session/summary/:id',
          builder: (_, s) => SessionSummaryScreen(
            sessionId: s.pathParameters['id']!,
            readOnly: s.uri.queryParameters['readOnly'] == 'true',
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    routerRef = router;
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    );
  }

  testWidgets(
      'Save on a live summary whose sessionId matches the active session '
      'commits it: status becomes completed and notes persist',
      (tester) async {
    useTallSurface(tester);
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 3);
    final session = await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(routedHarness());
    await pumpUntilSessionData(tester);

    // Reach the summary screen the same way the app does: the active
    // session's own Finish flow. This guarantees
    // `activeSessionControllerProvider` is already resolved and pointing
    // at exactly this session by the time Save is tapped.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish anyway'));
    await pumpUntilData(tester, until: find.text('Summary'));

    // `find.byType(TextField)` alone would also match set-input fields on
    // the still-mounted `ActiveSessionScreen` underneath (this screen was
    // reached via `push`, not `go`, so the previous route stays in the
    // tree) — the notes field is the only one with this hint text.
    await tester.enterText(
      find.widgetWithText(TextField, 'How did it go?'),
      'Felt strong today',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await pumpUntilData(tester, until: find.text('Home'));

    final row = await (db.select(db.workoutSessions)
          ..where((tbl) => tbl.id.equals(session.id)))
        .getSingle();
    expect(row.status, SessionStatus.completed);
    expect(row.notes, 'Felt strong today');

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets(
      'Save refuses to commit when the displayed session differs from the '
      "controller's actual active session (the tautology bug's regression "
      'test)', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 3);

    // Two active sessions: A started first, B started second so
    // `watchActiveSession` (most recent by `startedAt`) resolves to B —
    // the one `ActiveSessionScreen`/the controller actually track. A is a
    // stray second active session that never should have its own summary
    // screen shown live, but a future caller could still construct one by
    // hand (e.g. forgetting `readOnly`).
    // Real (not fake-clock) delay between the two so `startedAt` can't tie
    // — `watchActiveSession` breaks ties by `startedAt desc`, and this test
    // depends on B unambiguously winning that ordering.
    final sessionA = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    final sessionB = await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(routedHarness());
    await pumpUntilSessionData(tester);

    // Confirm the controller really did resolve to B before pushing A's
    // summary on top — otherwise this test would pass for the wrong
    // reason (an unresolved/loading controller also reads as "no match").
    final resolved = container.read(activeSessionControllerProvider).value;
    expect(resolved!.session.session.id, sessionB.id);

    routerRef!.push('/session/summary/${sessionA.id}');
    await pumpUntilData(tester, until: find.text('Summary'));

    // The guard's `assert(false, ...)` on a mismatch throws inside
    // `_handleSave`'s async body in debug/test builds (a separately parked
    // issue — not being fixed here). That's an unhandled `Future` error,
    // not one the framework's own build/layout error path catches, so
    // plain `tester.takeException()` can't intercept it — by the time
    // control would return to this test, `TestWidgetsFlutterBinding`'s
    // zone-level `handleUncaughtError` has already treated it as a fatal
    // test failure. Fork a guarded zone around just the tap so the thrown
    // `AssertionError` is caught here instead of escaping to that outer
    // zone.
    Object? caught;
    await runZonedGuarded(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
    }, (error, stack) => caught = error);
    expect(caught, isA<AssertionError>());

    // Neither session was touched: A (displayed but not active) stayed
    // active, and — the case this guard actually exists for — B (the
    // real active session, sitting untouched in the background) was NOT
    // silently completed behind the user's back.
    final rowA = await (db.select(db.workoutSessions)
          ..where((tbl) => tbl.id.equals(sessionA.id)))
        .getSingle();
    final rowB = await (db.select(db.workoutSessions)
          ..where((tbl) => tbl.id.equals(sessionB.id)))
        .getSingle();
    expect(rowA.status, SessionStatus.active);
    expect(rowB.status, SessionStatus.active);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('Save and Discard are hidden in read-only mode', (tester) async {
    useTallSurface(tester);
    final sessionId = await seedPartialSession(tester);

    await tester.pumpWidget(harness(sessionId, readOnly: true));
    await pumpUntilData(tester, until: find.text('2 / 6 sets'));

    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Discard'), findsNothing);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);

    await disposeAndDrainTimers(tester);
  });
}
