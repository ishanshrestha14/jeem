# T-012 — Ad-hoc sessions + add exercises mid-session

- **Status:** **Done** (2026-08-25) — `flutter analyze` clean, 320 tests pass.
- **Priority:** Must
- **Effort:** M
- **Specs:** S-006 (ad-hoc empty session), S-014 (picker), S-017 (session settings), CMP-004
- **Last updated:** 2026-08-25

## Goal

`startFromTemplate` is the only way to start a session, so a workout you have not planned cannot be
logged at all. And once a session is running, its exercises are fixed — whatever the routine
snapshotted is what you are stuck with.

Both fall out of the same missing capability: **putting an exercise into a live session**. This
ticket adds it, which makes an empty ad-hoc session viable (S-006's "Ad-hoc empty session") and
unblocks the Workout tab's FAB ([T-013](T-013-workout-tab.md)).

## Scope (in)

- `SessionRepository.startAdHoc()` — a session with no template and no exercises.
- `ActiveSessionController.addExercise(exerciseId)` — appends an exercise, with one empty set, to
  the running session.
- The empty-session surface from S-006: stats box, a void, then **Add exercises** (filled) above
  **More** (muted), vertically centred.
- The same pair below the last card when the session *does* have exercises — CMP-004, so exercises
  can be added to a session already underway.
- **More** opens the existing session settings sheet (S-017), per S-006's mapping.

## Scope (out)

- Removing an exercise from a live session — S-006 puts that behind the per-exercise ⋮, whose
  contents are still an open question there.
- Any change to the Workout tab; that is T-013.
- Prescriptions on an ad-hoc exercise. Added exercises arrive with one empty set and no plan, which
  is the honest state: nothing planned it.

## Files touched

- `lib/features/sessions/data/session_repository.dart` — `startAdHoc`, `addExerciseToSession`
- `lib/features/sessions/providers/active_session_controller.dart` — `addExercise`
- `lib/features/sessions/ui/active_session_screen.dart` — the empty state and the bottom actions

## Model / DB changes

**None.** `WorkoutSession.templateId` is already nullable, and `SessionExercises` snapshots an
exercise by value, so nothing about it requires a template to have existed.

## Decisions

- **An ad-hoc session is named `Workout`.** It has no routine to take a name from, and the name is
  editable in session settings. A date-stamped name would duplicate the timestamp every surface
  already shows beside it.
- **An added exercise starts with one empty set**, not the three a routine defaults to. You add the
  exercise because you are about to do it; how many sets is discovered as you go.
- **Appended, never inserted.** A new exercise goes to the end of the list, so adding one mid-session
  cannot reorder what you are in the middle of.

## Edge cases

- **Adding the first exercise to an empty session** must make it the current target, so the session
  becomes logbable immediately rather than sitting with no focused set.
- **Adding to a finished-but-not-saved session** — every exercise complete, then one added: the
  session must return to in-progress rather than staying "done".
- **A duration-logged exercise** added ad-hoc gets a duration set, not weight/reps.
- **An archived exercise** can still be added; the picker already surfaces its state.
- **Cancelling the picker** adds nothing and leaves the session untouched.

## Acceptance criteria

- [x] `startAdHoc` creates an active session with no template, no exercises, named `Workout`.
- [x] An empty session renders the stats box, **Add exercises** and **More** — no exercise list.
- [x] **Add exercises** opens the picker and appends the chosen exercise with one empty set.
- [x] The first exercise added to an empty session becomes the current target.
- [x] An exercise can be added to a session that already has exercises, and lands last.
- [x] Cancelling the picker changes nothing (the handler returns on a null pick).
- [x] **More** opens the session settings sheet.
- [x] A duration exercise added ad-hoc gets a duration set.
- [x] `flutter analyze` clean; `flutter test` passes (320).

## QA checklist (on device)

- [x] Start an ad-hoc session, add two exercises, log a set in each, finish — it appears in history.
- [x] Add an exercise to a routine-started session already underway.
- [x] Complete every set, then add another exercise — the session is in progress again.
- [ ] Open More mid-session — settings behave as they do from the app bar.

## Not yet reachable

`startAdHoc` has **no UI entry point yet** — the Workout tab's FAB is what will call it, and that is
[T-013](T-013-workout-tab.md). Adding an exercise mid-session *is* reachable today, from any session.

## What this cost

Putting **Add exercises / More** below the last card of a *populated* session — which
`ref-S006-session-active.png` clearly shows, and which the owner's "keep adding exercises as you go"
requires — grew the scroll content by ~130dp and broke **17 existing tests** in
`session_keypad_test` and `rest_ui_test`. None was a real defect: on the 800x600 test surface the set
rows no longer all sit above the fold, and `tester.tap` on an off-screen widget *warns and misses*
rather than failing, so the symptom appeared later as an assertion about state that never changed.

Fixed with a `tapVisible` helper in `pump_helpers.dart` (ensure-visible, pump, tap) applied to the
field and control taps. Worth knowing: a bare `tester.tap` is quietly position-dependent, so any
change to the session list's height can break tests that never mention it.

An empty-state-only placement was built and verified green first, then rejected — it would have hidden
the button as soon as the first exercise was added, which is the opposite of the requirement.

## Revision log
- 2026-08-25 — created. Owner chose the full ad-hoc route over a routine-picker FAB.
