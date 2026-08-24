import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/theme/semantic_colors.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/ui/widgets/strength_set_row.dart';

/// CMP-015. A pending set row shows the routine's snapshotted plan as muted
/// hint text in the Kg / Reps cells, so the row reads as "here is what you
/// planned" without claiming those numbers were lifted. Once a value is
/// logged, the hint gives way to it.
void main() {
  SessionSet buildSet({
    double? plannedWeight,
    int? plannedReps,
    int? plannedRepsMax,
    double? weight,
    int? reps,
  }) {
    final now = DateTime.now();
    return SessionSet(
      createdAt: now,
      updatedAt: now,
      id: 'set-1',
      sessionExerciseId: 'ex-1',
      setIndex: 0,
      plannedWeight: plannedWeight,
      plannedReps: plannedReps,
      plannedRepsMax: plannedRepsMax,
      weight: weight,
      reps: reps,
    );
  }

  Widget harness(SessionSet set) {
    return MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: StrengthSetRow(
          set: set,
          isCurrent: true,
          weightUnit: 'kg',
          onToggleComplete: () {},
          onWeightChanged: (_) {},
          onRepsChanged: (_) {},
          onRirChanged: (_) {},
        ),
      ),
    );
  }

  /// The hint of the field whose `decoration.hintText` is non-null and whose
  /// label semantics match — read straight off the built `TextField`, since a
  /// hint is not rendered as findable text once a value is present.
  List<String?> hints(WidgetTester tester) => tester
      .widgetList<TextField>(find.byType(TextField))
      .map((f) => f.decoration?.hintText)
      .toList();

  testWidgets('a pending row hints the planned weight and reps',
      (tester) async {
    await tester.pumpWidget(
        harness(buildSet(plannedWeight: 60, plannedReps: 8)));

    expect(hints(tester), ['60', '8']);
  });

  testWidgets('a planned rep range is hinted as a range', (tester) async {
    await tester.pumpWidget(harness(
        buildSet(plannedWeight: 60, plannedReps: 8, plannedRepsMax: 10)));

    expect(hints(tester), ['60', '8-10']);
  });

  testWidgets('a row with no plan hints nothing', (tester) async {
    await tester.pumpWidget(harness(buildSet()));

    expect(hints(tester), [null, null]);
  });

  testWidgets('a logged value is shown instead of its hint', (tester) async {
    await tester.pumpWidget(harness(
        buildSet(plannedWeight: 60, plannedReps: 8, weight: 72.5, reps: 5)));

    expect(find.text('72.5'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('the plan hint is muted, not the logged-value colour',
      (tester) async {
    await tester.pumpWidget(
        harness(buildSet(plannedWeight: 60, plannedReps: 8)));

    final muted = AppTheme.dark().extension<SemanticColors>()!.muted;
    final field = tester.widgetList<TextField>(find.byType(TextField)).first;
    expect(field.decoration?.hintStyle?.color, muted);
  });
}
