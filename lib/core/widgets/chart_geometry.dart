import 'dart:math' as math;

import 'package:intl/intl.dart';

/// The vertical axis of a chart: a domain snapped to round tick boundaries,
/// and the ticks themselves.
///
/// Pure arithmetic, deliberately. The painter that consumes this makes no
/// decisions, so the part worth testing is testable without rendering
/// anything — no golden tests, which this repo has none of (T-027).
class ChartScale {
  const ChartScale({
    required this.min,
    required this.max,
    required this.step,
  });

  final double min;
  final double max;
  final double step;

  List<double> get ticks {
    final out = <double>[];
    // Counted rather than accumulated, so floating-point drift cannot make
    // the last tick miss `max` by an epsilon and add a spurious one.
    final count = ((max - min) / step).round();
    for (var i = 0; i <= count; i++) {
      out.add(min + step * i);
    }
    return out;
  }

  /// 0.0 at [min], 1.0 at [max].
  double fractionOf(double value) => (value - min) / (max - min);
}

/// The "nice number" step: 1, 2, 2.5 or 5 times a power of ten.
double _niceStep(double span, int targetTicks) {
  final raw = span / targetTicks;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final normalized = raw / magnitude;
  for (final candidate in const [1.0, 2.0, 2.5, 5.0]) {
    if (normalized <= candidate) return magnitude * candidate;
  }
  return magnitude * 10;
}

/// A y-axis for [values], with round ticks that bracket every one of them.
///
/// Order matters: the step is chosen from the **raw** span, then the domain
/// edges are snapped outward to multiples of it. Snapping outward is what
/// guarantees the bracket — the low edge can only move down and the high edge
/// up — so no point can ever be painted outside the plot rect.
///
/// **Deviation from the design doc, recorded in T-027:** the design also
/// called for padding the range 5% before choosing the step. That produced a
/// 65-90 domain for data spanning 70-85 — 40% of the height empty — and
/// contradicted the two worked examples the design itself gives. Snapping
/// outward already keeps the extremes off the frame in every case but an
/// exact boundary hit, which reads correctly.
///
/// The domain is **not** anchored at zero. Zero-basing an estimated-1RM chart
/// spends most of its height on empty space and flattens the very change the
/// pane exists to show. The mitigation is that every tick is labelled, so the
/// numbers carry the scale and the shape alone is never the whole claim.
ChartScale verticalScale(List<double> values, {int targetTicks = 4}) {
  if (values.isEmpty) return const ChartScale(min: 0, max: 1, step: 0.5);

  var lo = values.reduce(math.min);
  var hi = values.reduce(math.max);

  // A flat series (or a single point) has no span to divide. Widen it around
  // the value so a plateau draws as a labelled flat line rather than dividing
  // by zero.
  if (hi - lo < 1e-9) {
    final spread = lo.abs() < 1e-9 ? 1.0 : lo.abs() * 0.05;
    lo -= spread;
    hi += spread;
  }

  final step = _niceStep(hi - lo, targetTicks);
  return ChartScale(
    min: (lo / step).floor() * step,
    max: (hi / step).ceil() * step,
    step: step,
  );
}

/// One labelled position on the time axis.
class DateTick {
  const DateTick({required this.when, required this.label});

  final DateTime when;
  final String label;
}

/// Where [when] sits between [first] and [last], as 0..1.
///
/// A single-date domain has no span, so everything sits at the left edge
/// rather than dividing by zero.
double dateFraction(DateTime when, DateTime first, DateTime last) {
  final span = last.difference(first).inSeconds;
  if (span <= 0) return 0;
  return when.difference(first).inSeconds / span;
}

/// Labels for the time axis, on **period boundaries** rather than on the
/// session dates themselves.
///
/// Labelling the data would bunch labels wherever training was dense, which is
/// exactly where the axis needs to stay readable. Granularity comes from the
/// span, targeting 3-5 labels:
///
/// | Span | Granularity | Example |
/// |---|---|---|
/// | < 8 weeks | weekly | `4 Aug` |
/// | 8 weeks - 2 years | monthly | `Aug` |
/// | > 2 years | quarterly | `Aug 26` |
///
/// The year is appended whenever the domain crosses one, at any granularity,
/// so `Dec` and `Jan` can never be read as the same year.
List<DateTick> dateTicks(DateTime first, DateTime last) {
  final days = last.difference(first).inDays;
  final crossesYear = first.year != last.year;

  if (days <= 0) {
    return [
      DateTick(when: first, label: DateFormat(crossesYear ? 'd MMM yy' : 'd MMM').format(first)),
    ];
  }

  if (days < 56) {
    // Weekly, stepped so 3-5 labels result.
    final everyNWeeks = math.max(1, (days / 7 / 4).ceil());
    final format = DateFormat(crossesYear ? 'd MMM yy' : 'd MMM');
    final out = <DateTick>[];
    // Start at the first midnight at or after `first`, so ticks are stable
    // positions rather than offsets from an arbitrary timestamp.
    var cursor = DateTime(first.year, first.month, first.day);
    if (cursor.isBefore(first)) cursor = cursor.add(const Duration(days: 1));
    while (!cursor.isAfter(last)) {
      out.add(DateTick(when: cursor, label: format.format(cursor)));
      cursor = cursor.add(Duration(days: 7 * everyNWeeks));
    }
    return out;
  }

  final months = (days / 30.44).round();
  final quarterly = days > 730;
  final stepMonths = quarterly
      ? math.max(3, ((months / 4).ceil() ~/ 3) * 3)
      : math.max(1, (months / 4).ceil());
  final format = DateFormat(crossesYear || quarterly ? 'MMM yy' : 'MMM');

  final out = <DateTick>[];
  // First month boundary at or after `first`.
  var cursor = DateTime(first.year, first.month, 1);
  if (cursor.isBefore(first)) {
    cursor = DateTime(first.year, first.month + 1, 1);
  }
  while (!cursor.isAfter(last)) {
    out.add(DateTick(when: cursor, label: format.format(cursor)));
    cursor = DateTime(cursor.year, cursor.month + stepMonths, 1);
  }
  return out;
}
