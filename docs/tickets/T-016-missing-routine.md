# T-016 — Starting a deleted routine crashed

- **Status:** **Done** (2026-08-26) — `flutter analyze` clean, 354 tests pass.
- **Priority:** Must
- **Effort:** S
- **Specs:** FL-001
- **Last updated:** 2026-08-26

## The bug

`TemplateRepository.deleteTemplate` is a **hard** delete, so a routine can vanish between being
listed and being started. `SessionRepository.startFromTemplate` used `getSingle()`, which throws a
bare `StateError: No element` on an empty result. Nothing caught it.

Reachable from every start entry point that names a routine — the Library play button, a suggested
routine on the Workout tab, a routine inside a program, and the S-030 detail screen left open while
the routine is deleted elsewhere.

**Found by writing [FL-001](../specs/flows/FL-001-start-a-workout.md)**, not by a test or a report.
No ticket from T-001 to T-015 had noticed it; tracing the flow end to end is what exposed the gap
between "the row is listed" and "the row still exists".

## The fix

- A typed `RoutineNotFound` exception, thrown when the lookup returns null. Callers need something
  they can catch and explain; `No element` is not an explanation.
- The shared `startWorkout()` catches it and shows *"That routine no longer exists."* No session is
  created, and every entry point inherits the behaviour because they all route through that function.

## Scope (out)

- Making `deleteTemplate` a soft delete. That would change what a deleted routine means for history
  and duplication, and deserves its own decision.
- Auto-refreshing a stale list. The lists are already stream-backed; this is the race, not a
  staleness bug.

## Files touched

- `lib/features/sessions/data/session_repository.dart` — `RoutineNotFound`, `getSingleOrNull`
- `lib/features/templates/ui/start_workout_action.dart` — catch and report

## Edge cases

- **A half-built session** cannot be left behind: the lookup is the first statement inside the
  transaction, so nothing has been inserted when it throws. Covered by a test.
- **An id that never existed** behaves identically to a deleted one.
- The `ScaffoldMessenger` is captured **before** the first await, since the resume-or-discard dialog
  is an async gap and `ScaffoldMessenger.of` must not cross one.

## Acceptance criteria

- [x] Starting a deleted routine throws `RoutineNotFound`, not `StateError`.
- [x] No session row is created.
- [x] An unknown id behaves the same.
- [x] The UI reports it instead of crashing.
- [x] `flutter analyze` clean; `flutter test` passes (354).

## QA checklist (on device)

**There is no manual reproduction, and the step originally written here was wrong.** It said to open
a routine's detail screen and delete the routine from another surface — but the detail screen is a
pushed route, so reaching another surface means backing out of it, which disposes the very screen
holding the stale Start button.

Two reasons it cannot be hit by hand on one device:

1. Every list that offers a start is **stream-backed**, so deleting a routine re-renders the list
   without it. There is no stale row left to tap.
2. Since [T-013](T-013-workout-tab.md) there is **no way to delete a routine in the UI at all** — see
   [T-017](T-017-restore-routine-delete.md).

The race is real but needs genuine concurrency: a second writer (a restored backup, or a future sync)
removing the row between the list rendering and the tap landing. That is exactly the kind of window
a unit test covers and a human cannot, so the coverage is:

- `test/sessions/missing_routine_test.dart` — the repository throws `RoutineNotFound`, creates no
  session, and behaves the same for an id that never existed.
- `test/widget/routine_play_button_test.dart` — the row is rendered, the routine is deleted
  underneath it, and tapping play reports the message instead of crashing.

- [ ] Optional sanity check, once routine deletion exists again: delete a routine, then confirm no
      surface still offers to start it.

## Note to self

The widget test for this hung on the first attempt because it awaited a Drift stream's `.first`
inside a `testWidgets` body — **the exact trap written up in T-013's "Notes for next time"**. Reading
one's own notes is apparently a separate skill from writing them. The fixture returns the id instead.

The snackbar assertion then needed `tester.runAsync` to let the real repository call complete; the
fake clock does not drive it.

## Revision log
- 2026-08-26 — created and fixed the same day, from FL-001's open question.
