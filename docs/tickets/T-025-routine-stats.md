# T-025 — Routine detail stats: estimated duration + body-part summary

- **Status:** **Done** (2026-08-27) — `flutter analyze` clean, 441 tests pass (27 new)
- **Priority:** Should
- **Effort:** M
- **Specs:** S-030, ADR-006
- **Last updated:** 2026-08-27

## Goal

Close both of S-030's remaining open questions. The routine detail's stats tile has shown **Total
sets** and nothing else since [T-011](T-011-routine-detail.md) deferred the other two slots: the
reference's `Duration ~40 min`, and its anatomical figure of the muscles worked.

The tile is the answer to "what am I signing up for?", and one number is a thin answer. Sets tells
you the shape of the work but not its cost in time, and nothing at all tells you what it hits.

## Scope (in)

- **Estimated duration** in the tile, measured from history where we have it and derived from the
  plan where we do not.
- **Body-part summary** beneath the two stats, from our own taxonomy (T-005).
- The stats tile relaid out as two columns plus a full-width line, degrading to today's single
  centred column when neither new stat has anything to say.

## Scope (out)

- **An anatomical figure.** The reference's art must not be copied (README §3), and drawing our own
  is a different-sized job than this ticket.
- **Per-muscle detail** (`Chest · Front Delts · Triceps`). Body parts are the coarse axis, already
  streamed in bulk for the library's rows and filter, and they keep the vocabulary the same as
  T-021's filter. Primary muscles would need a new bulk query and a mixed routine lists seven or
  more, which stops being a summary.
- **Ranking body parts by set count** (`Chest 9 · Arms 6`). More informative, but an exercise tagged
  with two body parts double-counts, and explaining that costs more than the ranking is worth here.
- Any change to the routine editor, the Library rows, or the session flow.

## Files to touch

- `lib/features/templates/domain/routine_estimate.dart` (new) — the whole rule, pure, no Flutter
- `lib/features/templates/data/template_repository.dart` — `recentDurations`
- `lib/features/templates/providers/template_providers.dart` — the provider for it
- `lib/features/templates/ui/routine_detail_screen.dart` — `_StatsTile`
- `test/features/routine_estimate_test.dart` (new)
- `test/features/recent_durations_test.dart` (new)
- `test/widget/routine_detail_test.dart` — the new tile

## Model / DB changes

**None.** Every input already exists:

| Input | Where it already lives |
|---|---|
| Planned sets, per exercise | `TemplateSet` rows (schema v6) |
| Rest, per exercise | `TemplateExercise.restSeconds`, default 90 |
| Real session durations | `WorkoutSessions.startedAt` / `endedAt` / `pausedSeconds` |
| Body parts, per exercise | `ExerciseBodyParts` (schema v4, T-005) |

## The duration rule

Two branches, and which one you get is stated on screen rather than hidden:

1. **Measured** — the mean of up to the **last 3 completed sessions** started from this routine.
   Caption: `your average`.
2. **Estimated** — from the plan, when the routine has never been performed. Caption: `estimated`.

Measured wins whenever it has anything at all, including a single session. One real run of a routine
tells you more about what it costs than any formula does.

### The formula

For each planned set: **work + rest**.

- **Work** is the set's own `durationSeconds` for a duration-logged exercise, else a constant.
- **Rest** is that exercise's `restSeconds`.
- The **last set of the routine drops its rest** — you do not rest after the final set before
  leaving.

**The per-set work constant is 45 seconds, and it is invented.** It is the one number here with no
basis in the user's data or in anything the app records. It is written down as a named constant
rather than buried in an expression, and it is only ever visible on a routine that has never been
performed — the first time you run one, the estimate is replaced by measurement and never returns.

### Measured duration, precisely

`endedAt − startedAt − pausedSeconds`, the same arithmetic as `SessionWithExercises.elapsed`.
Non-positive results are dropped as corrupt. **Nothing else is filtered** — not a session that ran
five hours because it was left open. [T-020](T-020-finish-form.md) lets the user edit the duration
on the finish form, so a wrong number is one they chose to keep, and second-guessing it here would
override an explicit edit.

Both branches render as `~52 min` — the `~` carries the imprecision, so neither needs rounding to
a false-looking multiple of five.

## The body-part summary

