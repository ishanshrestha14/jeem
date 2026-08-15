import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/exercises/ui/exercise_editor_screen.dart';
import '../db/test_database.dart';
import 'pump_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  testWidgets(
      'archiving from the editor shows an undo snackbar that actually restores the exercise',
      (tester) async {
    final repo = ExerciseRepository(db);
    final exercise = await repo.create(
      name: 'Plank',
      loggingType: LoggingType.durationOnly,
    );

    // A destination screen sits behind the editor, mirroring the app's real
    // navigation (the editor is pushed on top of the list). This proves the
    // undo snackbar survives the pop back to whatever screen is underneath.
    Widget harness() => ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Destination')),
                body: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ExerciseEditorScreen(exerciseId: exercise.id),
                      ),
                    ),
                    child: const Text('Open editor'),
                  ),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(harness());
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.archive_outlined));
    await tester.pumpAndSettle();

    // Confirm the destructive-action dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    // Back on the destination screen with an undo snackbar.
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Plank archived'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Undo'), findsOneWidget);

    final archived = await repo.findById(exercise.id);
    expect(archived!.isArchived, isTrue);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final restored = await repo.findById(exercise.id);
    expect(restored!.isArchived, isFalse);

    await disposeAndDrainTimers(tester);
  });
}
