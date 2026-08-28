import 'package:flutter/foundation.dart';
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

/// Reproduction for the reported bug: entering weight or reps in a live
/// session closes the pad after each keystroke.
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

  Future<void> startSession() async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 2);
    await SessionRepository(db).startFromTemplate(t.id, weightUnit: 'kg');
  }

  Finder weightField(int set) => find.byType(TextField).at(set * 2);

  testWidgets('the pad stays open across successive keystrokes',
      (tester) async {
    // The whole point of this file: `flutter test` runs as
    // TargetPlatform.android, where TextField's default `onTapOutside` does
    // nothing. It unfocuses only on desktop — which is why 457 green tests
    // never saw this bug and macOS did. Cleared before the body ends, or the
    // framework fails the test for leaving a debug var set.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    await startSession();
    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    // Open the pad on the first weight field, exactly as `typeOnKeypad` does.
    await tester.ensureVisible(weightField(0));
    await tester.pump();
    await tester.tap(weightField(0));
    await tester.pumpAndSettle();
    expect(find.byType(AppKeypad), findsOneWidget,
        reason: 'tapping a field opens the pad');

    // Each digit must leave the pad open and the field focused. The report is
    // that it closes after the first one.
    for (final digit in ['8', '0', '5']) {
      final key = find.descendant(
        of: find.byType(AppKeypad),
        matching: find.text(digit),
      );
      expect(key, findsOneWidget, reason: 'pad closed before typing "$digit"');
      await tester.tap(key);
      await tester.pump();

      expect(find.byType(AppKeypad), findsOneWidget,
          reason: 'pad closed after typing "$digit"');
      final field = tester.widget<TextField>(weightField(0));
      expect(field.focusNode?.hasFocus, isTrue,
          reason: 'field lost focus after typing "$digit"');
    }

    debugDefaultTargetPlatformOverride = null;
    await disposeAndDrainTimers(tester, container: container);
  });
}
