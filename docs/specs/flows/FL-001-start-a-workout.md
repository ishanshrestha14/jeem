# FL-001 — Start a workout

- **Status:** Draft
- **Surfaces involved:** S-003 (Workout tab), S-004 (Library), S-030 (routine detail), S-001 (Home), S-015 (active session)
- **Last updated:** 2026-08-26

## Trigger

Any of five entry points, all landing in the same place:

| From | Control | Starts |
|---|---|---|
| S-003 Workout tab | FAB `Start new workout` | ad-hoc |
| S-003 Workout tab | `Start new workout` / `Log another workout` row | ad-hoc |
| S-003 Workout tab | play button on a suggested routine | that routine |
| S-004 Library | play button on a routine row | that routine |
| S-030 routine detail | `Start workout` | that routine |
| S-001 Home | first-run card `Start workout` | ad-hoc |

Routine starts go through `startWorkout()`; ad-hoc through `startAdHocWorkout()`. Both share
`_resolveRunningSession`, so the already-running case behaves identically wherever you began.

## Preconditions

- For a routine start: the routine has at least one exercise (`canStart`). S-030 disables its button
  otherwise; the play buttons do not, since a routine row with no exercises is rare and the detail
  screen is one tap away.
- No precondition for an ad-hoc start.

## Happy path

1. User activates one of the controls above.
2. No session is running, so nothing is asked.
3. **Routine:** `startFromTemplate` snapshots the routine — its exercises, their rest, and every
   planned set's weight/reps/range/RIR/duration onto `SessionSets.planned*` (T-002).
   **Ad-hoc:** `startAdHoc` creates a session named `Workout` with no template and no exercises.
4. The notification-permission prompt is offered if it has not been (S-022).
5. `/session` is pushed — a full-screen route on the root navigator, sliding up from the bottom.

## Alternate paths

**A session is already running.** A dialog offers:
- *Resume the running session* — pushes `/session` for the **existing** session; the new one is never
  created.
- *Discard it and start this one* — `cancelSession` marks the old one cancelled, then the new session
  starts as above.
- Dismissing the dialog does nothing at all.

**Ad-hoc with nothing in it.** The session opens on S-006's empty state — stats box, then
**Add exercises** over **More**. See [FL-002](FL-002-log-a-set.md).

## Error paths

- **The routine was deleted between listing and starting.** `deleteTemplate` is a hard delete, so the
  row is gone. `startFromTemplate` throws a typed `RoutineNotFound`, which the shared
  `startWorkout()` catches and reports as *"That routine no longer exists."* No session is created.
  Fixed in [T-016](../../tickets/T-016-missing-routine.md); before it, this was an unhandled
  `StateError: No element`.
- Notification permission denied: the session starts regardless; only rest notifications are lost.

## Data changes

| Step | Table | Mutation | Persisted when |
|---|---|---|---|
| 3 | `workoutSessions` | insert, `status: active` | immediately |
| 3 (routine) | `sessionExercises` | one row per routine exercise, snapshotted by value | immediately |
| 3 (routine) | `sessionSets` | one row per planned set, `planned*` filled, logged columns null | immediately |
| Alternate | `workoutSessions` | old session `status: cancelled` | before the new insert |

Everything is committed inside one transaction per session, so a half-built session cannot exist.

## UI states

- **Starting** — no spinner; the insert is fast and local.
- **Session already running** — the resume-or-discard dialog.
- **Landed** — S-015, with the first pending set focused (or the empty state, ad-hoc).

## Acceptance criteria

- [x] Every entry point starts the same kind of session and lands on `/session`.
- [x] A routine start snapshots the plan; editing the routine afterwards does not alter the session.
- [x] An ad-hoc session has no template and is named `Workout`.
- [x] Starting while a session runs always asks, from every entry point.
- [x] Dismissing that dialog starts nothing.

## Open questions

- [x] What should happen if the routine is deleted between listing and starting? Resolved by
      [T-016](../../tickets/T-016-missing-routine.md): a typed `RoutineNotFound`, explained in the UI.
- [ ] Should a play button be disabled for a routine with no exercises, as S-030's button is?

## Revision log
- 2026-08-26 — derived from the implementation (T-011, T-012, T-013) as part of closing the §6 gap.
- 2026-08-26 — the deleted-routine crash this spec surfaced is fixed ([T-016](../../tickets/T-016-missing-routine.md));
  the error path and its open question updated.
