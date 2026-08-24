import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/theme/semantic_colors.dart';
import 'package:gymflow/features/sessions/domain/previous_best.dart';
import 'package:gymflow/features/sessions/ui/widgets/previous_best_line.dart';

/// S-006's `Previous`, as one line per exercise rather than a per-row column:
/// the value is identical down every row, and our set row already carries a
/// RIR column the reference app moved onto its keypad.
void main() {
  Widget harness({PreviousBest? best, String weightUnit = 'kg'}) {
    return MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: PreviousBestLine(best: best, weightUnit: weightUnit),
      ),
    );
  }

  PreviousBest bestSet({double weight = 60, int reps = 6}) => PreviousBest(
        weight: weight,
        reps: reps,
        when: DateTime.utc(2026, 8, 10),
      );

  testWidgets('reads "Last · 60kg x 6"', (tester) async {
    await tester.pumpWidget(harness(best: bestSet()));

    expect(find.text('Last · 60kg x 6'), findsOneWidget);
  });

  testWidgets('carries the session weight unit', (tester) async {
    await tester.pumpWidget(harness(best: bestSet(), weightUnit: 'lb'));

    expect(find.text('Last · 60lb x 6'), findsOneWidget);
  });

  testWidgets('trims a whole-number weight', (tester) async {
    await tester.pumpWidget(harness(best: bestSet(weight: 62.5)));

    expect(find.text('Last · 62.5kg x 6'), findsOneWidget);
  });

  testWidgets('renders nothing at all without history', (tester) async {
    await tester.pumpWidget(harness(best: null));

    // Not "Last · —": a header line has no column to hold open, so an
    // exercise you have never done simply has no line.
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('is muted, so it never competes with the logged numerals',
      (tester) async {
    await tester.pumpWidget(harness(best: bestSet()));

    final muted = AppTheme.dark().extension<SemanticColors>()!.muted;
    expect(tester.widget<Text>(find.text('Last · 60kg x 6')).style?.color, muted);
  });
}
