# FL-003 — Finish a workout

- **Status:** Draft
- **Surfaces involved:** S-015 (active session), S-018 (session summary), S-019 (history)
- **Last updated:** 2026-08-26

## Trigger

`Finish` in the active session's app bar.

## Preconditions

A session is running. It need not be complete.

## Happy path

1. Every set is complete, so nothing is asked.
2. `/session/summary/:id` is pushed.
3. The user reviews and taps **Save**.
4. `ActiveSessionController.finish` commits: `status: completed`, `endedAt` stamped.
5. The workout appears in the Workout tab's day list, Home's recent workouts, History, the week
   strips, and is counted by the weekly summary, personal records and `Previous`.

## Alternate paths

**Sets still incomplete.** A dialog naming how many remain offers:
- *Continue workout* — returns, nothing changes.
- *Finish anyway* — pushes the summary as above.
- *Discard session* — a second, destructive confirmation; on yes, `cancelSession` marks it cancelled
  and the screen pops itself.

**Backing out of the summary.** The session is **not** committed at step 2 — `finish` is only called
from the summary's Save. Backing out returns to a live session rather than losing it.

**Deleting it afterwards.** A completed workout can be removed from the Workout tab's day card or the
History row menu — see [FL-004](FL-004-delete-a-workout.md).

## Error paths

- Dismissing either dialog cancels the finish and leaves the session running.

## Data changes

| Step | Table | Mutation | Persisted when |
|---|---|---|---|
| 4 | `workoutSessions` | `status: completed`, `endedAt` | on Save |
| Discard | `workoutSessions` | `status: cancelled`, `endedAt`, rest cleared | on confirm |

Nothing is written between pressing Finish and pressing Save.

## UI states

- **Complete** — straight to the summary.
- **Incomplete** — the three-way dialog.
- **Discarding** — a destructive confirmation on top of it.

## Acceptance criteria

- [x] A complete session goes straight to the summary.
- [x] An incomplete one names the remaining sets and offers all three choices.
- [x] Backing out of the summary leaves the session live and uncommitted.
- [x] Discard requires a second confirmation.
- [x] A saved session reaches history, records and the weekly summary.

## Open questions

- [ ] S-023's finish form (title, notes, visibility) and S-024's celebration/share are unbuilt. Our
      summary screen is the counterpart; neither has been specced against it.

## Revision log
- 2026-08-26 — derived from the implementation as part of closing the §6 gap.
