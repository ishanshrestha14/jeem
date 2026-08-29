import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/widgets/line_chart.dart';

/// T-027 — the chart draws what geometry hands it. The arithmetic is tested
/// in `chart_geometry_test.dart`; these tests cover what renders.
void main() {
  Widget harness(List<({DateTime when, double value})> points) => MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 240,
            child: LineChart(points: points, valueLabel: 'kg'),
          ),
        ),
      );

  ({DateTime when, double value}) p(int dayOffset, double value) =>
      (when: DateTime.utc(2026, 6, 1).add(Duration(days: dayOffset)), value: value);

  testWidgets('labels every y tick with its value', (tester) async {
    await tester.pumpWidget(harness([p(0, 70), p(20, 78), p(40, 85)]));

    // Every tick labelled is the mitigation for the non-zero baseline: the
    // numbers carry the scale, so the shape alone is never the whole claim.
    expect(find.text('70'), findsOneWidget);
    // The topmost tick carries the unit, so the axis reads as `kg`/`lb`
    // rather than bare numbers (T-027 final review, fix 2).
    expect(find.text('85 kg'), findsOneWidget);
  });

  testWidgets('the y-axis carries the unit', (tester) async {
    await tester.pumpWidget(harness([p(0, 70), p(20, 78), p(40, 85)]));

    expect(find.textContaining('kg'), findsOneWidget);
  });

  testWidgets('renders without overflow at a small size', (tester) async {
    await tester.pumpWidget(harness([p(0, 61.2), p(15, 63.9)]));

    expect(tester.takeException(), isNull);
  });

  testWidgets('draws a single point without a line', (tester) async {
    await tester.pumpWidget(harness([p(0, 102.5)]));

    expect(tester.takeException(), isNull);
    // One session is not a trend; a line through it would imply one.
    final painter = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('line-chart-canvas')),
    );
    expect((painter.painter! as LineChartPainter).drawsLine, isFalse);
  });

  testWidgets('a single point shows its value beside the dot', (tester) async {
    await tester.pumpWidget(harness([p(0, 102.5)]));

    // The design's *States* section: one session shows "the dot and its
    // value" — the ticks alone (95/100/105/110) cannot show 102.5.
    expect(find.text('102.5'), findsOneWidget);
  });

  testWidgets('renders inside an unbounded parent without asserting',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                width: 360,
                child: LineChart(
                  points: [p(0, 70), p(20, 78), p(40, 85)],
                  valueLabel: 'kg',
                ),
              ),
            ],
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('draws a line once there are two points', (tester) async {
    await tester.pumpWidget(harness([p(0, 70), p(30, 80)]));

    final painter = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('line-chart-canvas')),
    );
    expect((painter.painter! as LineChartPainter).drawsLine, isTrue);
  });

  testWidgets('a flat series renders a labelled line, not a crash',
      (tester) async {
    await tester.pumpWidget(harness([p(0, 80), p(10, 80), p(20, 80)]));

    expect(tester.takeException(), isNull);
    expect(find.text('80'), findsOneWidget);
  });

  testWidgets('a tiny-span series gets distinct tick labels', (tester) async {
    // A span under ~0.4 makes `verticalScale` choose a step of 0.02 here —
    // the most zoomed-in chart is exactly where a hardcoded 1 decimal place
    // would round every tick to the same "100.1" label.
    await tester.pumpWidget(harness([p(0, 100.10), p(10, 100.15)]));

    // Ticks land on 100.10, 100.12, 100.14, 100.16 (step 0.02) — each must
    // be distinguishable from its neighbour.
    expect(find.text('100.10'), findsOneWidget);
    expect(find.text('100.16 kg'), findsOneWidget);
  });
}
