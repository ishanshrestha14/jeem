import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/exercises/ui/exercise_picker_sheet.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';
import 'pump_helpers.dart';

/// S-026: opened mid-session, the picker leads with what you have actually
/// done rather than the alphabetical library. Mid-set, recency beats
/// alphabetical.
void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Widget harness({required bool recentFirst}) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () =>
                      showExercisePickerSheet(context, recentFirst: recentFirst),
                  child: const Text('Open picker'),
                ),
              ),
            ),
          ),
        ),
      );

  /// 'Zebra Press' performed in a finished session; 'Alpha Curl' never done.
  /// Alphabetical order would put Alpha first, so recency is visible.
  Future<void> seed() async {
    final exercises = ExerciseRepository(db);
    final templates = TemplateRepository(db);
    final sessions = SessionRepository(db);
    await exercises.create(
        name: 'Alpha Curl', loggingType: LoggingType.strengthWeightRepsRir);
    final zebra = await exercises.create(
        name: 'Zebra Press', loggingType: LoggingType.strengthWeightRepsRir);

    final t = await templates.createTemplate(name: 'Push');
    await templates.addExercise(
        templateId: t.id, exerciseId: zebra.id, targetSets: 1);
    final s = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    final set = (await db.select(db.sessionSets).get()).last;
    await sessions.updateSet(set.copyWith(
      weight: const Value(60),
      reps: const Value(8),
      completedAt: Value(DateTime.now()),
    ));
    await sessions.finishSession(s.id);
  }

  testWidgets('mid-session, a performed exercise leads the list',
      (tester) async {
    await seed();

    await tester.pumpWidget(harness(recentFirst: true));
    await tester.tap(find.text('Open picker'));
    await pumpUntilData(tester, until: find.text('Recent'));

    expect(find.text('Recent'), findsOneWidget);
    final yZebra = tester.getTopLeft(find.text('Zebra Press')).dy;
    final yAlpha = tester.getTopLeft(find.text('Alpha Curl')).dy;
    expect(yZebra, lessThan(yAlpha),
        reason: 'recency beats alphabetical mid-set');

    await disposeAndDrainTimers(tester);
  });

  testWidgets('elsewhere the picker stays alphabetical', (tester) async {
    await seed();

    await tester.pumpWidget(harness(recentFirst: false));
    await tester.tap(find.text('Open picker'));
    await pumpUntilData(tester, until: find.text('Alpha Curl'));

    // Building a routine is not mid-set: there is no reason to reorder the
    // library, and a section that appears sometimes is harder to learn.
    expect(find.text('Recent'), findsNothing);
    final yZebra = tester.getTopLeft(find.text('Zebra Press')).dy;
    final yAlpha = tester.getTopLeft(find.text('Alpha Curl')).dy;
    expect(yAlpha, lessThan(yZebra));

    await disposeAndDrainTimers(tester);
  });

  testWidgets('with nothing performed there is no Recent section',
      (tester) async {
    await ExerciseRepository(db).create(
        name: 'Alpha Curl', loggingType: LoggingType.strengthWeightRepsRir);

    await tester.pumpWidget(harness(recentFirst: true));
    await tester.tap(find.text('Open picker'));
    await pumpUntilData(tester, until: find.text('Alpha Curl'));

    // An empty section header would be noise on a first workout.
    expect(find.text('Recent'), findsNothing);

    await disposeAndDrainTimers(tester);
  });
}
