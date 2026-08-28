# T-026 — Weight-unit normalisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every comparison or aggregation of weights **across sessions** converts to the user's current display unit first, so a mixed kg/lb history ranks and sums correctly.

**Architecture:** Read-time only. Storage is untouched — a session keeps the `weightUnit` it was logged in, permanently. Pure conversion helpers in `core/utils/`, applied inside the three domain functions that walk multiple sessions. Each of those functions gains a `displayUnit` parameter; each provider that calls one gains a `ref.watch` on the settings unit so a kg↔lb switch recomputes immediately.

**Tech Stack:** Dart 3.11, Flutter, Riverpod v2 (hand-written providers, **no codegen**), Drift. `flutter test`, `flutter analyze`.

**Spec:** `docs/superpowers/specs/2026-08-27-progress-chart-design.md` — read it first. This plan implements only its "The unit problem this uncovered — T-026" section. The Progress chart itself (T-027) is a **separate, later** plan.

## Global Constraints

- **No new dependencies.** Phase B rule, `docs/README.md` §4b. Nothing in this plan needs one.
- **No schema change.** Read-time only; no migration, no rewritten rows. `schemaVersion` stays **6**.
- **Riverpod v2, hand-written providers.** `riverpod_annotation` / `riverpod_generator` are NOT dependencies. Never write `@riverpod`.
- **Conversion constant: 1 lb = 0.45359237 kg**, exact by definition.
- **Round for display, never for storage or comparison** (ADR-004). Sums and comparisons run at full `double` precision.
- **Never `await` a Drift stream's `.first` inside a `testWidgets` body** — it wedges the runner rather than failing (`docs/README.md` §7).
- **Every widget test pumping a Drift-backed provider must end with `disposeAndDrainTimers`** — otherwise drift's cleanup timer is left pending and the file wedges. A red run looks like a hang: read the **head** of the log, not the tail.
- Commit messages: **no `Co-Authored-By` and no `Generated with` trailers.**
- Every change gets a ticket in `docs/tickets/`; specs are the source of truth; deviations get recorded, not made silently (`docs/README.md` §2, §3).

---

### Task 1: The conversion helpers, and the T-026 ticket

**Files:**
- Create: `lib/core/utils/weight_units.dart`
- Create: `test/features/weight_units_test.dart`
- Create: `docs/tickets/T-026-weight-unit-normalisation.md`

**Interfaces:**
- Consumes: nothing.
- Produces: `const double kgPerPound`; `double convertWeight(double value, {required String from, required String to})`. Every later task calls `convertWeight`.

- [ ] **Step 1: Write the failing test**

Create `test/features/weight_units_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/utils/weight_units.dart';

/// T-026 — the app stores each session in the unit it was logged in and never
/// rewrites it, so every cross-session comparison has to convert first.
void main() {
  test('leaves a value alone when the units match', () {
    expect(convertWeight(60, from: 'kg', to: 'kg'), 60);
    expect(convertWeight(135, from: 'lb', to: 'lb'), 135);
  });

  test('converts pounds to kilograms', () {
    expect(convertWeight(100, from: 'lb', to: 'kg'), closeTo(45.359237, 1e-9));
  });

  test('converts kilograms to pounds', () {
    expect(convertWeight(45.359237, from: 'kg', to: 'lb'), closeTo(100, 1e-9));
  });

  test('a round trip returns the original value', () {
    // Multiply one way and divide the other, rather than two separately
    // rounded constants — otherwise kg -> lb -> kg drifts.
    final there = convertWeight(82.5, from: 'kg', to: 'lb');
    expect(convertWeight(there, from: 'lb', to: 'kg'), closeTo(82.5, 1e-9));
  });

  test('passes an unrecognised unit through unchanged', () {
    // `weightUnit` is a free-text column with a 'kg' default, so a value we do
    // not know is possible. Guessing would corrupt the number; leaving it is
    // at worst as wrong as today.
    expect(convertWeight(60, from: 'stone', to: 'kg'), 60);
    expect(convertWeight(60, from: 'kg', to: 'stone'), 60);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/weight_units_test.dart`
