import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/theme/semantic_colors.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/ui/widgets/duration_set_row.dart';
import 'package:gymflow/features/sessions/ui/widgets/strength_set_row.dart';

/// CMP-015's last piece: a completed row is washed across its full width, so
/// set state is legible at arm's length.
///
/// S-006 draws that wash green. Ours is **chalk** — the design system's first
/// principle is that colour is scarce and means "live", and completed work
/// fills chalk-white like a tick in a paper log
/// (`docs/design/gymflow-design-system.md`). Asserting the token rather than
/// "some colour" is what makes a green regression fail here.
void main() {
  final semantic = AppTheme.dark().extension<SemanticColors>()!;

  SessionSet buildSet({required bool complete}) {
    final now = DateTime.utc(2026, 8, 24);
    return SessionSet(
      id: 'set-1',
      sessionExerciseId: 'ex-1',
      setIndex: 0,
      completedAt: complete ? now : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget strength({required bool complete, required bool isCurrent}) {
    return MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: StrengthSetRow(
          set: buildSet(complete: complete),
          isCurrent: isCurrent,
          weightUnit: 'kg',
          onToggleComplete: () {},
          onWeightChanged: (_) {},
          onRepsChanged: (_) {},
          onRirChanged: (_) {},
        ),
      ),
    );
  }

  Widget duration({required bool complete, required bool isCurrent}) {
    return MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: DurationSetRow(
          set: buildSet(complete: complete),
          isCurrent: isCurrent,
          onToggleComplete: () {},
          onDurationChanged: (_) {},
        ),
      ),
    );
  }

  /// The row's own background — the `AnimatedContainer` the row wraps itself
  /// in, which is the first one under the row widget.
  Color? background(WidgetTester tester, Type rowType) {
    final container = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.byType(rowType),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    return (container.decoration as BoxDecoration).color;
  }

  testWidgets('a completed strength row is washed chalk', (tester) async {
    await tester.pumpWidget(strength(complete: true, isCurrent: false));

    expect(background(tester, StrengthSetRow), semantic.completedRow);
  });

  testWidgets('a pending strength row has no wash', (tester) async {
    await tester.pumpWidget(strength(complete: false, isCurrent: false));

    expect(background(tester, StrengthSetRow), Colors.transparent);
  });

  testWidgets('the current row keeps surfaceHigh even once complete',
      (tester) async {
    // Completed sets stay editable and can still be the focused row (PRD §17).
    // "Where you are" is the more specific signal, and the filled disc still
    // marks the row done.
    await tester.pumpWidget(strength(complete: true, isCurrent: true));

    expect(background(tester, StrengthSetRow), semantic.surfaceHigh);
  });

  testWidgets('a completed duration row is washed the same way',
      (tester) async {
    await tester.pumpWidget(duration(complete: true, isCurrent: false));

    expect(background(tester, DurationSetRow), semantic.completedRow);
  });

  testWidgets('a pending duration row has no wash', (tester) async {
    await tester.pumpWidget(duration(complete: false, isCurrent: false));

    expect(background(tester, DurationSetRow), Colors.transparent);
  });

  test('the wash is chalk, not green', () {
    // The design system's first principle, pinned: `completedRow` is the
    // `success` chalk at low alpha, and success is itself deliberately not
    // green.
    expect(semantic.completedRow.r, semantic.success.r);
    expect(semantic.completedRow.g, semantic.success.g);
    expect(semantic.completedRow.b, semantic.success.b);
    expect(semantic.completedRow.a, lessThan(0.1),
        reason: 'a wash, not a fill — the numerals must stay the loudest thing');
  });
}
