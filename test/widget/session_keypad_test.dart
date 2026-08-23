import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/widgets/app_keypad.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';
import 'active_session_test.dart' show pumpUntilSessionData;
import 'pump_helpers.dart';

/// T-003 / CMP-018: set values are edited with an in-app keypad rather than
/// the system keyboard, so the layout never shifts mid-set, every key is a
/// thumb-sized target, and the pad can carry actions no OS keyboard has.
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

  /// A strength session with [sets] sets on one exercise.
  Future<void> startSession({int sets = 2}) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: sets);
    await SessionRepository(db).startFromTemplate(t.id, weightUnit: 'kg');
  }

  /// Positional, not content-based: `find.widgetWithText(TextField, '')`
  /// re-evaluates lazily, so once a field has a value the "first empty field"
  /// silently becomes a different one.
  Finder weightField(int set) => find.byType(TextField).at(set * 2);
  Finder repsField(int set) => find.byType(TextField).at(set * 2 + 1);

  Finder keypadKey(String label) => find.descendant(
        of: find.byType(AppKeypad),
        matching: find.text(label),
      );

  testWidgets('expanding one exercise collapses the other (single-open)',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    final press = await exercises.create(
        name: 'Overhead Press', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 1);
    await templates.addExercise(
        templateId: t.id, exerciseId: press.id, targetSets: 1);
    await SessionRepository(db).startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    // "Add set" only renders inside an expanded card, so it identifies which
    // exercise is open — a bare TextField count could pass vacuously if the
    // tap did nothing at all.
    Finder addSetIn(String exerciseId) => find.descendant(
          of: find.byKey(ValueKey<String>(exerciseId)),
          matching: find.text('Add set'),
        );
    final rows = await db.select(db.sessionExercises).get();
    final benchRow = rows.firstWhere((r) => r.name == 'Bench Press');
    final pressRow = rows.firstWhere((r) => r.name == 'Overhead Press');

    // The current exercise starts open; the other does not.
    expect(addSetIn(benchRow.id), findsOneWidget);
    expect(addSetIn(pressRow.id), findsNothing);

    // Expansion is toggled by the card's chevron, not by its title.
    final expandPress = find.descendant(
      of: find.byKey(ValueKey<String>(pressRow.id)),
      matching: find.byIcon(Icons.expand_more),
    );
    await tester.ensureVisible(expandPress);
    await tester.pump();
    await tester.tap(expandPress);
    await tester.pumpAndSettle();

    // Expanding the second collapses the first (S-006: single-open).
    expect(addSetIn(pressRow.id), findsOneWidget,
        reason: 'the tapped exercise must open');
    expect(addSetIn(benchRow.id), findsNothing,
        reason: 'only one exercise may be expanded at a time');
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('stays closed until a field is tapped', (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    expect(keypadKey('1'), findsNothing);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('opens on tap and does not raise the system keyboard',
      (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    await tester.tap(weightField(0));
    await tester.pumpAndSettle();

    expect(keypadKey('1'), findsOneWidget);
    // `readOnly` is what keeps the OS keyboard down while leaving the field
    // focusable and caret-visible.
    expect(tester.widget<TextField>(weightField(0)).readOnly, isTrue);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('offers a decimal point for weight but not for reps',
      (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    await tester.tap(weightField(0));
    await tester.pumpAndSettle();
    expect(keypadKey('.'), findsOneWidget);

    await tester.tap(repsField(0));
    await tester.pumpAndSettle();
    // Withheld rather than rejected: a fractional rep is unreachable, so no
    // error message is ever needed.
    expect(keypadKey('.'), findsNothing);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('enters a decimal weight and persists it', (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    await typeOnKeypad(tester, weightField(0), '62.5');
    await pumpUntilSessionData(tester);

    final rows = await (db.select(db.sessionSets)
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .get();
    expect(rows.first.weight, 62.5);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('backspace deletes the last character', (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    await typeOnKeypad(tester, weightField(0), '85');
    await tester.tap(find.descendant(
      of: find.byType(AppKeypad),
      matching: find.byIcon(Icons.backspace_outlined),
    ));
    await pumpUntilSessionData(tester);

    final rows = await (db.select(db.sessionSets)
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .get();
    expect(rows.first.weight, 8);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('typing replaces the existing value rather than appending it',
      (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    await typeOnKeypad(tester, weightField(0), '80');
    await pumpUntilSessionData(tester);

    // Move focus away and back: arriving at a field selects its whole value,
    // so the next keypress overwrites. The field carries the routine's plan,
    // and the common edit is "not that", not "append a digit". (Tapping a
    // field that already has focus just moves the caret, as anywhere else.)
    await tester.tap(repsField(0));
    await tester.pumpAndSettle();
    await typeOnKeypad(tester, weightField(0), '9');
    await pumpUntilSessionData(tester);

    final rows = await (db.select(db.sessionSets)
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .get();
    expect(rows.first.weight, 9);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('Next moves weight -> reps, then wraps into the next set',
      (tester) async {
    await startSession(sets: 2);
    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    await typeOnKeypad(tester, weightField(0), '100');
    await pumpUntilSessionData(tester);

    // weight -> reps of the same set
    await tester.tap(keypadKey('Next'));
    await tester.pumpAndSettle();
    for (final c in ['1', '0']) {
      await tester.tap(keypadKey(c));
      await tester.pump();
    }
    await pumpUntilSessionData(tester);

    // reps -> the *next set's* weight, across the row boundary
    await tester.tap(keypadKey('Next'));
    await tester.pumpAndSettle();
    for (final c in ['9', '5']) {
      await tester.tap(keypadKey(c));
      await tester.pump();
    }
    await pumpUntilSessionData(tester);

    final rows = await (db.select(db.sessionSets)
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .get();
    expect(rows[0].weight, 100);
    expect(rows[0].reps, 10);
    expect(rows[1].weight, 95, reason: 'Next wrapped into the following set');
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('the close key dismisses the pad', (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    await tester.tap(weightField(0));
    await tester.pumpAndSettle();
    expect(keypadKey('1'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(AppKeypad),
      matching: find.byIcon(Icons.keyboard_hide_outlined),
    ));
    await tester.pumpAndSettle();

    expect(keypadKey('1'), findsNothing);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('the RIR key logs reps-in-reserve for the focused set',
      (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    await tester.tap(weightField(0));
    await tester.pumpAndSettle();
    await tester.tap(keypadKey('RIR'));
    await tester.pumpAndSettle();

    expect(find.text('Reps in reserve'), findsOneWidget);
    // Scoped to the sheet's tiles: the keypad's own "2" key is still in the
    // tree behind the modal barrier, so a bare `find.text('2')` is ambiguous.
    // The list of RIR values is taller than the sheet, so scroll it into
    // view first — a tap on an offscreen widget lands somewhere else.
    final tile = find.widgetWithText(ListTile, '2');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    // The handler awaits the sheet and then the database; fake-time pumps
    // alone never let that second await finish.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await pumpUntilSessionData(tester);

    final rows = await (db.select(db.sessionSets)
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .get();
    expect(rows.first.rir, 2);
    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('a completed set is still editable via the keypad (PRD §17)',
      (tester) async {
    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    await tester.tap(find.byTooltip('Complete set').first);
    await pumpUntilSessionData(tester);

    await typeOnKeypad(tester, weightField(0), '70');
    await pumpUntilSessionData(tester);

    final rows = await (db.select(db.sessionSets)
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .get();
    expect(rows.first.weight, 70);
    await disposeAndDrainTimers(tester, container: container);
  });
}
