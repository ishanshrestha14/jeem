# T-027 — Progress chart (CMP-019) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add S-025's fourth pane — a line chart of estimated 1RM over time for one exercise, drawn by hand with no charting dependency.

**Architecture:** Three layers, each independently testable. A pure domain function turns exercise history into `(date, value)` points. A pure geometry module turns points plus a rect into tick values and pixel offsets. A dumb `CustomPainter` strokes what geometry hands it. The pane wires them to the existing `historyProvider`.

**Tech Stack:** Dart 3.11, Flutter, Riverpod v2 (hand-written providers, **no codegen**), Drift, `intl` (already a dependency). No charting package.

**Spec:** `docs/superpowers/specs/2026-08-27-progress-chart-design.md` — read it first, especially "What it shows", "How it is drawn", "The x-axis" and "States". This plan implements the whole of it except the T-026 section, which already shipped.

## Global Constraints

- **No new dependencies.** Phase B rule, `docs/README.md` §4b. `fl_chart` was explicitly rejected in the design; do not add it or any other charting package.
- **No schema change.** `schemaVersion` stays **6**. This feature is entirely derived from existing data.
- **Riverpod v2, hand-written providers.** `riverpod_annotation` / `riverpod_generator` are NOT dependencies. Never write `@riverpod`.
- **No golden tests.** The repo has none. Geometry is tested as pure arithmetic; the pane is tested for which state renders.
- **Round for display, never for storage or comparison** (ADR-004).
- **Weights are converted to the display unit before comparison** (T-026). Use `convertWeight` from `lib/core/utils/weight_units.dart`.
- **Never `await` a Drift stream's `.first` inside a `testWidgets` body** — it wedges the runner rather than failing (`docs/README.md` §7).
- **Every widget test that pumps a Drift-backed provider must end with `disposeAndDrainTimers`**, or drift's cleanup timer is left pending and the file wedges. A red run looks like a hang: read the **head** of the log, not the tail.
- **`flutter test` runs as `TargetPlatform.android`.** If you write a test whose behaviour is platform-dependent, override `debugDefaultTargetPlatformOverride` inside the test body and clear it before the body ends (see `test/widget/session_keypad_focus_test.dart`, T-028).
- Commit messages: **no `Co-Authored-By` and no `Generated with` trailers.**
- Every change gets a ticket in `docs/tickets/`; specs are the source of truth; deviations get recorded, not made silently (`docs/README.md` §2, §3).

## Recorded deviation from the spec — read before Task 2

The spec's geometry section says: pad the observed range by 5% each side, **then** choose the tick step from the padded span, then snap outward to tick boundaries.

**That pre-padding step is dropped.** It contradicts the spec's own worked examples, and I verified the arithmetic both ways:

| Data | With 5% pad | Without pad | Spec says |
|---|---|---|---|
| 70–85 | 65–90, step 5 | **70–85, step 5** | "the axis reads 70 / 75 / 80 / 85" |
| 61.2–63.9 | 61–65, step 1 | **61–64, step 1** | "61 / 62 / 63 / 64 at step 1" |

Padding produces 65–90 for data spanning 70–85 — 40% of the plot height empty — and disagrees with both examples the spec states. Snapping outward to round tick boundaries already keeps the extremes off the frame in every case except when a value lands exactly on a boundary, which reads correctly.

**So: choose the step from the raw span, then snap outward.** Task 6 records this in the design doc.

---

### Task 1: `exerciseProgress` — history to points

**Files:**
- Create: `lib/features/exercises/domain/exercise_progress.dart`
- Create: `test/features/exercise_progress_test.dart`
- Create: `docs/tickets/T-027-progress-chart.md`

