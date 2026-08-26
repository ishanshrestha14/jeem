import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/templates/ui/template_exercise_settings_sheet.dart';

void main() {
  testWidgets(
      'a note typed just before the sheet closes is flushed, not discarded',
      (tester) async {
    final config = TemplateExercise(
      id: 'te1',
      templateId: 't1',
      exerciseId: 'e1',
      sortOrder: 0,
      restSeconds: 90,
      notes: null,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      deletedAt: null,
    );

    TemplateExercise? received;
    late BuildContext capturedContext;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Builder(
        builder: (context) {
          capturedContext = context;
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showTemplateExerciseSettings(
                  context,
                  config: config,
                  loggingType: LoggingType.strengthWeightRepsRir,
                  onChanged: (updated) => received = updated,
                ),
                child: const Text('Open settings'),
              ),
            ),
          );
        },
      ),
    ));

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle(); // finite bottom-sheet open animation

    final noteField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Note',
    );
    await tester.enterText(noteField, 'Warm up first');

    // Deliberately do NOT pump out the 300ms debounce. Close the sheet
    // immediately instead — its dispose() must flush the pending note.
    Navigator.of(capturedContext).pop();
    await tester.pump();
    // The bottom sheet's own (bounded, ~200ms) closing animation.
    await tester.pump(const Duration(milliseconds: 250));

    expect(received, isNotNull);
    expect(received!.notes, 'Warm up first');
  });

  testWidgets('Replace exercise is offered, and reports the choice upward',
      (tester) async {
    // The sheet is presentational: it owns no database. "Replace exercise" is
    // an action the routine editor performs, so the sheet's job is to ask for
    // it — the same shape as `onChanged`.
    final config = TemplateExercise(
      id: 'te1',
      templateId: 't1',
      exerciseId: 'e1',
      sortOrder: 0,
      restSeconds: 90,
      notes: null,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      deletedAt: null,
    );

    var replaceRequested = 0;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showTemplateExerciseSettings(
                context,
                config: config,
                loggingType: LoggingType.strengthWeightRepsRir,
                onChanged: (_) {},
                onReplace: () => replaceRequested++,
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(find.text('Replace exercise'), findsOneWidget);
    await tester.tap(find.text('Replace exercise'));
    await tester.pumpAndSettle();

    expect(replaceRequested, 1);
  });

  testWidgets('the action is absent when no handler is given', (tester) async {
    // The sheet opens from more than one place; only the routine editor can
    // replace an exercise, so the row appears only where it works.
    final config = TemplateExercise(
      id: 'te1',
      templateId: 't1',
      exerciseId: 'e1',
      sortOrder: 0,
      restSeconds: 90,
      notes: null,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      deletedAt: null,
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showTemplateExerciseSettings(
                context,
                config: config,
                loggingType: LoggingType.strengthWeightRepsRir,
                onChanged: (_) {},
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(find.text('Replace exercise'), findsNothing);
  });
}
