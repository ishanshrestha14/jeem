import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/theme/semantic_colors.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/sessions/ui/widgets/rest_bar.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';

/// See the doc comment above `pumpUntilSessionData` in
/// `active_session_test.dart` for the full reproduction evidence of why
/// this screen needs `tester.runAsync` rather than plain `pumpUntilData` or
/// awaiting the controller's own future. Reused verbatim, as that comment
/// directs for Tasks 14/15/16/19.
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

/// Parses the widget's own `mmss` display ("1:30") back into whole seconds.
int _displayedSeconds(WidgetTester tester, Key key) {
  final text = tester.widget<Text>(find.byKey(key)).data!;
  final parts = text.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
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

  /// `restTickerProvider` is a `StreamProvider.autoDispose` backed by an
  /// unbounded `while (true) { await Future.delayed(500ms); yield ...; }`
  /// generator. Once it has been watched at least once, unmounting the
  /// watching widget is not by itself enough to make its *currently
  /// pending* `Future.delayed` Timer go away — that Timer already exists in
  /// the fake-time zone and nothing retroactively cancels it merely by the
  /// widget disappearing. Confirmed by direct reproduction: tearing a
  /// harness down with only `pumpWidget(shrink) + pump()` (as
  /// `disposeAndDrainTimers` does for Drift's zero-duration cleanup Timer)
  /// left a `!timersPending` failure every time, even after several more
  /// 600ms pumps and even after `container.dispose()`. Explicitly
  /// invalidating the provider *and* pumping fake time past its 500ms
  /// period drains it deterministically, so this is used instead of (or in
  /// addition to) `disposeAndDrainTimers` in every test here that touched
  /// an active/paused rest.
  Future<void> disposeRestScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.invalidate(restTickerProvider);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Seeds a session with one exercise ("Bench Press", 2 target sets, 90s
  /// rest) and completes its first set, landing the screen with a running
  /// rest whose next target is "Bench Press — Set 2".
  Future<void> startRestingSession(WidgetTester tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
      name: 'Bench Press',
      loggingType: LoggingType.strengthWeightRepsRir,
    );
    await templates.addExercise(
      templateId: t.id,
      exerciseId: bench.id,
      targetSets: 2,
      restSeconds: 90,
    );
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await pumpUntilSessionData(tester);
  }

  testWidgets('completing a set reveals the rest bar with the next target',
      (tester) async {
    await startRestingSession(tester);

    expect(find.byType(RestBar), findsOneWidget);
    expect(find.textContaining('Next: Bench Press — Set 2'), findsOneWidget);
    // The DB round-trip in completeSet() consumes a little real wall-clock
    // time before this assertion runs, so the exact second can legitimately
    // read 90 or (rarely) one tick below it — assert a tight band around
    // 90s rather than a single hard-coded literal.
    final seconds =
        _displayedSeconds(tester, const Key('restCountdownText'));
    expect(seconds, inInclusiveRange(85, 90));

    await disposeRestScreen(tester);
  });

  testWidgets('+15s extends the countdown', (tester) async {
    await startRestingSession(tester);
    final before =
        _displayedSeconds(tester, const Key('restCountdownText'));

    await tester.tap(find.text('+15s'));
    await pumpUntilSessionData(tester);

    final after = _displayedSeconds(tester, const Key('restCountdownText'));
    // Assert the DISPLAYED time actually moved by ~15s, not merely that
    // adjustRest() was invoked. A generous tolerance absorbs the real
    // wall-clock drift documented above; it's nowhere near wide enough to
    // also pass a no-op or a -15s regression (see deletion check).
    expect(after - before, inInclusiveRange(10, 17));

    await disposeRestScreen(tester);
  });

  testWidgets('-15s shortens the countdown', (tester) async {
    await startRestingSession(tester);
    final before =
        _displayedSeconds(tester, const Key('restCountdownText'));

    await tester.tap(find.text('-15s'));
    await pumpUntilSessionData(tester);

    final after = _displayedSeconds(tester, const Key('restCountdownText'));
    expect(before - after, inInclusiveRange(13, 20));

    await disposeRestScreen(tester);
  });

  testWidgets(
      'skip ends rest and replaces the bar with the rest-complete banner',
      (tester) async {
    await startRestingSession(tester);

    await tester.tap(find.byIcon(Icons.skip_next));
    await pumpUntilSessionData(tester);

    // The running countdown/progress UI is gone...
    expect(find.byKey(const Key('restCountdownText')), findsNothing);
    expect(find.byIcon(Icons.skip_next), findsNothing);
    // ...replaced by the finished banner (PRD FR-108/109): still inside
    // RestBar (restJustFinished keeps the bar mounted), not hidden outright.
    expect(find.byType(RestBar), findsOneWidget);
    expect(find.text('Rest complete'), findsOneWidget);
    expect(find.text('Next set'), findsOneWidget);

    await disposeRestScreen(tester);
  });

  testWidgets(
      'tapping "Next set" on the finished banner focuses the target and '
      'hides the bar', (tester) async {
    await startRestingSession(tester);
    await tester.tap(find.byIcon(Icons.skip_next));
    await pumpUntilSessionData(tester);
    expect(find.byType(RestBar), findsOneWidget);

    // Rest stopped being active (and so stopped being watched) the moment
    // it finished above — drain the ticker's pending timer here, while
    // still close to that transition, rather than only at teardown.
    container.invalidate(restTickerProvider);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }

    await tester.tap(find.text('Next set'));
    await pumpUntilSessionData(tester);

    expect(find.byType(RestBar), findsNothing);

    await disposeRestScreen(tester);
  });

  testWidgets('pausing shows the paused colour and freezes the countdown',
      (tester) async {
    await startRestingSession(tester);

    await tester.tap(find.byIcon(Icons.pause));
    await pumpUntilSessionData(tester);

    final frozen =
        _displayedSeconds(tester, const Key('restCountdownText'));
    final colors = AppTheme.dark().extension<SemanticColors>()!;
    final textWidget =
        tester.widget<Text>(find.byKey(const Key('restCountdownText')));
    expect(textWidget.style?.color, colors.warning);

    // Advance fake time well past a couple of 500ms ticks — a genuinely
    // paused timer must not have moved even though the ticker (which still
    // runs while paused, per design) keeps forcing rebuilds.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));

    final after =
        _displayedSeconds(tester, const Key('restCountdownText'));
    expect(after, frozen);

    await disposeRestScreen(tester);
  });

  testWidgets('tapping the bar opens the expanded sheet', (tester) async {
    await startRestingSession(tester);

    await tester.tap(find.byType(RestBar));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // The sheet's own 220dp CircularProgressIndicator, plus the "Undo last
    // set" control that isn't present on the compact bar.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Undo last set'), findsOneWidget);
    expect(find.text('Cancel rest'), findsOneWidget);

    await disposeRestScreen(tester);
  });

  testWidgets('"Undo last set" in the sheet uncompletes the set and cancels '
      'rest', (tester) async {
    await startRestingSession(tester);

    await tester.tap(find.byType(RestBar));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Undo last set'));
    await pumpUntilSessionData(tester);

    // Rest was anchored on the undone set, so it's cancelled outright, and
    // the bar disappears.
    expect(find.byType(RestBar), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await disposeRestScreen(tester);
  });
}
