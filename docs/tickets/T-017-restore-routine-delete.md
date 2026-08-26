# T-017 — Restore routine Delete and Duplicate

- **Status:** **Done** (2026-08-26) — `flutter analyze` clean, 357 tests pass.
- **Priority:** Must
- **Effort:** S
- **Specs:** S-030
- **Last updated:** 2026-08-26

## The regression

Before [T-013](T-013-workout-tab.md), the Workout tab's routine cards carried **Edit · Duplicate ·
Delete**. T-013 replaced that screen with S-003's day launchpad and retired the card. Edit had
already moved to the routine detail ⋮ in [T-011](T-011-routine-detail.md).

**Duplicate and Delete moved nowhere.** For four commits there was no way to delete or duplicate a
routine anywhere in the app.

## How it happened, which is the part worth keeping

T-011 explicitly *declined* to put Delete in the routine detail ⋮ menu. Its reasoning, quoted from
the ticket:

> **Delete** in the ⋮ menu — it already lives on the Workout tab; duplicating it needs its own reason.

That was correct when written. T-013 then deleted the Workout tab, listing "the routine list, and its
Edit/Duplicate/Delete menu" among the things it retired — and nobody went back to check whether the
premise of T-011's deferral still held. The ticket even enumerated its *retired tests* carefully while
missing that two user-facing actions had lost their only home.

**The lesson:** a decision deferred *because another surface already covers it* has a dependency on
that surface. When the surface goes, the deferral has to be re-opened. Nothing in the process
surfaced that link — it was recorded in prose in one ticket and silently invalidated by another.

**How it was found:** not by a test — the test suite stayed green throughout — and not by review. The
owner questioned a QA step in [T-016](T-016-missing-routine.md) that told them to delete a routine
from another surface while a detail screen stayed open. Trying to follow it exposed both that the
step was impossible *and* that the capability it assumed was gone.

## The fix

`Duplicate` and `Delete` join `Edit` in the routine detail's ⋮ menu (owner-confirmed 2026-08-26),
which is the surface dedicated to a single routine. S-030 had already flagged this as an open
question.

- **Delete** confirms first, then hard-deletes and pops the screen. The copy says what is *not*
  affected: *"Sessions you have already logged from it are not affected — they keep their own copy of
  what you did."* True, because a session snapshots the routine at start (T-002), and worth saying —
  the fear when deleting a routine is losing the history attached to it.
- **Duplicate** copies the routine with its full prescription and confirms with a snackbar naming the
  copy.

## Scope (out)

- A Delete on the Library row. One place to manage a routine; two would be the duplication the last
  several tickets removed.
- Making `deleteTemplate` soft. Still open — see T-016.

## Files touched

- `lib/features/templates/ui/routine_detail_screen.dart`

## Edge cases

- **Backing out of the confirmation** changes nothing.
- **Deleting the routine you are looking at** pops the screen; the stream would emit null and pop it
  anyway, but popping directly keeps it immediate.
- **Logged sessions survive** a routine's deletion, by design.
- **A duplicated routine keeps every planned set's numbers**, which is the point of duplicating.

## Acceptance criteria

- [x] The ⋮ menu offers Edit, Duplicate and Delete.
- [x] Delete confirms; backing out keeps the routine.
- [x] Duplicate produces a second routine carrying the prescription.
- [x] `flutter analyze` clean; `flutter test` passes (357).

## QA checklist (on device)

- [ ] Library → open a routine → ⋮ → Duplicate; the copy appears in the Library.
- [ ] ⋮ → Delete → confirm; the screen closes and the routine is gone.
- [ ] A workout logged from that routine is still in History afterwards.

## Revision log
- 2026-08-26 — created and fixed after the owner's question about T-016's QA steps exposed it.
