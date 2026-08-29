import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/widgets/line_chart.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/exercises/ui/exercise_detail_screen.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/test_database.dart';
import 'pump_helpers.dart';

/// T-027 — S-025's fourth pane, deferred by T-018 because charting was new to
/// this codebase.
void main() {
  late AppDatabase db;

  setUp(() {
    db = testDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Widget harness(String id) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: ExerciseDetailScreen(exerciseId: id),
        ),
      );

  Future<String> anExercise({
    String name = 'Bench Press',
    LoggingType loggingType = LoggingType.strengthWeightRepsRir,
  }) async {
    final e = await ExerciseRepository(db).create(
      name: name,
      loggingType: loggingType,
      description: 'Press the bar.',
    );
    return e.id;
  }

  /// One finished session logging [weight] x 5 of [exerciseId].
  Future<void> aLoggedSession(String exerciseId, {double weight = 100}) async {
    final templates = TemplateRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Push A');
    await templates.addExercise(
        templateId: t.id, exerciseId: exerciseId, targetSets: 1);
    final s = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    final set = (await db.select(db.sessionSets).get()).last;
    await sessions.updateSet(set.copyWith(
      weight: Value(weight),
      reps: const Value(5),
      completedAt: Value(DateTime.now()),
    ));
    await sessions.finishSession(s.id);
  }

  testWidgets('a strength exercise has a Progress tab', (tester) async {
    final id = await anExercise();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Press the bar.'));

    expect(find.text('Progress'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('a duration-logged exercise has no Progress tab', (tester) async {
    // An estimated 1RM for a plank is meaningless, and ADR-004 already gives
    // duration work no records at all.
    final id = await anExercise(
      name: 'Plank',
      loggingType: LoggingType.durationOnly,
    );

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Press the bar.'));

    expect(find.text('Progress'), findsNothing);
    expect(find.text('Records'), findsOneWidget,
        reason: 'the other three panes are unaffected');
    await disposeAndDrainTimers(tester);
  });

  testWidgets('an exercise never performed shows the empty state, not a chart',
      (tester) async {
    final id = await anExercise();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Press the bar.'));
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('No progress yet'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('a performed exercise charts its sessions', (tester) async {
    final id = await anExercise();
    await aLoggedSession(id, weight: 90);
    await aLoggedSession(id, weight: 100);

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Press the bar.'));
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('No progress yet'), findsNothing);
    await disposeAndDrainTimers(tester);
  });
}
