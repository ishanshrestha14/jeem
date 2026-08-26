# FL-002 — Log a set

- **Status:** Draft
- **Surfaces involved:** S-015 (active session), S-014 (exercise picker), S-021 (rest sheet), CMP-015, CMP-018
- **Last updated:** 2026-08-26

## Trigger

A session is running and has at least one exercise.

## Preconditions

- An exercise with at least one set. An ad-hoc session starts with none — see *Adding an exercise*.

## Happy path — a set that goes to plan

1. The current exercise's card is expanded; its first pending set row is the current target
   (`surfaceHigh` background, 3px chalk leading bar, a writing line under its numeric cells).
2. The row shows the routine's plan **muted** in `KG` and `REPS` — `60`, `8-10` (T-008). This is a
   hint, not a value: nothing is written yet.
3. The user taps ✓.
4. Any still-empty logged column is filled from the plan — a rep range logs its **lower bound** — and
   `completedAt` is stamped, in one write.
5. The row washes chalk at 5% (T-010) and its ✓ becomes a filled disc.
6. Rest starts for that exercise's `restSeconds`, the rest bar appears, and an OS notification is
   scheduled for when rest ends.
7. When rest finishes (or is skipped), focus advances to the next pending set — the next set of this
   exercise, else the first set of the next pending exercise.

A set that goes to plan is therefore **one tap and no typing**.

## Alternate paths

**Typing a value.** Tapping a numeric cell raises the in-app keypad (CMP-018), not the system
keyboard — the field is `readOnly` so the OS keyboard stays down. `Next` commits and advances
weight → reps → the following set's weight. `RIR` opens the RIR picker for the focused set. `.` is
offered for weight and withheld for reps. A typed value always wins: step 4 fills only empty columns.

**Rest of zero seconds.** No timer starts; focus advances immediately.

**Adjusting rest.** `+15s` / `-15s` / pause / skip from the rest bar or the expanded sheet (S-021).

**Adding an exercise** (T-012, CMP-004). **Add exercises** — below the last card, or centred in the
void on an empty ad-hoc session — opens the picker (S-014). The chosen exercise is **appended** with
one empty set and no prescription, and becomes the current target if nothing else is pending.
Cancelling the picker changes nothing.

**Reordering.** `Do later` sends the current exercise behind every other pending one, with an inline
undo. `Do next` pulls a later exercise to the front.

**Un-completing.** Tapping ✓ again clears `completedAt`. Values materialised in step 4 **stay** —
once logged they are real numbers to edit or clear, and silently un-writing them would lose an edit
made after the tap.

## Error paths

- Haptics, sound or the notification channel throwing does not abort the write: every side effect is
  wrapped so the mutation still reaches `_emit`.
- A `shared_preferences` read failing falls back to the setting's own default.

## Data changes

| Step | Table | Mutation | Persisted when |
|---|---|---|---|
| 4 | `sessionSets` | `completedAt`, plus `weight`/`reps` if empty | on tap |
| Typing | `sessionSets` | the edited column | on each debounced change |
| 6 | `workoutSessions` | `restStatus`, `restEndsAt`, `restAfterSetId` | when rest starts |
| Adding | `sessionExercises` + `sessionSets` | one exercise, one empty set, appended | on pick |

Rest state is persisted, so a session survives the process being killed mid-rest.

## UI states

- **Pending** — muted plan hint, outlined ✓ ring.
- **Current** — `surfaceHigh`, leading bar, writing line.
- **Complete** — chalk wash, filled ✓ disc, dimmed set number; values stay editable (PRD §17).
- **Resting** — rest bar above the keypad; both can be up at once.

## Acceptance criteria

- [x] A planned set is logged with one tap and no typing.
- [x] A rep range logs its lower bound.
- [x] A typed value is never overwritten by the plan.
- [x] A set with no plan completes with empty values, as before T-008.
- [x] Completing starts rest and schedules its notification; zero rest advances immediately.
- [x] An exercise can be added mid-session and is appended.
- [x] Un-completing keeps the logged values.

## Open questions

- [ ] What is in the per-exercise ⋮ menu? Removing an exercise from a live session has no home yet.
- [ ] Should `Previous` become a per-row column? That needs RIR to move onto the keypad first.

## Revision log
- 2026-08-26 — derived from the implementation (T-003, T-008, T-009, T-010, T-012) as part of
  closing the §6 gap.
