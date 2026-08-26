# FL-004 — Delete a logged workout

- **Status:** Draft
- **Surfaces involved:** S-003 (Workout tab), S-019 (history)
- **Last updated:** 2026-08-26

## Trigger

⋮ → **Delete** on a logged workout, from the Workout tab's day card or a History row.

## Preconditions

The session is completed. A *running* session is discarded instead — see
[FL-003](FL-003-finish-a-workout.md).

## Happy path

1. User picks **Delete**.
2. A destructive confirmation: *"Delete this workout? Its sets, and any records it set, will be
   removed from your history."*
3. On confirm, `deleteSession` stamps `deletedAt`.
4. The workout disappears from every derived surface at once.

## What "at once" means

`_fetchCompletedSessions` filters `deletedAt.isNull()`, and **everything below is derived from that
list rather than stored** — so one write removes the workout from all of them:

| Surface | Effect |
|---|---|
| History (S-019) | row gone |
| Workout tab day list (S-003) | gone; if it was the day's only one, the empty state and suggestions return |
| Home (S-001) | gone from recent workouts; the weekly summary and its deltas re-derive |
| Week strips (CMP-020) | that day's dot may clear |
| Personal records (ADR-004) | records it set **hand back to the next best** |
| `Previous` (T-009) | falls back to the next most recent session containing the exercise |

The record consequence is why the confirmation names it: it is correct, but otherwise invisible.

## Alternate paths

- Backing out of the confirmation changes nothing.
- Deleting an already-deleted or unknown id is a no-op, not an error — the menu may be acting on a
  row removed elsewhere.

## Error paths

None. The write cannot partially apply.

## Data changes

| Step | Table | Mutation | Persisted when |
|---|---|---|---|
| 3 | `workoutSessions` | `deletedAt`, `updatedAt` | on confirm |

**Soft**: the row and its sets survive in the database. Not the app's universal pattern —
`deleteTemplate` and `removeSet` drop rows outright — but a session is the only record that a
workout happened, so it is kept. Nothing in the
UI surfaces them again.

## UI states

- **Menu open** — Delete always present; Duplicate only when the workout's routine still exists.
- **Confirming** — destructive dialog.
- **Deleted** — the list re-renders without it; no snackbar, no undo.

## Acceptance criteria

- [x] Deletable from both the Workout tab and History.
- [x] Confirmation required; backing out keeps the workout.
- [x] Soft-deleted, not dropped.
- [x] Records and volume re-derive without it.
- [x] An ad-hoc workout, which has no routine, is still deletable.

## Open questions

- [ ] Should a deleted workout be recoverable? The row survives, but nothing surfaces it. An undo
      window was rejected in T-014 as too easy to miss for something this destructive.

## Revision log
- 2026-08-26 — derived from the implementation (T-014) as part of closing the §6 gap.
