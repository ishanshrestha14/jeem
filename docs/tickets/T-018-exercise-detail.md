# T-018 — Exercise detail screen (S-025)

- **Status:** **Done** (2026-08-26) — `flutter analyze` clean, 368 tests pass.
- **Priority:** Must
- **Effort:** M
- **Specs:** S-025, ADR-004, ADR-006
- **Last updated:** 2026-08-26

## Goal

We hold every set of every lift ever logged, and offered no way to look at one exercise's history.
S-013 is a bottom sheet with description and notes — "how to do it" and nothing else. This is the
largest remaining capability gap now the session loop is done.

## Scope (in)

- A pushed screen at `/exercises/:id/detail` with three panes:
  - **About** — image, description, notes, primary/secondary muscles by name, equipment.
  - **History** — every session that logged this exercise, newest first, with its sets.
  - **Records** — ADR-004's four metrics for this exercise, each with its achieving set.
- Library exercise rows open it; **Edit** moves to its ⋮.

## Scope (out)

- **Progress** pane. Charting is entirely new to this codebase and the gap analysis marks it Later.
- **Leaderboard** pane — social, out of scope per 00-overview §5.
- **Anatomical figures.** We do not reproduce the reference's artwork; muscles are listed by name
  from our own taxonomy (T-005), which is what its own legend does anyway.
- The animated demonstration and the YouTube/Share action chips.
- Delete from the ⋮. Exercise deletion is archiving here (`isArchived`) and behaves differently from
  routine deletion; folding it in without thinking would repeat T-017's mistake in reverse.

## Decisions

- **Three panes, not five** (owner-confirmed 2026-08-26).
- **Tap opens the detail, Edit in ⋮** (owner-confirmed 2026-08-26), the same shape routines got in
  [T-011](T-011-routine-detail.md). Exercises behaving differently from routines is the split that
  caused the T-011/T-013 tangle.
- **The in-session ℹ opens this screen** (owner-confirmed 2026-08-26, after the fact). Shipped in
  T-018 as the S-013 sheet — my assumption, since the question went unanswered — and corrected
  immediately in [T-019](T-019-in-session-info.md). One surface for an exercise everywhere.
- **A session where the exercise was skipped is omitted from History**, not shown blank. A set you
  did not log is not something you did, and a blank row is a puzzle rather than information.

## Files touched

- `lib/features/exercises/domain/exercise_history.dart` (new)
- `lib/features/exercises/ui/exercise_detail_screen.dart` (new)
- `lib/app/router.dart` — the new route
- `lib/features/library/ui/library_screen.dart` — tap target

## Model / DB changes

**None.** Everything shown is already stored or derived.

## Edge cases

- **Never logged** — History says so plainly; Records says "log a set to set your first".
- **Nothing recorded** — About says so rather than rendering an empty screen.
- **A missing image file** falls back to nothing rather than a broken-image box.
- **Deleted while open** — the screen pops.
- **Duration-logged exercises** show their seconds in History rather than weight x reps.
- **An exercise never tagged** shows no muscle rows — untagged is the normal state (ADR-006).

## Acceptance criteria

- [x] Opens on About with the name and description; three tabs present.
- [x] History lists the sessions the exercise appeared in, with its sets.
- [x] History says so when it has never been logged.
- [x] Records shows the heaviest lift, and the achieving set beside it.
- [x] Edit is in the ⋮, not on the surface.
- [x] `flutter analyze` clean; `flutter test` passes (368).

## QA checklist (on device)

- [x] Library → Exercises → tap one → detail opens on About.
- [x] History shows past sessions; a never-done exercise says so.
- [x] Records match the You tab for the same exercise.
- [x] ⋮ → Edit opens the editor and saving returns correctly.
- [x] The ℹ inside a live session opens this screen (changed by T-019).

## Revision log
- 2026-08-26 — created and shipped. Panes and tap target confirmed by the owner; the in-session ℹ
  decision was not answered and is recorded above as an assumption.
