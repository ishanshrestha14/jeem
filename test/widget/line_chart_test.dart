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
    expect(find.text('85'), findsOneWidget);
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
}