**Interfaces:**
- Consumes: `exerciseHistory(...)` → `List<ExerciseHistoryEntry>` (existing, in `lib/features/exercises/domain/exercise_history.dart`). Each entry has `DateTime when`, `String sessionName`, `String weightUnit`, `List<SessionSet> sets`. `convertWeight(value, {from, to})` from `lib/core/utils/weight_units.dart`. `estimatedOneRepMax(weight, reps)` from `lib/features/records/data/personal_records.dart`.
- Produces: `class ProgressPoint { final DateTime when; final double value; }` and `List<ProgressPoint> exerciseProgress(List<ExerciseHistoryEntry> history, {required String displayUnit})`, returned **oldest first** (the chart draws left to right; `exerciseHistory` is newest first, so this reverses).

- [ ] **Step 1: Write the failing test**

Create `test/features/exercise_progress_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/domain/exercise_history.dart';
import 'package:gymflow/features/exercises/domain/exercise_progress.dart';

/// T-027 — one point per session: the best estimated 1RM logged that day.
void main() {
  var seq = 0;
  final base = DateTime.utc(2026, 6, 1);

  SessionSet set({double? weight, int? reps}) {
    final now = DateTime.utc(2026, 6, 1);
    return SessionSet(
      id: 'set-${seq++}',
      sessionExerciseId: 'se-1',
      setIndex: 0,
      weight: weight,
      reps: reps,
      rir: null,
      durationSeconds: null,
      completedAt: now,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  ExerciseHistoryEntry entry({
    required int dayOffset,
    required List<SessionSet> sets,
    String unit = 'kg',
  }) =>
      ExerciseHistoryEntry(
        when: base.add(Duration(days: dayOffset)),
        sessionName: 'Session',
        weightUnit: unit,
        sets: sets,
      );

  test('takes the best estimated 1RM of each session', () {
    // 70x5 estimates higher than 60x8 under Epley capped at 12.
    final points = exerciseProgress([
      entry(dayOffset: 0, sets: [set(weight: 60, reps: 8), set(weight: 70, reps: 5)]),
    ], displayUnit: 'kg');

    expect(points, hasLength(1));
    expect(points.single.value, closeTo(70 * (1 + 5 / 30), 1e-9));
  });

  test('returns points oldest first, whatever order history arrives in', () {
    // `exerciseHistory` is newest first; the chart draws left to right.
    final points = exerciseProgress([
      entry(dayOffset: 10, sets: [set(weight: 80, reps: 5)]),
      entry(dayOffset: 0, sets: [set(weight: 70, reps: 5)]),
    ], displayUnit: 'kg');

    expect(points.map((p) => p.when).toList(),
        [base, base.add(const Duration(days: 10))]);
  });

  test('converts each session from its own unit', () {
    // 135 lb = 61.23 kg; e1RM at 5 reps = x(1 + 5/30).
    final points = exerciseProgress([
      entry(dayOffset: 0, unit: 'lb', sets: [set(weight: 135, reps: 5)]),
    ], displayUnit: 'kg');

    expect(points.single.value, closeTo(61.2349 * (1 + 5 / 30), 1e-3));
  });

  test('skips sets with no weight, no reps, or zero weight', () {
    // A zero weight is bodyweight work, not a lift — an e1RM of 0 would drag
    // the whole y-domain to zero.
    final points = exerciseProgress([
      entry(dayOffset: 0, sets: [
        set(weight: null, reps: 8),
        set(weight: 60, reps: null),
        set(weight: 0, reps: 20),
        set(weight: 50, reps: 5),
      ]),
    ], displayUnit: 'kg');

    expect(points.single.value, closeTo(50 * (1 + 5 / 30), 1e-9));
  });

  test('a session with nothing usable yields no point at all', () {
    final points = exerciseProgress([
      entry(dayOffset: 0, sets: [set(weight: 0, reps: 20)]),
    ], displayUnit: 'kg');

    expect(points, isEmpty, reason: 'no point beats a point at zero');
  });

  test('caps reps at 12, so a 20-rep set scores as a 12-rep one', () {
    // Inherited from ADR-004's cap. Documented consequence: progress made by
    // adding reps beyond 12 does not move the line.
    final twenty = exerciseProgress([
      entry(dayOffset: 0, sets: [set(weight: 40, reps: 20)]),
    ], displayUnit: 'kg').single.value;
    final twelve = exerciseProgress([
      entry(dayOffset: 0, sets: [set(weight: 40, reps: 12)]),
    ], displayUnit: 'kg').single.value;

    expect(twenty, closeTo(twelve, 1e-9));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/exercise_progress_test.dart`
