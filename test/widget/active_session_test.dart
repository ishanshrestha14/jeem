import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/sessions/ui/session_summary_screen.dart';
import 'package:gymflow/features/sessions/ui/widgets/duration_set_row.dart';
import 'package:gymflow/features/sessions/ui/widgets/rest_bar.dart';
import 'package:gymflow/features/sessions/ui/widgets/strength_set_row.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/test_database.dart';
import '../session_feedback_fakes.dart';
import 'pump_helpers.dart';

/// Both `ActiveSessionController.build()` and every one of its mutators
/// (`completeSet`, `updateSetValues`, ...) reload the post-write session via
/// `SessionRepository.watchSession(id).first` / `.watchActiveSession().first`.
/// `Stream.first`'s `_cancelAndValue` awaits the subscription's `cancel()`
/// future before completing, and `SessionRepository`'s hand-rolled
/// `_watchAggregate` cancellation needs a genuine event-loop turn to settle
/// — which plain `tester.pump()` calls never provide under
/// `AutomatedTestWidgetsFlutterBinding`'s fake clock (confirmed by isolating
/// the hang to exactly this `.first` call: swapping it for a manual,
/// non-awaited-cancel subscription resolved immediately under the same pump
/// loop that otherwise stalled indefinitely, even across 300 pumps).
/// `pumpUntilData` alone therefore hangs on this screen.
///
/// `tester.runAsync` is flutter_test's sanctioned escape hatch for exactly
/// this: it briefly runs real (non-simulated) async code so a pending Future
/// chain can actually resolve.
///
/// Two things were tried and rejected before landing on the approach below
/// — both verified by direct reproduction, not assumption:
///
/// 1. A single fixed sleep — `runAsync(() => Future.delayed(100ms))` then
///    pump — works, but is a magic number: on a loaded CI runner, if the
///    real fetch+cancel round trip ever exceeds 100ms this flakes instead
///    of failing deterministically.
/// 2. Awaiting the notifier's own Future directly —
///    `container.read(activeSessionControllerProvider.future)` inside
///    `runAsync` — looked like the "obviously correct" deterministic fix,
///    but **hangs indefinitely** (reproduced and confirmed stuck past 30s).
///    `container.read(...)` from *inside* `runAsync`'s real zone also does
///    not observe the state transition even once it has genuinely happened
///    elsewhere — polling `container.read(activeSessionControllerProvider)`
///    on a real timer inside `runAsync` never once saw anything but
///    `AsyncLoading`, even after 4+ real seconds, right up until the poll
///    loop's cap was hit — yet the screen had already rendered correctly by
///    the time normal `tester.pump()` calls ran afterwards. Reading
///    Riverpod container state from inside a `runAsync` real-zone excursion
///    is therefore not a reliable readiness signal in this environment.
///
/// What *is* a reliable readiness signal — because it's exactly what
/// `pumpUntilData` already uses successfully on every other Drift-backed
/// screen in this codebase — is the widget tree itself: the screen's
/// `loading:` branch renders a `CircularProgressIndicator` and nothing
/// else does. So this repeatedly nudges real time forward in small,
/// bounded steps (letting the pending `.first`/cancel chain's real OS
/// timers/isolate messages actually get delivered) and, after each nudge,
/// pumps a frame and checks the *rendered* tree — exiting the moment the
/// spinner is gone rather than after a fixed total duration. That makes
/// the wait adaptive (fast when the reload is fast, tolerant of a slow
/// CI runner up to the iteration cap) without ever guessing a constant.
///
/// No production code changes were needed or made; this is purely a
/// test-environment characteristic of the `.first`-based reload pattern —
/// see the Task 13 report and this update's fix report for the full
/// mechanism and the two dead ends above.
///
/// Reused verbatim by Tasks 14/15/16/19, which also render this screen.
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

