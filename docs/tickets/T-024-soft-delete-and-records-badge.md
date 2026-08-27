# T-024 — Soft-delete routines, and the `Records 🏅 N` badge

- **Status:** **Done** (2026-08-27) — `flutter analyze` clean, 414 tests pass.
- **Priority:** Should
- **Effort:** M
- **Specs:** S-001, S-030, ADR-004, FL-001
- **Last updated:** 2026-08-27

Both deferred decisions, answered by the owner 2026-08-27 and built together.

## 1. `deleteTemplate` is now a soft delete

**Decision:** soft (owner-confirmed).

A routine is what your logged history was built from, which made this the one genuinely destructive
delete in the app. Sessions snapshot the routine, so history was never at risk — but the routine
itself was unrecoverable, and it was the root of the race
[T-016](T-016-missing-routine.md) had to defend against.

Every query that reads routines already filtered `deletedAt` — `watchSummaries`, `watchTemplate`,
the programs join, `startFromTemplate` — so one write removes it everywhere. **T-016's defence still
holds**: a filtered-out row is as absent as a dropped one, so starting a deleted routine still
throws `RoutineNotFound` rather than crashing.

### Two consequences that needed deciding, not patching

- **An abandoned draft is still hard-deleted.** The editor discards a blank, unnamed, exercise-less draft on the way out. Soft-deleting those would accumulate invisible rows forever — one per time anybody opened the editor and changed their mind. That path now calls a separate `discardDraft`, and the distinction is the point: a draft is litter, a routine is history.
- **Child rows are deliberately kept.** The hard delete cascaded to `templateExercises`; the soft one does not, because if a routine is ever restorable its exercises must still be there. Nothing can reach them — every query goes through the template. The DAO test now asserts *unreachability*
  rather than row absence, which is what it always meant.

## 2. `Records 🏅 N` on Home's workout rows

**Decision:** a record counts against **all** history (owner-confirmed) — the badge means *"this
session still holds a best"*, not *"this was a best at the time"*. A workout whose record has since
been beaten shows nothing, so **the number can fall as you get stronger**, which is the correct
reading of "personal record".

### Counted per exercise, not per metric

My call, not the owner's. One heavy set commonly sets the heaviest weight, the best estimated 1RM
*and* the most reps at once; counting metrics would render that as `Records 3` for a single lift.
One exercise, one badge.

### A surprise worth knowing, pinned by a test

`mostReps` ignores weight (ADR-004). So a **light** session that ties your best rep count holds that
record on the tie and earns a badge. That looks wrong at a glance, but silently demoting ties would
make this badge disagree with the You tab, which shows the same record. Recorded in
`records_set_in_test.dart` rather than left to be rediscovered.

Zero hides the badge: most workouts set no record, and a `0 records` line on every row would be
noise.

## Files touched

- `lib/features/templates/data/template_repository.dart` — soft `deleteTemplate`, new `discardDraft`
- `lib/features/templates/ui/template_editor_screen.dart` — drafts use `discardDraft`
- `lib/features/records/data/personal_records.dart` — `recordsSetIn`
- `lib/features/dashboard/ui/home_screen.dart` — the badge

## Model / DB changes

**None.** `deletedAt` already existed on every table via `SyncColumns`.

## Acceptance criteria

- [x] Deleting a routine keeps the row, stamped `deletedAt`.
- [x] It leaves the routine list, cannot be opened, and drops out of programs.
- [x] Starting it still throws `RoutineNotFound`.
- [x] Workouts already logged from it are untouched.
- [x] An abandoned draft is still removed outright.
- [x] A workout holding a standing record shows the badge; one whose record was beaten does not.
- [x] Ties on reps count, and are pinned by a test.
- [x] `flutter analyze` clean; `flutter test` passes (414).

## QA checklist (on device)

- [x] Delete a routine you have logged workouts from — history keeps them.
- [x] Home shows 🏅 on a workout that set a record; beat it and the badge moves.
- [x] Open and back out of a new routine without typing — no empty routine appears.

## No restore path — decided, not overlooked

Routines are recoverable in the database and **nothing surfaces them**, so from the user's seat
deleting still looks exactly like a hard delete. The owner raised this while testing and chose to
**leave it as is** (2026-08-27).

Worth stating the honest cost, so a later session does not "fix" it by accident: the benefits of soft
delete are currently all invisible — a restorable row, T-016's race defused, history keeping its
referential context. None is user-facing. Options weighed and declined: an undo snackbar on delete
(cheap, catches the accidental case), a "Recently deleted" list in the Library (handles regret a week
later), or reverting to a hard delete.

If it is ever picked up, the undo snackbar is the one worth doing first: accidental deletion is the
overwhelmingly common case, and it needs no new surface.

## Revision log
- 2026-08-27 — created and shipped; both deferred decisions answered by the owner.