Expected: FAIL — `Error when reading 'lib/features/exercises/domain/exercise_progress.dart': No such file or directory`

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/exercises/domain/exercise_progress.dart`:

```dart
import '../../../core/utils/weight_units.dart';
import '../../records/data/personal_records.dart';
import 'exercise_history.dart';

/// One session's showing on the progress chart (T-027, S-025's fourth pane).
class ProgressPoint {
  const ProgressPoint({required this.when, required this.value});

  final DateTime when;

  /// Best estimated 1RM logged that session, in the display unit.
  final double value;
}

/// One point per session: the best estimated 1RM across the sets logged that
/// day, oldest first.
///
/// The session's *best* set represents it, not an average — the same
/// convention `Previous` (T-009) and Records (ADR-004) already use, so
/// "better lift" means one thing across the app.
///
/// Sets with no weight, no reps, or a zero weight contribute nothing: a
/// zero-weight set is bodyweight work, and an e1RM of zero is not a lift —
/// plotted, one would drag the whole y-domain to zero and flatten every real
/// point above it. A session where nothing qualifies yields no point rather
/// than a point at zero.
///
/// Reps are capped at 12 by [estimatedOneRepMax] (ADR-004). The documented
/// consequence: progress made purely by adding reps beyond 12 does not move
/// the line.
List<ProgressPoint> exerciseProgress(
  List<ExerciseHistoryEntry> history, {
  required String displayUnit,
}) {
  final points = <ProgressPoint>[];

  for (final entry in history) {
    var best = 0.0;
    for (final set in entry.sets) {
      final logged = set.weight;
      final reps = set.reps;
      if (logged == null || reps == null || reps <= 0) continue;
      final weight = convertWeight(
        logged,
        from: entry.weightUnit,
        to: displayUnit,
      );
      if (weight <= 0) continue;
      final score = estimatedOneRepMax(weight, reps);
      if (score > best) best = score;
    }
    if (best > 0) points.add(ProgressPoint(when: entry.when, value: best));
  }

  // `exerciseHistory` is newest first; the chart reads left to right.
  points.sort((a, b) => a.when.compareTo(b.when));
  return points;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/exercise_progress_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Write the ticket**

Create `docs/tickets/T-027-progress-chart.md`:

```markdown
# T-027 — Progress chart: estimated 1RM over time (CMP-019)

- **Status:** In progress
- **Priority:** Should
- **Effort:** L
- **Specs:** S-025, CMP-019, ADR-004, [design](../superpowers/specs/2026-08-27-progress-chart-design.md)
- **Last updated:** 2026-08-29

## Goal

S-025's fourth pane. [T-018](T-018-exercise-detail.md) built About · History · Records and stopped
there because charting was new to this codebase. This adds Progress: one line, one point per
session, the best estimated 1RM you hit that day.

## Scope (in)

- `exerciseProgress` — history to points, in the display unit.
- A pure chart-geometry module: y-domain, round ticks, x-axis labels, point mapping.
- A hand-rolled `CustomPainter` line chart. **No charting dependency.**
- The Progress tab on S-025, absent for duration-logged exercises.

## Scope (out)

- **`fl_chart` or any charting package** — explicitly rejected in the design.
- Touch tooltips or point selection.
- The other three ADR-004 metrics as switchable series.
- A range selector (3m / 6m / all).
- Any second chart elsewhere in the app.

## Model / DB changes

**None.** `schemaVersion` stays 6. Every input already exists.

## Acceptance criteria

- [ ] The Progress tab charts one point per session, oldest left.
- [ ] Axis ticks are round numbers and bracket every point.
- [ ] A gap in training shows as horizontal distance, since points sit at real dates.
- [ ] One session draws a dot and no line; no sessions shows the empty state.
- [ ] A duration-logged exercise has no Progress tab.
- [ ] `flutter analyze` clean; full suite green.

## QA checklist

- [ ] Open a well-trained exercise — the line reads left to right and the axis labels are round.
- [ ] Open one performed once — a single dot, no line.
- [ ] Open one never performed — empty state, no chart.
- [ ] Open a stretch (duration-logged) — no Progress tab at all.

## Revision log

- 2026-08-29 — created from the approved design.
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/exercises/domain/exercise_progress.dart test/features/exercise_progress_test.dart docs/tickets/T-027-progress-chart.md
git commit -m "feat(progress): turn exercise history into chart points (T-027)

One point per session: the best estimated 1RM logged that day, in the
display unit. A zero-weight set is bodyweight work and contributes
nothing — an e1RM of zero would drag the y-domain to zero."
```

---

### Task 2: Chart geometry — the y-domain and its ticks

**Files:**
- Create: `lib/core/widgets/chart_geometry.dart`
- Create: `test/features/chart_geometry_test.dart`

**Interfaces:**
- Consumes: nothing (pure Dart, no Flutter import beyond `dart:math`).
- Produces:
  ```dart
  class ChartScale {
    final double min;   // snapped domain minimum
    final double max;   // snapped domain maximum
    final double step;  // tick interval
    List<double> get ticks;      // min, min+step, ... max
    double fractionOf(double value); // 0.0 at min, 1.0 at max
  }
  ChartScale verticalScale(List<double> values, {int targetTicks = 4});
  ```

- [ ] **Step 1: Write the failing test**

Create `test/features/chart_geometry_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/chart_geometry_test.dart`
Expected: FAIL — `Error when reading 'lib/core/widgets/chart_geometry.dart': No such file or directory`

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/widgets/chart_geometry.dart`:

```dart
import 'dart:math' as math;

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/chart_geometry_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/chart_geometry.dart test/features/chart_geometry_test.dart
git commit -m "feat(chart): y-axis domain and round ticks (T-027)

Step chosen from the raw span, then the edges snapped outward to
multiples of it — snapping outward is what guarantees the domain
brackets every point.

Drops the design's 5% pre-padding, which produced a 65-90 domain for
data spanning 70-85 and contradicted the design's own worked examples."
```

---

### Task 3: Chart geometry — x-axis labels

**Files:**
- Modify: `lib/core/widgets/chart_geometry.dart`
- Modify: `test/features/chart_geometry_test.dart`

**Interfaces:**
- Consumes: `ChartScale` (Task 2), `package:intl/intl.dart` (already a dependency).
- Produces:
  ```dart
  class DateTick { final DateTime when; final String label; }
  List<DateTick> dateTicks(DateTime first, DateTime last);
  double dateFraction(DateTime when, DateTime first, DateTime last);
  ```

- [ ] **Step 1: Write the failing test**

Append to `test/features/chart_geometry_test.dart`, inside `main()`:

```dart
  group('dateTicks', () {
    test('labels a short span by day', () {
      // Under 8 weeks: `4 Aug`.
      final ticks = dateTicks(
        DateTime.utc(2026, 7, 6),
        DateTime.utc(2026, 8, 10),
      );

      expect(ticks.length, inInclusiveRange(3, 5));
      expect(ticks.first.label, matches(RegExp(r'^\d{1,2} [A-Z][a-z]{2}$')));
    });

    test('labels a medium span by month', () {
      // 8 weeks to 2 years, inside one calendar year: `Aug`.
      final ticks = dateTicks(
        DateTime.utc(2026, 2, 1),
        DateTime.utc(2026, 11, 1),
      );

      expect(ticks.length, inInclusiveRange(3, 5));
      expect(ticks.first.label, matches(RegExp(r'^[A-Z][a-z]{2}$')));
    });

    test('appends the year when the span crosses one', () {
      // Dec and Jan must never read as the same year.
      final ticks = dateTicks(
        DateTime.utc(2025, 10, 1),
        DateTime.utc(2026, 6, 1),
      );

      expect(ticks.every((t) => RegExp(r'\d{2}$').hasMatch(t.label)), isTrue,
          reason: 'every label carries a year once the domain crosses one');
    });

    test('ticks land on period boundaries, not on the data dates', () {
      // Labelling session dates would bunch labels wherever training was
      // dense, which is exactly where the axis must stay readable.
      final ticks = dateTicks(
        DateTime.utc(2026, 2, 17),
        DateTime.utc(2026, 11, 3),
      );

      expect(ticks.every((t) => t.when.day == 1), isTrue);
    });

    test('a single date yields exactly one tick', () {
      final day = DateTime.utc(2026, 8, 4);
      final ticks = dateTicks(day, day);

      expect(ticks, hasLength(1));
      expect(ticks.single.when, day);
    });
  });

  group('dateFraction', () {
    test('maps the span onto 0..1', () {
      final first = DateTime.utc(2026, 1, 1);
      final last = DateTime.utc(2026, 1, 11);

      expect(dateFraction(first, first, last), closeTo(0, 1e-9));
      expect(dateFraction(last, first, last), closeTo(1, 1e-9));
      expect(dateFraction(DateTime.utc(2026, 1, 6), first, last),
          closeTo(0.5, 1e-9));
    });

    test('a single date sits at the left edge rather than dividing by zero',
        () {
      final day = DateTime.utc(2026, 8, 4);

      expect(dateFraction(day, day, day), 0);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/chart_geometry_test.dart`
Expected: FAIL — `Method not found: 'dateTicks'`.

- [ ] **Step 3: Write minimal implementation**

Append to `lib/core/widgets/chart_geometry.dart`:

```dart
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
    var cursor = DateTime.utc(first.year, first.month, first.day);
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
  var cursor = DateTime.utc(first.year, first.month, 1);
  if (cursor.isBefore(first)) {
    cursor = DateTime.utc(first.year, first.month + 1, 1);
  }
  while (!cursor.isAfter(last)) {
    out.add(DateTick(when: cursor, label: format.format(cursor)));
    cursor = DateTime.utc(cursor.year, cursor.month + stepMonths, 1);
  }
  return out;
}
```

Add `import 'package:intl/intl.dart';` to the top of the file.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/chart_geometry_test.dart`
Expected: PASS, 15 tests. If a label-count assertion fails, adjust the **step arithmetic** to land in 3-5 — do not loosen the test's range, which is the requirement.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/chart_geometry.dart test/features/chart_geometry_test.dart
git commit -m "feat(chart): time-axis ticks on period boundaries (T-027)

Granularity by span, 3-5 labels, and the year appended whenever the
domain crosses one so Dec and Jan cannot read as the same year.

Ticks land on period boundaries rather than session dates: labelling
the data would bunch labels wherever training was dense."
```

---

### Task 4: The line chart widget

**Files:**
- Create: `lib/core/widgets/line_chart.dart`
- Create: `test/widget/line_chart_test.dart`

**Interfaces:**
- Consumes: `ChartScale`, `verticalScale`, `DateTick`, `dateTicks`, `dateFraction` (Tasks 2-3); `ProgressPoint` is **not** used here — the chart takes plain `(DateTime, double)` pairs so it stays independent of the exercises feature.
- Produces: `class LineChart extends StatelessWidget { const LineChart({super.key, required this.points, required this.valueLabel}); final List<({DateTime when, double value})> points; final String valueLabel; }`

- [ ] **Step 1: Write the failing test**

Create `test/widget/line_chart_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/line_chart_test.dart`
Expected: FAIL — `Error when reading 'lib/core/widgets/line_chart.dart': No such file or directory`

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/widgets/line_chart.dart`:

```dart
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final scale = verticalScale([for (final p in points) p.value]);
    final first = points.isEmpty ? DateTime.now() : points.first.when;
    final last = points.isEmpty ? DateTime.now() : points.last.when;

    return CustomPaint(
      key: const ValueKey('line-chart-canvas'),
      painter: LineChartPainter(
        points: points,
        scale: scale,
        ticks: points.isEmpty ? const [] : dateTicks(first, last),
        first: first,
        last: last,
        valueLabel: valueLabel,
        lineColor: theme.colorScheme.primary,
        gridColor: semantic.line,
        textColor: semantic.muted,
        textStyle: theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12),
      ),
      size: Size.infinite,
    );
  }
}

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

  static const _leftGutter = 44.0;
  static const _bottomGutter = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final plot = Rect.fromLTRB(
      _leftGutter,
      8,
      size.width - 8,
      size.height - _bottomGutter,
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

  String _formatTick(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  bool shouldRepaint(LineChartPainter old) =>
      old.points != points ||
      old.scale.min != scale.min ||
      old.scale.max != scale.max ||
      old.lineColor != lineColor;
}
```

The gutter constants must be shared by both layers, so declare them once on `LineChart` and have the painter read them:

```dart
class LineChart extends StatelessWidget {
  /// Shared with [LineChartPainter] so the labels and the plot rect agree.
  static const leftGutter = 44.0;
  static const bottomGutter = 24.0;
```

and in the painter, replace the two private constants with `LineChart.leftGutter` / `LineChart.bottomGutter`.

Then `LineChart.build` returns a `Stack` — the painter underneath, real `Text` widgets on top:

```dart
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
              painter: LineChartPainter(/* as above */),
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
          for (final tick in dateTicks(first, last))
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
```

Move `_formatTick` to a top-level private function in the file so both the widget and the painter can use it. Guard the whole build with `if (points.isEmpty) return const SizedBox.shrink();` before computing the rect — Task 5's pane renders the empty state instead, so an empty chart is never asked for, but a zero-size rect would still throw.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/line_chart_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/line_chart.dart test/widget/line_chart_test.dart
git commit -m "feat(chart): hand-rolled line chart widget (T-027)

No charting dependency: one chart type, dark-only, in a design system
that already has its own tokens. The painter makes no decisions — every
number it draws came from chart_geometry, which is tested without
rendering.

A single point draws a dot and no line: one session is not a trend."
```

---

### Task 5: The Progress pane on S-025

**Files:**
- Modify: `lib/features/exercises/ui/exercise_detail_screen.dart`
- Create: `test/widget/exercise_progress_pane_test.dart`

**Interfaces:**
- Consumes: `exerciseProgress` (Task 1), `LineChart` (Task 4), `historyProvider`, `settingsProvider`.
- Produces: nothing further.

- [ ] **Step 1: Write the failing test**

Create `test/widget/exercise_progress_pane_test.dart`. The harness below is lifted from
`test/widget/exercise_detail_test.dart` — read that file too, and keep the two consistent.

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/widgets/line_chart.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/exercises/ui/exercise_detail_screen.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/test_database.dart';
import 'pump_helpers.dart';

/// T-027 — S-025's fourth pane, deferred by T-018 because charting was new to
/// this codebase.
void main() {
  late AppDatabase db;

  setUp(() {
    db = testDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => db.close());

  Widget harness(String id) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: ExerciseDetailScreen(exerciseId: id),
        ),
      );

  Future<String> anExercise({
    String name = 'Bench Press',
    LoggingType loggingType = LoggingType.strengthWeightRepsRir,
  }) async {
    final e = await ExerciseRepository(db).create(
      name: name,
      loggingType: loggingType,
      description: 'Press the bar.',
    );
    return e.id;
  }

  /// One finished session logging [weight] x 5 of [exerciseId].
  Future<void> aLoggedSession(String exerciseId, {double weight = 100}) async {
    final templates = TemplateRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Push A');
    await templates.addExercise(
        templateId: t.id, exerciseId: exerciseId, targetSets: 1);
    final s = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    final set = (await db.select(db.sessionSets).get()).last;
    await sessions.updateSet(set.copyWith(
      weight: Value(weight),
      reps: const Value(5),
      completedAt: Value(DateTime.now()),
    ));
    await sessions.finishSession(s.id);
  }

  testWidgets('a strength exercise has a Progress tab', (tester) async {
    final id = await anExercise();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Press the bar.'));

    expect(find.text('Progress'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('a duration-logged exercise has no Progress tab', (tester) async {
    // An estimated 1RM for a plank is meaningless, and ADR-004 already gives
    // duration work no records at all.
    final id = await anExercise(
      name: 'Plank',
      loggingType: LoggingType.durationOnly,
    );

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Press the bar.'));

    expect(find.text('Progress'), findsNothing);
    expect(find.text('Records'), findsOneWidget,
        reason: 'the other three panes are unaffected');
    await disposeAndDrainTimers(tester);
  });

  testWidgets('an exercise never performed shows the empty state, not a chart',
      (tester) async {
    final id = await anExercise();

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Press the bar.'));
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('No progress yet'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('a performed exercise charts its sessions', (tester) async {
    final id = await anExercise();
    await aLoggedSession(id, weight: 90);
    await aLoggedSession(id, weight: 100);

    await tester.pumpWidget(harness(id));
    await pumpUntilData(tester, until: find.text('Press the bar.'));
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('No progress yet'), findsNothing);
    await disposeAndDrainTimers(tester);
  });
}
```

**If `disposeAndDrainTimers` takes a `container:` argument in this file's harness shape, match
whatever `exercise_detail_test.dart` does** — that file uses a plain `ProviderScope`, so the no-arg
form is what applies here. Getting it wrong wedges the file rather than failing it: read the head of
the log, not the tail.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/exercise_progress_pane_test.dart`
Expected: FAIL — no `Progress` tab exists yet.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/exercises/ui/exercise_detail_screen.dart`:

1. The tab count and tabs become conditional on the logging type:

```dart
        // A plank has no estimated 1RM, and ADR-004 already gives duration
        // work no records — so the pane is absent rather than empty (T-027).
        final showsProgress =
            exercise.loggingType != LoggingType.durationOnly;
        return DefaultTabController(
          length: showsProgress ? 4 : 3,
```

with `Tab(text: 'Progress')` inserted after `History` when `showsProgress`, and `_ProgressPane(exercise: exercise)` in the matching `TabBarView` position. Build both lists with a collection `if` so the tab strip and the view can never drift apart.

2. Add the pane:

```dart
class _ProgressPane extends ConsumerWidget {
  const _ProgressPane({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historyProvider).valueOrNull ?? const [];
    final unit = ref.watch(settingsProvider).weightUnit;
    final points = exerciseProgress(
      exerciseHistory(sessions, exerciseKey: exercise.id),
      displayUnit: unit,
    );

    if (points.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'No progress yet',
        message: 'Log this exercise in a workout and its estimated 1RM will '
            'chart here.',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 16, 16),
      child: LineChart(
        points: [for (final p in points) (when: p.when, value: p.value)],
        valueLabel: unit,
      ),
    );
  }
}
```

Add the imports for `exercise_progress.dart`, `line_chart.dart`, `settings_providers.dart` and `empty_state.dart` as needed — check which are already imported before adding.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/exercise_progress_pane_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Run the full suite**

Run: `flutter test && flutter analyze`
Expected: all green, analyze clean. `test/widget/exercise_detail_test.dart` may assert a tab count or tab list — update it to expect four tabs for a strength exercise. That is the correct fix; do not weaken its other assertions.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(exercises): the Progress pane on the exercise detail (T-027)

S-025's fourth pane, deferred by T-018 because charting was new to this
codebase. Estimated 1RM per session at its real date, so a layoff shows
as horizontal distance.

Absent entirely for duration-logged exercises: an e1RM for a plank is
meaningless, and ADR-004 already gives duration work no records."
```

---

### Task 6: Close the ticket and record the decisions

**Files:**
- Modify: `docs/specs/screens/S-025-reference-exercise-detail.md`
- Modify: `docs/superpowers/specs/2026-08-27-progress-chart-design.md`
- Modify: `docs/tickets/T-027-progress-chart.md`
- Modify: `docs/README.md`

- [ ] **Step 1: Update S-025**

Add a dated revision-log line for 2026-08-29 recording that the Progress pane is built as T-027, that it is **our design rather than the reference's** (the reference's Progress pane was never screenshotted — the spec still marks it `UNVERIFIED`), and that the pane is absent for duration-logged exercises. Update the pane's description in the body from "UNVERIFIED — not captured" to what we built, keeping the note that the reference's version was never seen.

- [ ] **Step 2: Record the geometry deviation in the design doc**

Append to `docs/superpowers/specs/2026-08-27-progress-chart-design.md`'s revision log, dated 2026-08-29:

```markdown
- 2026-08-29 — built as [T-027](../../tickets/T-027-progress-chart.md). **One deviation:** the
  geometry section called for padding the observed range 5% before choosing the tick step. That was
  dropped — it produced a 65-90 domain for data spanning 70-85 (40% of the height empty) and
  contradicted the two worked examples this document itself gives (`70 / 75 / 80 / 85`, and
  `61 / 62 / 63 / 64` for the ugly range). Both are reproduced exactly by choosing the step from the
  raw span and snapping outward, which is what shipped.
```

- [ ] **Step 3: Close the ticket**

Set `Status: **Done** (2026-08-29)` with the real test count from the suite run, tick the acceptance criteria the tests cover, and add a revision-log entry noting the geometry deviation.

**Leave the four QA checklist boxes unticked** — they need a device or macOS run, and ticking them from a green suite would be a false claim (`docs/README.md` §6).

- [ ] **Step 4: Update the README**

- Add the T-027 row to the ticket registry: `| [T-027](tickets/T-027-progress-chart.md) | Progress chart: estimated 1RM over time | **Done** | L | S-025, CMP-019, ADR-004 |`
- Remove the "T-027 is reserved" note added by T-028, now that it is spent.
- Move **CMP-019** from `Candidate` to `**Built** — [T-027](tickets/T-027-progress-chart.md)` in the components table.
- Update S-025's row and the §7 status counts.
- Rewrite §7's "Next step" list: items 1 (S-030 stats) and 4 (the chart) are now done. What remains is item 2 (S-003's Insights row / streak) and item 3 (the remaining flows: build/edit a routine, exercise info, programs).

- [ ] **Step 5: Verify**

Run: `flutter test && flutter analyze`
Expected: green and clean — this task changes no code. Record the real count in the ticket; do not guess it.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "docs: close T-027 and record the geometry deviation

The design's 5% pre-padding was dropped: it contradicted the design's
own worked examples and wasted 40% of the plot height."
```

---

## Notes for whoever executes this

**The three layers exist so the hard part is testable without rendering.** Tasks 2 and 3 are pure arithmetic with no Flutter import beyond `dart:math` and `intl`. If you find yourself wanting a golden test, the split has gone wrong — the repo has no goldens and should not gain its first here.

**Task 4 has a trap called out in its own step 3:** `find.text` cannot see text a `CustomPainter` drew to the canvas. The axis labels must be real `Text` widgets in a `Stack` over the `CustomPaint`, sharing the gutter constants so the two layers agree. Getting this wrong makes Task 4's first test unpassable and tempts you to weaken it.

**Task 5's test file is specified as a comment block, not written out.** That is deliberate — it must be built on `exercise_detail_test.dart`'s real harness, which you should read rather than have me guess at. Write all four tests in full.

**The non-zero baseline is a deliberate, documented choice**, not an oversight. Every tick is labelled precisely because the axis does not start at zero. If a reviewer flags the baseline, the answer is in `chart_geometry.dart`'s doc comment and in the design.
