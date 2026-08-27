# T-023 — `Recent Performed` leads the mid-session picker (S-026)

- **Status:** **Done** (2026-08-27) — `flutter analyze` clean, 399 tests pass.
- **Priority:** Should
- **Effort:** S
- **Specs:** S-026, S-014, S-015
- **Last updated:** 2026-08-27

## Goal

The follow-up [T-021](T-021-body-part-filter.md) deliberately left out. S-026: opened from a live
session the picker's leading section becomes **`Recent Performed`** rather than the alphabetical
library, because *mid-set what you want is almost always something you have done before*.

The spec also notes it is cheap for us — we already have the session history to sort by — and that turned out to be exactly right: [T-018](T-018-exercise-detail.md) had already built the pass over
completed sessions this needed.

## Scope (in)

- `recentlyPerformedExerciseIds` — library ids ordered by most recent actual performance, deduped.
- `showExercisePickerSheet(..., recentFirst: true)`, rendering `Recent` then `All exercises`.
- Wired at the one call site that reasoning was written for: **Add exercises inside a live session**.

## Decisions

- **Only mid-session.** Building a routine is not mid-set, so the picker stays alphabetical there. A
  section that appears *sometimes* is harder to learn than one that appears for a reason.
- **Suppressed while searching.** Once a query is typed you are looking for a specific thing, and
  reordering around recency would fight the search.
- **"Performed" means a set was logged**, matching `exerciseHistory`. An exercise you loaded into a
  session and skipped is not something you did.
- **A snapshot with no `exerciseId` is skipped.** The picker offers library rows; there is no row for
  it to point at.
- **No section headers at all when nothing has been performed.** An empty `Recent` header would be
  noise on a first workout.

## Scope (out)

The rest of S-026 stays unbuilt and is not a gap so much as a different design: the grid/list toggle,
per-card bookmark and `?` affordances, and `+` inside the picker (ours is a full row at the top,
which does the same job).

## Files touched

- `lib/features/exercises/domain/exercise_history.dart` — `recentlyPerformedExerciseIds`
- `lib/features/exercises/ui/exercise_picker_sheet.dart` — `recentFirst` and the sections
- `lib/features/sessions/ui/active_session_screen.dart` — passes it

## Model / DB changes

**None.**

## Edge cases

- **Nothing performed yet** — no headers, plain alphabetical list.
- **Searching** — recency suppressed.
- **An exercise performed twice** appears once, at its most recent position.
- **A performed exercise since deleted** is skipped: it is matched against the library rows on
  screen, so an id with no row simply does not appear.

## Acceptance criteria

- [x] Mid-session, a performed exercise sorts above an alphabetically-earlier unperformed one.
- [x] Elsewhere the picker stays alphabetical, with no `Recent` header.
- [x] With nothing performed there is no `Recent` header.
- [x] Ordering is by most recent performance, deduped.
- [x] `flutter analyze` clean; `flutter test` passes (399).

## QA checklist (on device)

- [x] Log a workout, start another, tap **Add exercises** — what you just did is at the top.
- [x] Type a search inside that picker — the sections disappear and results are plain.
- [x] Open the picker from the routine editor — no `Recent` section.

## Revision log
- 2026-08-27 — created and shipped.