/// `flutter test` never loads the app's real fonts by default — text
/// measures against a generic fallback instead, which for this design
/// system's condensed/tabular styles renders noticeably *wider* than the
/// real 'Barlow'/'BarlowCondensed' faces do on-device. That's normally
/// harmless, but it means a 320dp overflow test built against the fallback
/// font can fail (or "pass") for reasons that have nothing to do with the
/// real layout at real sizes. Loading the actual asset files (no new
/// package — `dart:ui`'s `FontLoader` plus `rootBundle`, both already
/// available) keeps the "does not overflow at 320dp" test honest.
Future<void> _loadRealFonts() async {
  final barlow = FontLoader('Barlow')
    ..addFont(rootBundle.load('assets/fonts/Barlow-SemiBold.ttf'));
  await barlow.load();
  final condensed = FontLoader('BarlowCondensed')
    ..addFont(rootBundle.load('assets/fonts/BarlowCondensed-Bold.ttf'));
  await condensed.load();
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(_loadRealFonts);
  setUp(() {
    db = testDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget harness() {
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
        home: const ActiveSessionScreen(),
      ),
    );
  }

  /// Like [harness], but with a real [GoRouter] wired for `/session` and
  /// `/session/summary/:id` — needed to exercise the app bar overflow's
  /// Finish flow, which pushes to the summary screen via `context.push`
  /// (a go_router extension that throws without a `GoRouter` ancestor).
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
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: router,
      ),
    );
  }

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

    await disposeAndDrainTimers(tester, container: container);
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

    await disposeAndDrainTimers(tester, container: container);
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

    await disposeAndDrainTimers(tester, container: container);
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

    // The done control is a bare InkWell ring/disc, not a Material checkbox
    // (design system) — pending vs. complete is distinguished by its
    // tooltip, same text the old IconButton carried.
    expect(find.byTooltip('Complete set'), findsNWidgets(2));
    expect(find.byTooltip('Mark incomplete'), findsNothing);

    await tester.tap(find.byTooltip('Complete set').first);
    await pumpUntilSessionData(tester);

    expect(find.byTooltip('Mark incomplete'), findsOneWidget);
    expect(find.byTooltip('Complete set'), findsOneWidget);

    final rows = await (db.select(db.sessionSets)
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .get();
    expect(rows.first.completedAt, isNotNull);
    expect(rows.last.completedAt, isNull);

    await disposeAndDrainTimers(tester, container: container);
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

    await disposeAndDrainTimers(tester, container: container);
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
    await tester.tap(find.byTooltip('Complete set'));
    await pumpUntilSessionData(tester);

    final row = await (db.select(db.sessionSets)).getSingle();
    expect(row.completedAt, isNotNull);
    expect(row.weight, isNull);
    expect(row.reps, isNull);

    await disposeAndDrainTimers(tester, container: container);
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

    await tester.tap(find.byTooltip('Complete set').first);
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

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets(
      'the set row layout does not overflow at a 320dp-wide surface',
      (tester) async {
    // Regression test for the RenderFlex overflow this reskin also fixes:
    // `DropdownButtonFormField<double?>` in the RIR column laid out with
    // `BoxConstraints(w=7.4)` on a narrow phone. A `RenderFlex` overflow
    // raises a `FlutterError` during layout, which `tester.takeException()`
    // surfaces — it does NOT throw synchronously from `pumpWidget`, so the
    // only reliable check is asserting the exception queue is empty after
    // pumping.
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;

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

    // Give the RIR control (and weight/reps) real values, matching a
    // mid-workout row rather than an all-empty one, so any column that
    // would overflow with real digits in it is actually exercised.
    final weightField = find.widgetWithText(TextField, '').first;
    await tester.enterText(weightField, '102.5');
    await pumpUntilSessionData(tester);

    expect(find.byType(StrengthSetRow), findsNWidgets(3));
    final ex = tester.takeException();
    expect(ex, isNull);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets(
      'the rest bar does not overflow at a 320dp-wide surface',
      (tester) async {
    // Regression test: the outer Row's fixed children (countdown, two
    // `±15s` TextButtons, two IconButtons, gaps, padding) consume ~294dp of
    // a 320dp viewport, leaving the `Expanded` inner column only ~26dp —
    // less than the "NEXT" label alone needed at its natural size, so it
    // overflowed by ~11dp before `NEXT` was wrapped in a shrinkable
    // `Flexible`. `_loadRealFonts()` (see `setUpAll` above) matters here:
    // without the real 'BarlowCondensed'/'Barlow' faces, `flutter test`'s
    // fallback font renders every fixed element wide enough to overflow
    // the *outer* Row too — which very nearly produced a "fix" that wrapped
    // every child of the outer Row in `Flexible`, breaking the "tapping the
    // bar opens the expanded sheet" test in `rest_ui_test.dart` (`Expanded`
    // no longer claimed all the leftover width once its siblings had flex
    // too, which shifted the sheet's own tap target out from under the
    // point `tester.tap(find.byType(RestBar))` uses). Real fonts make this
    // test exercise the actual production-sized overflow instead. Mirrors
    // the "set row layout does not overflow at a 320dp-wide surface" test
    // above for viewport setup/teardown.
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;

    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 2, restSeconds: 90);
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    // Complete the first set to start a genuinely running rest, so the
    // `RestBar` (mounted in `bottomNavigationBar` only while rest is
    // active) actually renders.
    await tester.tap(find.byTooltip('Complete set').first);
    await pumpUntilSessionData(tester);

    expect(find.byType(RestBar), findsOneWidget);
    final ex = tester.takeException();
    expect(ex, isNull);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets(
      'typing in a different set defers the auto-focus scroll/expand and '
      'catches up once that field loses focus', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    for (final n in ['Bench Press', 'Lat Pulldown', 'Squat']) {
      final e = await exercises.create(
          name: n, loggingType: LoggingType.strengthWeightRepsRir);
      await templates.addExercise(
          templateId: t.id, exerciseId: e.id, targetSets: 1, restSeconds: 90);
    }
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    // `SessionExerciseCard`'s key is `SessionExercise.id`, a fresh id minted
    // by `startFromTemplate` — distinct from the library `Exercise.id`
    // created above — so look the ids used for widget-finding up from the
    // live session state rather than the exercise-creation calls.
    final startState =
        (await container.read(activeSessionControllerProvider.future))!;
    final ids = {
      for (final entry in startState.session.exercises)
        entry.exercise.name: entry.exercise.id,
    };

    // `ValueKey`'s equality includes its generic type parameter, so a plain
    // `ValueKey(ids['Lat Pulldown'])` here would infer `ValueKey<String?>`
    // (nullable, from the `Map` lookup) — never equal to the widget's own
    // `ValueKey<String>`. Helper below forces the non-nullable type so
    // `find.byKey` actually matches.
    ValueKey<String> keyFor(String name) => ValueKey<String>(ids[name]!);

    // Current target starts as Bench Press (first pending, session order;
    // nothing completed yet). Expand Lat Pulldown by hand and start typing
    // into its weight field — a set that is neither the current target nor
    // about to become one.
    final expandLatPulldown = find.descendant(
      of: find.byKey(keyFor('Lat Pulldown')),
      matching: find.byIcon(Icons.expand_more),
    );
    await tester.ensureVisible(expandLatPulldown);
    await tester.pump();
    await tester.tap(expandLatPulldown);
    await tester.pump();
    final latWeightField = find
        .descendant(
          of: find.byKey(keyFor('Lat Pulldown')),
          matching: find.widgetWithText(TextField, ''),
        )
        .first;
    await tester.enterText(latWeightField, '42');
    await tester.pump();

    // Move Squat to the front of session order. `currentTarget` tracks
    // session order live whenever nothing is explicitly focused — the same
    // property `nextTargetAfter`'s reorder-recomputation (Task 15) relies
    // on — so this changes the screen's current target from Bench Press to
    // Squat exactly the way a mid-rest reorder finishing with auto-focus on
    // would (PRD §18.8), without needing to choreograph an actual rest.
    // Neither the old (Bench Press) nor the new (Squat) target is the set
    // the user is typing into (Lat Pulldown).
    unawaited(
        container.read(activeSessionControllerProvider.notifier).reorder(2, 0));
    await pumpUntilSessionData(tester);

    // Deferred: Squat's card must not have been force-expanded while the
    // user is still typing elsewhere ("Add set" only renders when
    // expanded).
    expect(
      find.descendant(
        of: find.byKey(keyFor('Squat')),
        matching: find.text('Add set'),
      ),
      findsNothing,
    );
    // The typed text survived — nothing rebuilt over it or stole focus.
    expect(find.text('42'), findsOneWidget);

    // Release focus — the deferred move should now apply.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(keyFor('Squat')),
        matching: find.text('Add set'),
      ),
      findsOneWidget,
    );

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets(
      '"Finish anyway" on an incomplete session navigates to the summary '
      'without committing it — the session stays active until Save '
      '(Task 19 core invariant)', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 3);
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(routedHarness());
    await pumpUntilSessionData(tester);

    // Open the app bar overflow and tap "Finish" with sets still
    // incomplete (0/3) — this must show the "Finish workout?" dialog
    // rather than finishing straight away.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('Finish workout?'), findsOneWidget);

    await tester.tap(find.text('Finish anyway'));
    await pumpUntilData(tester, until: find.text('Summary'));

    // Landed on the summary screen...
    expect(find.text('Summary'), findsOneWidget);

    // ...but the underlying session was never committed by navigating
    // there: only Save (ActiveSessionController.finish) may do that.
    final row = await (db.select(db.workoutSessions)).getSingle();
    expect(row.status, SessionStatus.active);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets(
      'a 60-character exercise name ellipsises without pushing the info icon '
      'off a 320dp-wide screen', (tester) async {
    // PRD §18.10: very long names must wrap/ellipsise and the `i` icon must
    // stay reachable. Same 320dp viewport + real-font setup as the overflow
    // tests above — the fallback font measures wider than the real
    // 'Barlow' face, so a name-length test built against it would be
    // testing the wrong glyph widths.
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;

    const paddedName =
        'Seated Single-Arm Dumbbell Overhead Triceps Extension (Left)';
    expect(paddedName.length, 60);

    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final e = await exercises.create(
        name: paddedName, loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: e.id, targetSets: 2);
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    // Nothing overflowed while laying the header row out.
    expect(tester.takeException(), isNull);

    // The name is rendered, ellipsised (maxLines 2 + TextOverflow.ellipsis)
    // rather than allowed to push its siblings out of the row.
    final nameFinder = find.text(paddedName);
    expect(nameFinder, findsOneWidget);
    final nameWidget = tester.widget<Text>(nameFinder);
    expect(nameWidget.overflow, TextOverflow.ellipsis);
    expect(nameWidget.maxLines, 2);

    // The info icon is still fully on-screen and hit-testable — the actual
    // regression §18.10 guards against.
    final infoFinder = find.byTooltip('Exercise info');
    expect(infoFinder, findsOneWidget);
    final infoRect = tester.getRect(infoFinder);
    expect(infoRect.left, greaterThanOrEqualTo(0));
    expect(infoRect.right, lessThanOrEqualTo(320));
    expect(infoRect.width, greaterThan(0));
    await tester.tap(infoFinder);
    await tester.pumpAndSettle();
    // The sheet actually opened, so the icon was genuinely reachable.
    expect(find.text('Strength'), findsWidgets);

    await disposeAndDrainTimers(tester, container: container);
  });
}
