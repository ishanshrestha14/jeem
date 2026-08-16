import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/sessions/ui/widgets/duration_set_row.dart';
import 'package:gymflow/features/sessions/ui/widgets/strength_set_row.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';
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
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const ActiveSessionScreen(),
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
}
