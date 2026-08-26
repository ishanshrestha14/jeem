import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/widgets/week_dot_strip.dart';

/// CMP-020: the week runs Sunday to Saturday (the owner's week), so "this
/// week" does not shift under you mid-week.
void main() {
  test('the week starts on Sunday, whatever day you ask about', () {
    // 2026-08-20 is a Thursday; its week begins Sunday 2026-08-16.
    expect(WeekDotStrip.startOfWeek(DateTime(2026, 8, 20)),
        DateTime(2026, 8, 16));
    // Asking on the Sunday itself must not jump back a week.
    expect(WeekDotStrip.startOfWeek(DateTime(2026, 8, 16)),
        DateTime(2026, 8, 16));
    // Saturday is the last day of the same week, not the first of the next.
    expect(WeekDotStrip.startOfWeek(DateTime(2026, 8, 22)),
        DateTime(2026, 8, 16));
  });

  testWidgets('renders seven days whether or not anything was trained',
      (tester) async {
    // Semantics are not built in a widget test unless something holds them
    // open, and the trained/untrained state is only exposed there. Disposed
    // inside the body, not via addTearDown: the handle check runs first.
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: WeekDotStrip(trainedDays: const {}, today: DateTime(2026, 8, 20)),
      ),
    ));

    // The strip keeps its shape on an empty week rather than collapsing.
    expect(find.text('S'), findsNWidgets(2));
    expect(find.text('T'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Trained'), findsNothing);
    expect(find.bySemanticsLabel('No workout'), findsNWidgets(7));
    semantics.dispose();
  });

  testWidgets('marks only the days with a completed workout', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: WeekDotStrip(
          today: DateTime(2026, 8, 20),
          trainedDays: {
            // Time of day must not matter — these are calendar days.
            DateTime(2026, 8, 17, 6, 30),
            DateTime(2026, 8, 20, 22, 15),
            // Last week: outside the strip, must not light anything up.
            DateTime(2026, 8, 12),
          },
        ),
      ),
    ));

    expect(find.bySemanticsLabel('Trained'), findsNWidgets(2));
    expect(find.bySemanticsLabel('No workout'), findsNWidgets(5));
    semantics.dispose();
  });
}
