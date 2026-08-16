import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/history/ui/history_screen.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';
import 'pump_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const HistoryScreen(),
        ),
      );

  testWidgets('shows the empty state when there are no completed sessions',
      (tester) async {
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('No completed sessions yet'));

    expect(find.text('No completed sessions yet'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('renders a completed session with its set progress',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);

    final t = await templates.createTemplate(name: 'Push Day');
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 2);

    final session = await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    // Complete one of the two seeded sets so the screen's fraction reads
    // "1/2 sets" rather than "0/2".
    final rows = await (db.select(db.sessionSets)).get();
    await sessions.updateSet(
      rows.first.copyWith(completedAt: Value(DateTime.now())),
    );
    await sessions.finishSession(session.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Push Day'));

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('1/2 sets'), findsOneWidget);
    expect(find.text('No completed sessions yet'), findsNothing);

    await disposeAndDrainTimers(tester);
  });
}
