import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/widgets/chart_geometry.dart';

/// T-027 — the arithmetic behind the progress chart, tested without painting
/// anything. This is why the chart is split into a pure layer and a dumb
/// painter: the interesting part is an ordinary `expect`.
void main() {
  group('verticalScale', () {
    test('picks round ticks for a clean range', () {
      final scale = verticalScale([70, 74, 81, 85]);

      expect(scale.step, 5);
      expect(scale.min, 70);
      expect(scale.max, 85);
      expect(scale.ticks, [70, 75, 80, 85]);
    });

    test('picks round ticks for an ugly range', () {
      // The case the algorithm order exists for: the axis must not read
      // 61.2 / 62.1 / 63.0.
      final scale = verticalScale([61.2, 62.4, 63.9]);

      expect(scale.step, 1);
      expect(scale.min, 61);
      expect(scale.max, 64);
      expect(scale.ticks, [61, 62, 63, 64]);
    });

    test('the domain brackets every value', () {
      // The property that keeps a point from being painted outside the plot
      // rect. Asserted directly rather than inferred from the arithmetic.
      for (final values in [
        <double>[70, 74, 81, 85],
        <double>[61.2, 62.4, 63.9],
        <double>[0.5, 99.5],
        <double>[102.5],
        <double>[7, 7, 7],
      ]) {
        final scale = verticalScale(values);
        for (final v in values) {
          expect(v, greaterThanOrEqualTo(scale.min), reason: '$values');
          expect(v, lessThanOrEqualTo(scale.max), reason: '$values');
        }
      }
    });

    test('domain edges are exact multiples of the step', () {
      for (final values in [
        <double>[70, 85],
        <double>[61.2, 63.9],
        <double>[3, 4000],
      ]) {
        final scale = verticalScale(values);
        expect((scale.min / scale.step) % 1, closeTo(0, 1e-9));
        expect((scale.max / scale.step) % 1, closeTo(0, 1e-9));
      }
    });

    test('a flat series still yields a usable domain', () {
      // Three sessions all at 80: the range is zero, so there is no span to
      // divide. Must not produce min == max or divide by zero — a plateau is
      // a real answer and deserves a labelled flat line.
      final scale = verticalScale([80, 80, 80]);

      expect(scale.max, greaterThan(scale.min));
      expect(scale.step, greaterThan(0));
      expect(80, greaterThanOrEqualTo(scale.min));
      expect(80, lessThanOrEqualTo(scale.max));
    });

    test('a single point yields a usable domain', () {
      final scale = verticalScale([102.5]);

      expect(scale.max, greaterThan(scale.min));
      expect(scale.ticks.length, greaterThanOrEqualTo(2));
    });

    test('fractionOf maps the domain onto 0..1', () {
      final scale = verticalScale([70, 85]);

      expect(scale.fractionOf(scale.min), closeTo(0, 1e-9));
      expect(scale.fractionOf(scale.max), closeTo(1, 1e-9));
      expect(scale.fractionOf((scale.min + scale.max) / 2), closeTo(0.5, 1e-9));
    });

    test('an empty series is handled rather than thrown on', () {
      final scale = verticalScale([]);

      expect(scale.max, greaterThan(scale.min));
    });
  });
}
