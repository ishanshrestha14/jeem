import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/exercises/ui/exercise_detail_screen.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/test_database.dart';
import 'pump_helpers.dart';

/// S-025: everything known about one exercise — how to do it, what you have
/// done, and your best. Ours is About · History · Records; Progress needs
/// charting we do not have, and Leaderboard is social.
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

  Future<String> anExercise({String name = 'Bench Press'}) async {
    final e = await ExerciseRepository(db).create(
      name: name,
      loggingType: LoggingType.strengthWeightRepsRir,
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

  testWidgets('opens on About, showing the name and description',
      (tester) async {
    final id = await anExercise();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Press the bar.'));

    expect(find.text('Bench Press'), findsWidgets);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
  });

  testWidgets('History lists the sessions this exercise appeared in',
      (tester) async {
    final id = await anExercise();
    await aLoggedSession(id);

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('About'));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Push A'), findsOneWidget);
    expect(find.textContaining('100'), findsWidgets);
  });

  testWidgets('History says so when the exercise has never been done',
      (tester) async {
    final id = await anExercise();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('About'));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.textContaining('never'), findsOneWidget);
  });

  testWidgets('Records shows the heaviest lift once there is history',
      (tester) async {
    final id = await anExercise();
    await aLoggedSession(id, weight: 80);
    await aLoggedSession(id, weight: 120);

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('About'));
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();

    expect(find.text('Heaviest weight'), findsOneWidget);
    expect(find.textContaining('120'), findsWidgets);
  });

  testWidgets('editing is in the overflow, not the surface', (tester) async {
    final id = await anExercise();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('About'));

    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
  });
}