Union of the body parts of every exercise in the routine, deduped, in **enum declaration order**
(`Chest · Back · Shoulders · Arms · Core · Legs …`) so one routine always reads the same way and
two routines are comparable at a glance.

Deliberately **not** `bodyPartsSubtitle`, which sorts alphabetically and caps at two with a `+n`.
That helper exists to stop a narrow list row changing height; the tile is full-width and has no such
problem, so it shows all of them.

Untagged exercises contribute nothing. A routine of entirely untagged exercises shows no line at
all — normal early on under [ADR-006](../decisions/ADR-006-exercise-library-phasing.md), and better
than an empty label.

## New components

None. `_StatsTile` is private to the routine detail screen and stays there; it is used by exactly
one surface, so a CMP-ID and a spec would be ceremony (README §6).

## Edge cases

- **Routine with no sets** — the estimate is zero, so the duration column is hidden rather than
  showing `~0 min`.
- **Routine never performed, no taxonomy** — both hidden; the tile is exactly today's single
  centred `Total sets`.
- **Duration-logged exercise with no seconds planned** — falls back to the work constant like any
  other set.
- **A session from this routine that is still running** — excluded, since only `completed` sessions
  count.
- **A soft-deleted session** — excluded, so deleting a bad workout ([T-014](T-014-delete-logged-workout.md))
  also removes it from the average, which is what deleting it should mean.
- **Body parts not loaded yet** — the line is absent for that frame rather than empty, the same
  choice the library's filter makes for the same reason.

## Acceptance criteria

- [x] A never-performed routine shows a duration from the plan, captioned `estimated`.
- [x] A routine with one or more completed sessions shows their mean, captioned `your average`.
- [x] The mean covers at most the three most recent, and subtracts paused time.
- [x] Body parts appear as one deduped line in enum order.
- [x] A routine with no sets and no taxonomy renders the tile as it does today.
- [x] The duration rule is unit-tested without pumping a widget.
- [x] `flutter analyze` clean; full suite green.

## QA checklist

Run on **macOS** (`flutter run -d macos`), not on the phone — the fast loop, and enough for a tile
that has no platform-specific behaviour in it.

Passed 2026-08-27, by opening routines and looking:

- [x] Open a routine you have never done — duration reads `estimated`.
- [x] Open a routine of untagged exercises — no body-part line, no empty gap.
- [x] Open an empty routine — tile is a single centred `Total sets`, Start still disabled.
- [x] Two columns align, and the caption does not crowd the number. No `RenderFlex` overflow in the
      run log.

**Not exercised.** These three need a session logged, edited and deleted in sequence, which the
visual pass did not do. They are covered by tests — `recent_durations_test.dart` asserts each of the
three behaviours at the repository level — but not confirmed by hand:

- [ ] Run it, finish it, reopen — duration now reads `your average` and reflects the real time.
- [ ] Edit the duration on the finish form, reopen — the average moves to match the edit.
- [ ] Delete that logged workout, reopen — the routine reverts to `estimated`.

## Revision log

- 2026-08-27 — created. Owner decisions, taken during brainstorming: measured-with-formula-fallback
  over formula-only (an invention that never gets truer) and over measured-only (missing precisely
  on new routines); body parts over primary muscles and over set-count ranking; two columns with the
  summary beneath over a three-column row (too narrow for the words) and over chips (implies a tap
  we are not building).
- 2026-08-27 — shipped. 27 tests: 14 on the pure rule, 8 on `recentDurations`, 5 on the tile.

## What shipped

The rule is one pure file, `routine_estimate.dart`, with no Flutter import — the interesting part of
this ticket is *which number you get and why*, and that should be readable without a widget near it.

Two things worth knowing for the next session:

- **`startFromTemplate` + `finishSession` in a widget test produces a zero-length session**, which
  `recentDurations` then drops as corrupt. Both run against the wall clock, so a session started and
  finished in the same test really did take no time. The T-025 widget tests insert their sessions
  directly for exactly this reason; the existing `last performed` test does not care, because it
  only reads `endedAt`.
- **`WorkoutTemplate`'s generated constructor requires `defaultRestSeconds`, `autoFocusNextSet` and
  `autoFocusNextExercise`.** Nothing in a fixture needs them, so the compile error arrives one
  argument at a time.
