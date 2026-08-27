# T-011 — Routine detail screen + start-from-anywhere play button

- **Status:** **Done** (2026-08-25) — `flutter analyze` clean, 310 tests pass.
- **Priority:** Must
- **Effort:** M
- **Specs:** S-030, S-004, S-009, CMP-011
- **Last updated:** 2026-08-25

## Goal

Tapping a routine has always opened the **editor**. You start a routine far more often than you edit
it, so the tap now opens a read-only detail screen (S-030) whose primary action is **Start workout**,
and editing moves to the ⋮ menu. Routine rows also gain a play button, so starting takes one tap from
the list without opening anything.

## Scope (in)

- New screen at `/templates/:id/detail` (S-030).
- `LibraryRow` gains a trailing slot; routine rows put a play button in it.
- Routine rows in the Library **and** inside a program open the detail screen and carry the play
  button. Program rows do not — a program holds several routines, so there is nothing single to
  start.
- A prescription-line formatter aggregating an exercise's planned sets.

## Scope (out)

- The estimated duration, the anatomical figure, and the share button (S-030 open questions).
- Any change to the routine editor itself beyond being reached from ⋮.
- **Delete** in the ⋮ menu — it already lives on the Workout tab; duplicating it needs its own reason.
- A program *detail* screen. The program surface stays an editor; only its routine rows change.

## Files touched

- `lib/features/templates/ui/routine_detail_screen.dart` (new)
- `lib/features/templates/data/template_models.dart` — `describeTemplateExercise`
- `lib/core/utils/formatting.dart` — `relativeDay`
- `lib/features/library/ui/library_screen.dart` — trailing slot + play button + tap target
- `lib/features/programs/ui/program_editor_screen.dart` — same on its routine rows
- `lib/app/router.dart` — the new route

## Model / DB changes

**None.** `TemplateWithExercises`, `TemplateSummary.lastPerformedAt` and the schema-v6 planned sets
already carry everything the screen shows.

## New components

None new; reuses `InitialsTile` (CMP-011) and the existing `startWorkout()` action, so the
already-running-session dialog behaves identically to every other entry point.

## Edge cases

- Routine with **no exercises** — empty state, Start disabled (`canStart` is already false).
- Routine **deleted while open** — the stream emits null; pop rather than render a shell.
- **Never performed** — `Never performed` instead of a relative date.
- **Mixed prescriptions** across sets — the line shows the span (`6-10 reps`, `60-80kg`), not "varied".
- **Duration-logged** exercises show seconds instead of reps and weight.
- A **session already running** when Start or play is pressed — existing resume-or-discard dialog.

## Acceptance criteria

- [x] Tapping a routine in the Library opens the detail screen, not the editor.
- [x] The screen shows the name, last-performed (or `Never performed`), total sets, and one row per
      exercise with its prescription line.
- [x] ⋮ → Edit opens the editor.
- [x] Start workout starts a session and lands on it.
- [x] A routine with no exercises shows an empty state and cannot be started.
- [x] A play button on routine rows starts a session without opening the detail screen.
- [x] Program rows have no play button.
- [x] Routine rows inside a program behave the same as in the Library.
- [x] `flutter analyze` clean; `flutter test` passes (310).

## QA checklist (on device)

- [x] Library → tap a routine → detail; Start workout runs it.
- [x] Library → play button on a routine → straight into the session.
- [x] Open a program → tap a routine → same detail screen.
- [x] A never-performed routine reads `Never performed`.
- [x] An empty routine cannot be started.
- [x] Start one routine while another session runs — the resume-or-discard dialog appears.

## Tests

- `test/features/routine_prescription_line_test.dart` — 12 cases on the aggregated line.
- `test/features/relative_day_test.dart` — 6 on `relativeDay`.
- `test/widget/routine_detail_test.dart` — 7 on the screen.
- `test/widget/routine_play_button_test.dart` — 4 on the play button across both surfaces.

## What this cost, and the lesson worth keeping

**A widget test for a `templateProvider`-backed screen must use a plain `ProviderScope`, not
`UncontrolledProviderScope` with a container disposed in `tearDown`.**

The first version of `routine_detail_test.dart` used the `UncontrolledProviderScope` + external
container pattern copied from `library_screen_test.dart`. Every run appeared to *hang*: no output,
no failure, the runner wedged until killed.

It was not a hang in the usual sense. Disposing the container after the last pump lets drift's
`StreamQueryStore.markAsClosed` schedule a zero-duration cleanup timer with no frame left to drain
it; the pending-timer assertion then fires during finalization and leaves `flutter_tester` stuck, so
the symptom presents as silence rather than as a failure.

Four hypotheses were wrong before the right one: that `flutter run` was holding the build directory,
that `pumpUntilData` was spinning (it is bounded at 40 frames), that `disposeAndDrainTimers` alone
would fix it, and that watching `templateProvider` and `templateSummariesProvider` together was the
cause. What actually settled it was checking a **known-good existing test** — `library_screen_test`
passed in one second, proving the environment was fine — and then noticing that
`template_editor_test`, the only other test touching the same family provider, uses `ProviderScope`.

Two process notes: the real exception was in the log the whole time, above the lines a `grep` filter
was keeping, and piping a hanging test through `tail` hides all progress. Read the head of the log.

## Revision log
- 2026-08-25 — created from S-030, itself from `ref-S030-routine-detail.png`; shipped the same day.