Expected: FAIL — `Error when reading 'lib/core/utils/weight_units.dart': No such file or directory`

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/utils/weight_units.dart`:

```dart
/// T-026 — weight-unit conversion, applied at read time only.
///
/// A session records the unit it was logged in and keeps it forever: that is
/// the true record of what happened, and rewriting history to one unit would
/// destroy it. What converts is every *comparison or aggregation across
/// sessions* — records, `Previous`, and weekly volume — on the way out.

/// Exact by definition (international avoirdupois pound).
const double kgPerPound = 0.45359237;

/// [value], expressed in [from], restated in [to].
///
/// Multiplies one way and divides the other rather than carrying two rounded
/// constants, so a kg -> lb -> kg round trip returns what it started with.
///
/// An unrecognised unit passes the value through unchanged. `weightUnit` is a
/// free-text column defaulting to `'kg'`, so an unknown value is reachable;
/// guessing at it would corrupt the number, whereas passing it through is at
/// worst exactly as wrong as the behaviour this ticket replaces.
double convertWeight(double value, {required String from, required String to}) {
  if (from == to) return value;
  if (from == 'lb' && to == 'kg') return value * kgPerPound;
  if (from == 'kg' && to == 'lb') return value / kgPerPound;
  return value;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/weight_units_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Write the ticket**

Create `docs/tickets/T-026-weight-unit-normalisation.md`:

```markdown
# T-026 — Normalise weights to the display unit before comparing

- **Status:** In progress
- **Priority:** Must
- **Effort:** M
- **Specs:** ADR-003, ADR-004, [design](../superpowers/specs/2026-08-27-progress-chart-design.md)
- **Last updated:** 2026-08-28

## Goal

There is **no weight-unit conversion anywhere in `lib/`**. Sessions snapshot their own `weightUnit`,
Settings lets the unit change at any time, so history can hold both kg and lb — and three places
compare or aggregate weights across sessions without reading that field.

This is a **live bug**, found while designing the progress chart (T-027) rather than introduced by
it. Today a 100 lb lift (45 kg) out-ranks a 60 kg one on every personal record.

## Scope (in)

- `convertWeight` helpers in `core/utils/`.
- `computePersonalRecords`, `previousBestByExercise`, `weeklySummary` take a `displayUnit`.
- The providers behind them watch the settings unit, so a switch recomputes immediately.
- Home's volume delta stops hardcoding `kg`.

## Scope (out)

- **Any migration or backfill.** Read-time only, owner-confirmed 2026-08-28. Storage is untouched.
- The progress chart itself — that is [T-027](T-027-progress-chart.md).
- Unit conversion in the *live* session UI. A running session has one unit throughout; nothing
  there compares across sessions.

## Model / DB changes

**None.** `schemaVersion` stays 6.

## Acceptance criteria

- [ ] A mixed kg/lb history ranks personal records by true weight.
- [ ] `Previous` names the genuinely heavier set across a unit change.
- [ ] Weekly volume sums after conversion; the delta is computed before rounding.
- [ ] Switching the unit in Settings restates all three with no history edit.
- [ ] Home's volume delta shows the user's unit, not a hardcoded `kg`.
- [ ] `flutter analyze` clean; full suite green.

## QA checklist

- [ ] Log a session in kg, switch to lb, open You — records restate immediately.
- [ ] Home's weekly volume and its delta both read in the current unit.

## Revision log

- 2026-08-28 — created from the T-027 design doc, which uncovered the bug.
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/utils/weight_units.dart test/features/weight_units_test.dart docs/tickets/T-026-weight-unit-normalisation.md
git commit -m "feat(units): convert weights between kg and lb (T-026)

No conversion existed anywhere in lib/, so any comparison across
sessions logged in different units was wrong. Read-time only: storage
keeps the unit each session was logged in."
```

---

### Task 2: A shared mixed-unit session fixture

Tasks 3-5 each need `ActiveSession` values that differ **by unit**, which no existing fixture
supports — `test/features/personal_records_test.dart` has a local `session(...)` helper with
`weightUnit: 'kg'` hard-coded. Build it once here rather than three times.

**Files:**
- Create: `test/support/session_fixtures.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `ActiveSession completedSession({required String unit, required List<(double, int)> sets, DateTime? endedAt, String exerciseId, String exerciseName, LoggingType loggingType})`. Tasks 3, 4 and 5 all import this one function.

- [ ] **Step 1: Write the fixture**

Create `test/support/session_fixtures.dart`. There is no test to fail first — this is test
infrastructure, not behaviour; Task 3's failing test is the one that exercises it.

```dart
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/data/session_models.dart';

var _seq = 0;

/// A completed session holding one exercise, whose sets are `(weight, reps)`
/// pairs, logged in [unit].
///
/// The existing per-file helpers hard-code `weightUnit: 'kg'`, which is exactly
/// the axis T-026 needs to vary, so this lives in `test/support/` and is shared
/// rather than copied a third time.
ActiveSession completedSession({
  required String unit,
  required List<(double, int)> sets,
  DateTime? endedAt,
  String exerciseId = 'ex-1',
  String exerciseName = 'Bench Press',
  LoggingType loggingType = LoggingType.strengthWeightRepsRir,
}) {
  final now = endedAt ?? DateTime.utc(2026, 8, 20);
  final sessionId = 'session-${_seq++}';

  final sessionSets = [
    for (final (weight, reps) in sets)
      SessionSet(
        id: 'set-${_seq++}',
        sessionExerciseId: 'se-$sessionId',
        setIndex: 0,
        weight: weight,
        reps: reps,
        rir: null,
        durationSeconds: null,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      ),
  ];

  return ActiveSession(
    session: WorkoutSession(
      id: sessionId,
      templateId: null,
      name: 'Session',
      weightUnit: unit,
      status: SessionStatus.completed,
      autoFocusNextSet: true,
      autoFocusNextExercise: true,
      startedAt: now,
      endedAt: now,
      pausedSeconds: 0,
      pausedAt: null,
      notes: null,
      restStatus: RestTimerStatus.idle,
      restEndsAt: null,
      restRemainingSeconds: null,
      restTotalSeconds: null,
      restAfterSetId: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    ),
    exercises: [
      SessionExerciseWithSets(
        exercise: SessionExercise(
          id: 'se-$sessionId',
          sessionId: sessionId,
          exerciseId: exerciseId,
          name: exerciseName,
          description: null,
          notes: null,
          imagePath: null,
          loggingType: loggingType,
          sortOrder: 0,
          restSeconds: 90,
          targetSets: sets.length,
          sessionNotes: null,
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
        ),
        sets: sessionSets,
      ),
    ],
  );
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze test/support/session_fixtures.dart`
Expected: `No issues found!`

If a constructor argument is missing or renamed, the generated `app_database.g.dart` is the
authority — read the constructor there rather than guessing. `WorkoutSession` in particular has
required named parameters that arrive one compile error at a time.

- [ ] **Step 3: Commit**

```bash
git add test/support/session_fixtures.dart
git commit -m "test: shared fixture for sessions logged in different units

T-026 needs sessions that differ by weightUnit; every existing helper
hard-codes kg."
```

---

### Task 3: Personal records rank by true weight

**Files:**
- Modify: `lib/features/records/data/personal_records.dart` — `computePersonalRecords`
- Modify: `lib/features/records/providers/records_providers.dart`
- Create: `test/features/records_units_test.dart`

**Interfaces:**
- Consumes: `convertWeight` (Task 1), `completedSession` (Task 2).
- Produces: `computePersonalRecords(List<ActiveSession> sessions, {required String displayUnit})` — **the positional `sessions` argument stays first**; `displayUnit` is a new required named parameter. Every existing caller must be updated.

- [ ] **Step 1: Write the failing test**

Create `test/features/records_units_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/features/records/data/personal_records.dart';

import '../support/session_fixtures.dart';

/// T-026 — records compared raw numbers, so the unit a session was logged in
/// decided the ranking.
void main() {
  test('a heavier kg lift outranks a larger lb number', () {
    // 100 lb = 45.36 kg, so the 60 kg set is the real record even though
    // 100 > 60 as a bare number — the bug this ticket fixes.
    final sessions = [
      completedSession(unit: 'lb', sets: [(100.0, 5)]),
      completedSession(unit: 'kg', sets: [(60.0, 5)]),
    ];

    final records = computePersonalRecords(sessions, displayUnit: 'kg');

    expect(records.single.heaviestWeight!.value, closeTo(60, 1e-9));
  });

  test('restates every record in the display unit', () {
    final sessions = [completedSession(unit: 'kg', sets: [(60.0, 5)])];

    final records = computePersonalRecords(sessions, displayUnit: 'lb');

    // 60 kg = 132.277 lb.
    expect(records.single.heaviestWeight!.value, closeTo(132.277, 1e-3));
  });

  test('a zero-weight set sets no record', () {
    // Bodyweight work. A 0 kg "record" is not a lift, and it is what the
    // progress chart would otherwise plot at zero.
    final sessions = [completedSession(unit: 'kg', sets: [(0.0, 10)])];

    final records = computePersonalRecords(sessions, displayUnit: 'kg');

    expect(records, isEmpty);
  });
}
```

**Note on the third test — this is a deliberate behaviour change.** Today `computePersonalRecords` skips only `null` weights, so a logged `0` sets a 0 kg weight record and a 0 e1RM record. The design doc flagged this for T-026 to decide; the decision is to skip `weight <= 0`, matching what `exerciseProgress` will do in T-027. Record it in the ticket's revision log.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/records_units_test.dart`
Expected: FAIL — `computePersonalRecords` has no `displayUnit` named parameter.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/records/data/personal_records.dart`, change the signature and convert each weight as it is read:

```dart
List<ExerciseRecords> computePersonalRecords(
  List<ActiveSession> sessions, {
  required String displayUnit,
}) {
```

Inside the set loop, replace:

```dart
        final weight = set.weight;
        final reps = set.reps;
        if (weight == null || reps == null || reps <= 0) continue;
```

with:

```dart
        final logged = set.weight;
        final reps = set.reps;
        if (logged == null || reps == null || reps <= 0) continue;
        // Converted before any comparison: the session stores what was
        // logged, in the unit it was logged in, and two sessions can differ.
        final weight = convertWeight(
          logged,
          from: session.session.weightUnit,
          to: displayUnit,
        );
        // A zero-weight set is bodyweight work, not a 0 kg record (T-026).
        if (weight <= 0) continue;
```

Add the import:

```dart
import '../../../core/utils/weight_units.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/records_units_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Update the provider to watch the unit**

In `lib/features/records/providers/records_providers.dart`:

```dart
final personalRecordsProvider = Provider<List<ExerciseRecords>>((ref) {
  final sessions = ref.watch(historyProvider).valueOrNull ?? const [];
  // Watched, not read: switching units in Settings must restate every record
  // immediately. Without this the provider only recomputes when history
  // changes, leaving records visibly stale in the new unit (T-026).
  final unit = ref.watch(settingsProvider).weightUnit;
  return computePersonalRecords(sessions, displayUnit: unit);
});
```

Add the import for `settingsProvider` (`../../settings/providers/settings_providers.dart`).

- [ ] **Step 6: Write the invalidation test**

Append to `test/features/records_units_test.dart`:

```dart
  test('switching the display unit restates records with no history edit',
      () async {
    final container = ProviderContainer(overrides: [
      historyProvider.overrideWith(
        (ref) => Stream.value([completedSession(unit: 'kg', sets: [(60.0, 5)])]),
      ),
    ]);
    addTearDown(container.dispose);
    // Let the overridden stream deliver before reading the derived provider.
    await container.read(historyProvider.future);

    expect(container.read(personalRecordsProvider).single.heaviestWeight!.value,
        closeTo(60, 1e-9));

    await container.read(settingsProvider.notifier).setWeightUnit('lb');

    expect(container.read(personalRecordsProvider).single.heaviestWeight!.value,
        closeTo(132.277, 1e-3),
        reason: 'the unit switch alone must recompute it');
  });
```

`setWeightUnit` writes through `settingsRepositoryProvider`, so override that too — check how existing tests stub it (`test/widget/settings_screen_test.dart`) and follow that pattern rather than inventing one.

- [ ] **Step 7: Fix the other callers, then run the whole suite**

`computePersonalRecords` is called from more than one place. Find them and pass the unit:

```bash
grep -rn "computePersonalRecords" lib/ test/
```

Run: `flutter test && flutter analyze`
Expected: all green, analyze clean. Existing `test/features/personal_records_test.dart` will need `displayUnit: 'kg'` added to its calls — that is the correct fix, not a reason to make the parameter optional.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "fix(records): rank personal records by true weight (T-026)

computePersonalRecords compared raw numbers, so a 100 lb lift (45 kg)
outranked a 60 kg one on all four metrics. Converts to the display unit
first, and the provider now watches the setting so a switch restates
records immediately.

Also stops treating a logged 0 as a 0 kg record: a zero-weight set is
bodyweight work, not a lift."
```

---

### Task 4: `Previous` names the genuinely heavier set

**Files:**
- Modify: `lib/features/sessions/domain/previous_best.dart` — `previousBestByExercise`
- Modify: `lib/features/sessions/providers/previous_best_provider.dart`
- Create: `test/features/previous_best_units_test.dart`

**Interfaces:**
- Consumes: `convertWeight` (Task 1), `completedSession` (Task 2).
- Produces: `previousBestByExercise(List<ActiveSession> completed, {required String displayUnit})`. `PreviousBest.weight` is now **in the display unit**, not as logged.

- [ ] **Step 1: Write the failing test**

Create `test/features/previous_best_units_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/features/sessions/domain/previous_best.dart';

import '../support/session_fixtures.dart';

/// T-026 — `Previous` scored raw numbers, so a set logged in lb could beat a
/// genuinely heavier kg set.
void main() {
  test('reports the previous best in the display unit', () {
    // Logged as 135 lb; shown to a kg user as 61.2 kg.
    final sessions = [completedSession(unit: 'lb', sets: [(135.0, 5)])];

    final best = previousBestByExercise(sessions, displayUnit: 'kg');

    expect(best.values.single.weight, closeTo(61.235, 1e-3));
  });

  test('ranks two sets from one session by converted weight', () {
    // Same session, so same unit — this guards that the ordering logic still
    // works once weights pass through conversion.
    final sessions = [
      completedSession(unit: 'kg', sets: [(60.0, 8), (70.0, 5)]),
    ];

    final best = previousBestByExercise(sessions, displayUnit: 'kg');

    // 70x5 estimates higher than 60x8 under Epley (ADR-004).
    expect(best.values.single.weight, closeTo(70, 1e-9));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/previous_best_units_test.dart`
Expected: FAIL — no `displayUnit` named parameter.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/sessions/domain/previous_best.dart`:

```dart
Map<String, PreviousBest> previousBestByExercise(
  List<ActiveSession> completed, {
  required String displayUnit,
}) {
```

In the set loop, replace:

```dart
        final weight = set.weight;
        final reps = set.reps;
        if (weight == null || reps == null || reps <= 0) continue;
```

with:

```dart
        final logged = set.weight;
        final reps = set.reps;
        if (logged == null || reps == null || reps <= 0) continue;
        // Converted before scoring, so a set logged in lb is ranked against a
        // kg set by what was actually lifted (T-026).
        final weight = convertWeight(
          logged,
          from: session.session.weightUnit,
          to: displayUnit,
        );
```

Add `import '../../../core/utils/weight_units.dart';`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/previous_best_units_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Update the provider to watch the unit**

In `lib/features/sessions/providers/previous_best_provider.dart`:

```dart
final previousBestProvider = Provider<Map<String, PreviousBest>>((ref) {
  final sessions = ref.watch(historyProvider).valueOrNull ?? const [];
  // Watched for the same reason personalRecordsProvider watches it: a unit
  // switch must restate `Previous` without waiting on a history edit (T-026).
  final unit = ref.watch(settingsProvider).weightUnit;
  return previousBestByExercise(sessions, displayUnit: unit);
});
```

- [ ] **Step 6: Fix the other callers and run the suite**

```bash
grep -rn "previousBestByExercise" lib/ test/
```

Run: `flutter test && flutter analyze`
Expected: green and clean.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "fix(sessions): rank Previous by converted weight (T-026)

previousBestByExercise scored raw numbers, so a set logged in lb could
beat a genuinely heavier kg set. Converts first, and the provider watches
the setting so a switch restates the line."
```

---

### Task 5: Weekly volume sums after conversion, and Home stops saying "kg"

**Files:**
- Modify: `lib/features/sessions/data/session_models.dart` — add `completedVolumeIn`
- Modify: `lib/features/dashboard/domain/weekly_summary.dart` — `weeklySummary`
- Modify: `lib/features/dashboard/ui/home_screen.dart:38,70-72`
- Create: `test/features/weekly_summary_units_test.dart`

**Interfaces:**
- Consumes: `convertWeight` (Task 1), `completedSession` (Task 2).
- Produces: `ActiveSession.completedVolumeIn(String displayUnit)`; `weeklySummary(List<ActiveSession> completed, {required DateTime now, required String displayUnit})`.

- [ ] **Step 1: Write the failing test**

Create `test/features/weekly_summary_units_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/features/dashboard/domain/weekly_summary.dart';

import '../support/session_fixtures.dart';

/// T-026 — weekly volume added kg and lb together.
void main() {
  final now = DateTime.utc(2026, 8, 26); // a Wednesday

  test('sums this week volume after converting each session', () {
    // 100 lb x 10 reps = 1000 lb of work = 453.59 kg.
    final sessions = [
      completedSession(unit: 'lb', sets: [(100.0, 10)], endedAt: now),
    ];

    final summary = weeklySummary(sessions, now: now, displayUnit: 'kg');

    expect(summary.volume, closeTo(453.59237, 1e-5));
  });

  test('computes the delta from unrounded sums', () {
    // Two weeks whose volumes differ by less than a whole unit must not
    // display a whole-unit delta: rounding each week first and subtracting
    // would manufacture one.
    final lastWeek = now.subtract(const Duration(days: 7));
    final sessions = [
      completedSession(unit: 'kg', sets: [(10.4, 1)], endedAt: now),
      completedSession(unit: 'kg', sets: [(10.0, 1)], endedAt: lastWeek),
    ];

    final summary = weeklySummary(sessions, now: now, displayUnit: 'kg');

    expect(summary.volumeDelta, closeTo(0.4, 1e-9));
  });
}
```

**Check `weekStart` before writing the dates.** The app's week runs Sunday-Saturday
(`core/utils/formatting.dart`), so confirm `now` and `lastWeek` land in adjacent weeks under that
definition rather than assuming a Monday start.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/weekly_summary_units_test.dart`
Expected: FAIL — no `displayUnit` named parameter.

- [ ] **Step 3: Add the unit-aware volume getter**

In `lib/features/sessions/data/session_models.dart`, beside the existing `completedVolume`:

```dart
  /// [completedVolume], restated in [displayUnit].
  ///
  /// The session knows the unit it was logged in, so the conversion belongs
  /// here rather than at each call site. `completedVolume` is kept for the
  /// single-session surfaces (the summary screen, a history row), which show
  /// a session in its own unit and have nothing to reconcile (T-026).
  double completedVolumeIn(String displayUnit) => convertWeight(
        completedVolume,
        from: session.weightUnit,
        to: displayUnit,
      );
```

Volume is `Σ weight × reps`, so it scales linearly with the weight unit — converting the total is identical to converting each set, and cheaper.

Add `import '../../../core/utils/weight_units.dart';`.

- [ ] **Step 4: Thread the unit through `weeklySummary`**

In `lib/features/dashboard/domain/weekly_summary.dart`:

```dart
WeeklySummary weeklySummary(
  List<ActiveSession> completed, {
  required DateTime now,
  required String displayUnit,
}) {
```

and replace both `s.completedVolume` uses with `s.completedVolumeIn(displayUnit)`.

The delta already subtracts the raw `double` sums (`volume - priorVolume`), which is what the second test requires — **do not add rounding here.** Rounding happens only where it is drawn.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/weekly_summary_units_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 6: Fix Home — pass the unit, and stop hardcoding it**

`lib/features/dashboard/ui/home_screen.dart:38` calls `weeklySummary` directly from the widget, so the watch goes here:

```dart
    final unit = ref.watch(settingsProvider).weightUnit;
    final summary = weeklySummary(history, now: DateTime.now(), displayUnit: unit);
```

Then at lines 70-72, the delta label hardcodes `kg` — a lie today for any lb user, independent of this ticket:

```dart
                  value: '${summary.volume.round()}',
                  delta: summary.volumeDelta,
                  deltaLabel: '${summary.volumeDelta.abs().round()} $unit',
```

`.round()` at the point of display is the rule from the spec: full precision to sum and compare, whole units to draw.

- [ ] **Step 7: Run the whole suite**

```bash
grep -rn "weeklySummary(" lib/ test/
```

Run: `flutter test && flutter analyze`
Expected: green and clean. `test/features/weekly_summary_test.dart` needs `displayUnit: 'kg'` added to its calls.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "fix(home): sum weekly volume after converting units (T-026)

weeklySummary added kg and lb together, so both the weekly volume and
its week-on-week delta were wrong for a mixed history. The delta is still
computed from unrounded sums and rounded only to draw.

Home's delta label also hardcoded 'kg', which was wrong for any lb user
regardless of this ticket."
```

---

### Task 6: Close the ticket and record the decisions

**Files:**
- Modify: `docs/decisions/ADR-003-volume-as-total-weight.md`
- Modify: `docs/tickets/T-026-weight-unit-normalisation.md`
- Modify: `docs/README.md` — ticket registry, §7

- [ ] **Step 1: Add the ADR-003 revision note**

Append to ADR-003's revision log:

```markdown
- 2026-08-28 — volume is stated in the **display unit**, summed after conversion at full precision
  and rounded only to draw ([T-026](../tickets/T-026-weight-unit-normalisation.md)). Until then it
  added kg and lb together, so a mixed history produced a meaningless total — the definition was
  right and the arithmetic was not.
```

- [ ] **Step 2: Tick the ticket's acceptance criteria and add its revision entry**

Set `Status: **Done** (2026-08-28)` with the real test count from the suite run, tick every acceptance box that the tests cover, and add:

```markdown
- 2026-08-28 — shipped. Records, `Previous` and weekly volume all convert first; the three providers
  watch the settings unit so a switch restates them with no history edit. Also decided here: a
  logged `0` is bodyweight, not a 0 kg record — `computePersonalRecords` skipped only `null` before.
```

Leave the two **QA checklist** boxes unticked. They need a device or a macOS run, and ticking them from a test suite would be the false claim `docs/README.md` §6 already records being caught once.

- [ ] **Step 3: Update the README registry**

Add to the ticket table:

```markdown
| [T-026](tickets/T-026-weight-unit-normalisation.md) | Normalise weights to the display unit before comparing | **Done** | M | ADR-003, ADR-004 |
```

Set `Next free T-ID: **T-027**`, bump the ticket count in §7's table, and add a `Next step` line pointing at T-027 (the progress chart) with its design doc linked.

- [ ] **Step 4: Verify the whole suite one last time**

Run: `flutter test && flutter analyze`
Expected: all green, analyze clean. Record the real test count in the ticket — do not guess it.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs: close T-026, and state volume in the display unit

ADR-003's definition was right and its arithmetic was not: volume is
summed after conversion, at full precision, rounded only to draw."
```

---

## Notes for whoever executes this

**Tasks 3-5 are the same shape three times**, deliberately: convert on read, thread a `displayUnit` parameter, make the provider watch the setting. Resist merging them — each is independently reviewable and independently revertible, and they touch three unrelated screens (You, the live session, Home).

**The invalidation watch is the part most likely to be skipped**, because everything passes without it — the conversion is correct, the tests on the pure functions are green, and the bug only shows when a human switches units and stares at a stale number. Task 3 Step 6 is the test that catches it. Do not drop it.

**One deliberate behaviour change rides along** (Task 3): a logged `0` stops setting a 0 kg record. It is recorded in the ticket and in the design doc. If a reviewer objects, it is a two-line revert that leaves the rest of the ticket intact.
