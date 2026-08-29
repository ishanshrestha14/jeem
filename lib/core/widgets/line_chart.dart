import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/semantic_colors.dart';
import 'chart_geometry.dart';

/// A single-series line chart over time, drawn by hand.
///
/// No charting package: this app needs exactly one chart type, dark-only,
/// inside a design system that already has its own tokens — a dependency's
/// visual language would be something to override rather than use (T-027,
/// Phase B "no new dependencies").
///
/// Deliberately generic over `(when, value)` rather than over the exercises
/// feature's `ProgressPoint`, so it owes nothing to its only caller. It is
/// **not** yet a reusable parameterised component: with one caller, the right
/// abstraction is unknowable. Extract when a second chart appears.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.points,
    required this.valueLabel,
  });

  /// Oldest first.
  final List<({DateTime when, double value})> points;

  /// Unit suffix for the y-axis, e.g. `kg`.
  final String valueLabel;

  /// Shared with [LineChartPainter] so the labels and the plot rect agree.
  static const leftGutter = 44.0;
  static const bottomGutter = 24.0;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final scale = verticalScale([for (final p in points) p.value]);
    final first = points.first.when;
    final last = points.last.when;
    final ticks = dateTicks(first, last);

    return LayoutBuilder(builder: (context, constraints) {
      // An unbounded parent (e.g. a `Column` in a `ScrollView`) hands the
      // rect below `-infinity`/`infinity` edges, which asserts once used as
      // a `Positioned.top`. There is no sane rect to draw in that case.
      if (!constraints.maxWidth.isFinite || !constraints.maxHeight.isFinite) {
        return const SizedBox.shrink();
      }

      final plot = Rect.fromLTRB(
        LineChart.leftGutter,
        8,
        constraints.maxWidth - 8,
        constraints.maxHeight - LineChart.bottomGutter,
      );
      if (plot.width <= 0 || plot.height <= 0) {
        return const SizedBox.shrink();
      }

      final labelStyle = theme.textTheme.bodySmall?.copyWith(color: semantic.muted);
      final topTick = scale.ticks.last;

      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              key: const ValueKey('line-chart-canvas'),
              painter: LineChartPainter(
                points: points,
                scale: scale,
                ticks: ticks,
                first: first,
                last: last,
                plot: plot,
                lineColor: theme.colorScheme.primary,
                gridColor: semantic.line,
              ),
            ),
          ),
          // Every tick labelled — the axis does not start at zero, so the
          // numbers are what carry the scale. The topmost tick also carries
          // the unit, since a bare number carries the scale only partly.
          for (final tick in scale.ticks)
            Positioned(
              left: 0,
              width: LineChart.leftGutter - 6,
              top: plot.bottom - scale.fractionOf(tick) * plot.height - 8,
              child: Text(
                tick == topTick
                    ? '${_formatTick(tick, scale.step)} $valueLabel'
                    : _formatTick(tick, scale.step),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
          for (final tick in ticks)
            Positioned(
              left: plot.left +
                  dateFraction(tick.when, first, last) * plot.width -
                  30,
              width: 60,
              top: plot.bottom + 6,
              child: Text(
                tick.label,
                textAlign: TextAlign.center,
                style: labelStyle,
              ),
            ),
          // The design's *States* section: a single session shows "the dot
          // and its value" — the ticks alone cannot show it precisely.
          if (points.length == 1)
            Positioned(
              left: plot.left +
                  dateFraction(points.single.when, first, last) * plot.width +
                  8,
              top: plot.bottom -
                  scale.fractionOf(points.single.value) * plot.height -
                  20,
              child: Text(
                _formatValue(points.single.value),
                style: labelStyle,
              ),
            ),
        ],
      );
    });
  }
}

/// Formats a tick value with enough decimal places to distinguish it from
/// its neighbours, derived from [step] rather than a hardcoded precision:
/// `verticalScale` can choose a step as fine as 0.025 on a tightly-clustered
/// series, and a fixed one decimal place would round every tick on that
/// chart to the same label — exactly where the labels matter most.
String _formatTick(double v, double step) => v.toStringAsFixed(_decimalsFor(step));

/// Formats a single raw value (not necessarily a multiple of any step),
/// e.g. the sole point's value on a one-session chart: an integer when it
/// lands on one, else one decimal place.
String _formatValue(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// The fewest decimal places that represent [step] exactly, up to 4.
int _decimalsFor(double step) {
  for (var decimals = 0; decimals < 4; decimals++) {
    final scaled = step * math.pow(10, decimals);
    if ((scaled - scaled.roundToDouble()).abs() < 1e-6) return decimals;
  }
  return 4;
}

/// Strokes what it is handed. Makes no decisions: every number it draws was
/// computed by `chart_geometry.dart` or the plot rect `LineChart.build`
/// derived once from its constraints, which is tested without rendering.
/// Draws no text — every label is a real `Text` widget in the `Stack` above
/// this painter, so `find.text` can see it.
class LineChartPainter extends CustomPainter {
  LineChartPainter({
    required this.points,
    required this.scale,
    required this.ticks,
    required this.first,
    required this.last,
    required this.plot,
    required this.lineColor,
    required this.gridColor,
  });

  final List<({DateTime when, double value})> points;
  final ChartScale scale;
  final List<DateTick> ticks;
  final DateTime first;
  final DateTime last;

  /// Computed once by `LineChart.build` from its `LayoutBuilder` constraints
  /// and handed down, so the widget's labels and this painter's canvas can
  /// never disagree about where the plot area is.
  final Rect plot;
  final Color lineColor;
  final Color gridColor;

  /// One session is not a trend, and a line through it would imply one.
  bool get drawsLine => points.length >= 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    if (plot.width <= 0 || plot.height <= 0) return;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Gridlines only. Their **labels are real `Text` widgets** in the Stack
    // above this painter, not canvas text: `find.text` cannot see anything a
    // painter drew, and those labels are the mitigation for the non-zero
    // baseline, so they must be assertable.
    for (final tick in scale.ticks) {
      final y = plot.bottom - scale.fractionOf(tick) * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }

    final offsets = [
      for (final p in points)
        Offset(
          plot.left + dateFraction(p.when, first, last) * plot.width,
          plot.bottom - scale.fractionOf(p.value) * plot.height,
        ),
    ];

    if (drawsLine) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final o in offsets.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final dot = Paint()..color = lineColor;
    for (final o in offsets) {
      canvas.drawCircle(o, 3, dot);
    }
  }

  @override
  bool shouldRepaint(LineChartPainter old) =>
      !listEquals(old.points, points) ||
      old.scale.min != scale.min ||
      old.scale.max != scale.max ||
      old.scale.step != scale.step ||
      !_sameTicks(old.ticks, ticks) ||
      old.first != first ||
      old.last != last ||
      old.plot != plot ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor;
}

bool _sameTicks(List<DateTick> a, List<DateTick> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].when != b[i].when || a[i].label != b[i].label) return false;
  }
  return true;
}
