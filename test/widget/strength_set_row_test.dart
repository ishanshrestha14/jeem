import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/ui/widgets/strength_set_row.dart';

/// Regression coverage for the RIR-menu dismissal bug: `showMenu` returns
/// `null` both when the user explicitly picks the `—` entry (whose
/// underlying value is itself `null`) and when the menu is dismissed
/// without a selection (tap outside / back). Before the fix, both cases
/// were treated identically and any accidental outside-tap on an already-
/// logged set silently wiped its RIR.
void main() {
  // `setIndex: 0` renders the badge as "1" (`SetBadge` shows `index + 1`)
  // so it can't collide with the RIR value's own text, which the tests
  // below locate by `find.text`.
  SessionSet buildSet({double? rir}) {
    final now = DateTime.now();
    return SessionSet(
      createdAt: now,
      updatedAt: now,
      id: 'set-1',
      sessionExerciseId: 'ex-1',
      setIndex: 0,
      rir: rir,
    );
  }

  Widget harness(SessionSet set, ValueChanged<double?> onRirChanged) {
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
          onRirChanged: onRirChanged,
        ),
      ),
    );
  }

  testWidgets('dismissing the RIR menu leaves the existing RIR unchanged',
      (tester) async {
    var calls = 0;
    final set = buildSet(rir: 1.5);
    await tester.pumpWidget(harness(set, (_) => calls++));

    // Open the menu.
    await tester.tap(find.text('1.5'));
    await tester.pumpAndSettle();

    // Dismiss it by tapping the modal barrier well away from the menu
    // itself, rather than picking an item.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(calls, 0);
    // The row still shows the original value — nothing was cleared.
    expect(find.text('1.5'), findsOneWidget);
  });

  testWidgets('explicitly choosing — clears the RIR', (tester) async {
    double? received = 1.5;
    var calls = 0;
    final set = buildSet(rir: 1.5);
    await tester.pumpWidget(harness(set, (v) {
      calls++;
      received = v;
    }));

    await tester.tap(find.text('1.5'));
    await tester.pumpAndSettle();

    // The `—` entry is the menu item for `kRirValues[0]` (null).
    await tester.tap(find.text('—').last);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(received, isNull);
  });

  testWidgets(
      'every tappable control in the row is at least 48dp tall '
      '(PRD §16.3 / §24.4)', (tester) async {
    // The weight and reps fields are `NumericField(dense: true)`, which
    // deliberately strips all box chrome. With `contentPadding: zero` the
    // resulting `TextField` measured only ~33dp tall — visually fine inside
    // a 56dp row, but its *tappable* area was well under the 48dp floor the
    // PRD sets for every input. This pins the floor for all four controls.
    await tester.pumpWidget(harness(buildSet(rir: 2), (_) {}));

    for (final field in find.byType(TextField).evaluate()) {
      expect((field.renderObject! as RenderBox).size.height,
          greaterThanOrEqualTo(48.0));
    }
    // The RIR control is not a TextField (it's an InkWell + showMenu), so
    // measure the InkWell — the thing that actually takes the tap — rather
    // than the `Text` it centres inside itself.
    expect(
      tester
          .getSize(find.ancestor(
              of: find.text('2'), matching: find.byType(InkWell)))
          .height,
      greaterThanOrEqualTo(48.0),
    );
    expect(tester.getSize(find.byTooltip('Complete set')).height,
        greaterThanOrEqualTo(48.0));
  });
}
