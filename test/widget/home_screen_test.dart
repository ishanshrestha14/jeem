import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:gymflow/features/templates/ui/home_screen.dart';
import '../db/test_database.dart';
import 'pump_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.dark(), home: const HomeScreen()),
      );

  testWidgets('empty state invites creating the first workout', (tester) async {
    await tester.pumpWidget(harness());
    await pumpUntilData(tester);
    expect(find.text('Create your first workout'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('a workout card shows its exercise and set counts',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    for (final n in ['Bench Press', 'Overhead Press']) {
      final e = await exercises.create(
          name: n, loggingType: LoggingType.strengthWeightRepsRir);
      await templates.addExercise(templateId: t.id, exerciseId: e.id);
    }

    await tester.pumpWidget(harness());
    await pumpUntilData(tester);

    expect(find.text('Push'), findsOneWidget);
    expect(find.textContaining('2 exercises'), findsOneWidget);
    expect(find.textContaining('6 sets'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('Start is disabled for a template with no exercises',
      (tester) async {
    await TemplateRepository(db).createTemplate(name: 'Empty');

    await tester.pumpWidget(harness());
    await pumpUntilData(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start'),
    );
    expect(button.onPressed, isNull);
    await disposeAndDrainTimers(tester);
  });
}
