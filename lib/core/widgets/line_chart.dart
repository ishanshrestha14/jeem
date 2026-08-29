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
      final plot = Rect.fromLTRB(
        LineChart.leftGutter,
        8,
        constraints.maxWidth - 8,
        constraints.maxHeight - LineChart.bottomGutter,
      );
      final labelStyle = theme.textTheme.bodySmall?.copyWith(color: semantic.muted);

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
                valueLabel: valueLabel,
                lineColor: theme.colorScheme.primary,
                gridColor: semantic.line,
                textColor: semantic.muted,
                textStyle: theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12),
              ),
            ),
          ),
          // Every tick labelled — the axis does not start at zero, so the
          // numbers are what carry the scale.
          for (final tick in scale.ticks)
            Positioned(
              left: 0,
              width: LineChart.leftGutter - 6,
              top: plot.bottom - scale.fractionOf(tick) * plot.height - 8,
              child: Text(
                _formatTick(tick),
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
        ],
      );
    });
  }
}

/// Formats a tick value as an integer when it lands on one, else one
/// decimal place. Shared by the widget's labels and the painter.
String _formatTick(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Strokes what it is handed. Makes no decisions: every number it draws was
/// computed by `chart_geometry.dart`, which is tested without rendering.
class LineChartPainter extends CustomPainter {
  LineChartPainter({
    required this.points,
    required this.scale,
    required this.ticks,
    required this.first,
    required this.last,
    required this.valueLabel,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.textStyle,
  });

  final List<({DateTime when, double value})> points;
  final ChartScale scale;
  final List<DateTick> ticks;
  final DateTime first;
  final DateTime last;
  final String valueLabel;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final TextStyle textStyle;

  /// One session is not a trend, and a line through it would imply one.
  bool get drawsLine => points.length >= 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final plot = Rect.fromLTRB(
      LineChart.leftGutter,
      8,
      size.width - 8,
      size.height - LineChart.bottomGutter,
    );
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
      old.points != points ||
      old.scale.min != scale.min ||
      old.scale.max != scale.max ||
      old.lineColor != lineColor;
}
