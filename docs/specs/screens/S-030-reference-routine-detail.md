# S-030 — Routine detail

- **Type:** screen
- **Status:** Implemented
- **Source:** reference app
- **Screenshots:** ref-S030-routine-detail.png
- **Last updated:** 2026-08-27

## Purpose

A read-only view of one routine: what it contains, when you last did it, and a single large button
to start it. It is the surface between *finding* a routine and *doing* it — the step our app has
never had, because tapping a routine has always opened the editor.

The ratio matters: you start a routine many times for every time you edit it, so starting is the
screen's primary action and editing is demoted to the overflow menu.

## Entry points

- Tapping a routine row in the Library tab (S-004)
- Tapping a routine row inside a program (S-004 → program)

## Layout & sections

1. **Top bar** — back, share, ⋮. *(Ours: back and ⋮ only; share is out of scope.)*
2. **Name** — the routine's name, large, with a chevron to expand *(reference: expands to a
   description; ours has no description field, so no chevron.)*
3. **Last performed** — `Last performed: 2 days ago` over the absolute date.
4. **Stats tile** — a bordered row: `Total Sets 15` · `Duration ~40 min` · an anatomical figure
   showing the muscles worked. *(Ours: two stat columns — total sets and duration — with the body
   parts on their own full-width line beneath, inside the same border. No figure; see below.)*
5. **Exercise list** — one row per exercise: thumbnail, name, and a prescription line
   `3 sets · 6 reps · 60kg`.
6. **Start Workout** — full-width, high-emphasis, pinned to the bottom above the system bar.

## Data shown

| Element | Data | Source (our app) | Notes |
|---|---|---|---|
| Name | Routine name | `WorkoutTemplate.name` | |
| Last performed | Relative + absolute date of the last session from this routine | `TemplateSummary.lastPerformedAt` | Already computed for the Library's "Recent" sort |
| Total sets | Count of planned sets across all exercises | `TemplateWithExercises.totalSets` | Row count since schema v6 (T-002) |
| Duration | Estimated minutes | `TemplateRepository.recentDurations`, else the plan | Measured from real sessions where there are any, estimated from the plan where there are not — see below (T-025) |
| Muscles worked | Anatomical figure | `ExerciseBodyParts` via `bodyPartsByExerciseProvider` | Our own taxonomy in words. No figure: the reference's art must not be copied (T-025) |
| Exercise thumbnail | Image per exercise | `Exercise.imagePath`, else CMP-011 initials tile | Most exercises have no image, so the tile is the default, not the fallback |
| Prescription line | `3 sets · 6 reps · 60kg` | `TemplateExerciseWithExercise.sets` | Aggregated across the planned sets — see below |

### The prescription line

The reference shows one line per exercise, not per set. Ours aggregates the planned sets:

- **Count** always: `3 sets` (`1 set` singular).
- **Reps**, when any set has them: the span across all sets and both bounds — `6 reps`, `6-8 reps`,
  `6-10 reps` where the sets themselves differ.
- **Weight**, when any set has it: the same span rule — `60kg`, `60-80kg`.
- **Duration-logged** exercises show their seconds instead of reps/weight: `3 sets · 45s`.
- An exercise with no prescription at all shows only its set count.

Spans rather than "varied" because the numbers are the point: a routine that ramps 60→80kg should
say so on the row you are reading before you start.

### The duration

Two branches, and the screen says which one you are looking at rather than hiding it:

- **Measured** — the mean of up to the **last 3 completed sessions** from this routine, captioned
  `your average`. `endedAt − startedAt − pausedSeconds`, the same arithmetic as the live session
  header, so the two agree.
- **Estimated** — from the plan, captioned `estimated`, only while the routine has never been
  performed. Each planned set costs its work plus that exercise's `restSeconds`, and the routine's
  final set drops its rest. Work is the set's own seconds for a duration-logged exercise, else a
  **45-second constant — the one invented number on this screen.**

Measured wins on a single session: one real run says more about what a routine costs than a formula
does, so the invented constant is visible only until the first time you do the routine.

Both render as `~52 min`. The tilde carries the imprecision, so neither branch rounds to a
false-looking multiple of five.

### The body-part line

The union of the body parts of every exercise in the routine, deduped, in **enum declaration order**
(`Chest · Back · Shoulders · Arms · Core · Legs …`) so one routine always reads the same way and two
are comparable at a glance. Body parts rather than primary muscles: the coarse axis is already
streamed in bulk for the library, and it keeps the vocabulary identical to T-021's filter.

Deliberately not `bodyPartsSubtitle`, which sorts alphabetically and caps at two — that helper exists
to stop a narrow list row changing height, and the tile is full-width.

## Primary actions

| Action | Result | Destination |
|---|---|---|
| **Start Workout** | Starts a session from this routine | S-015 (active session) |

Goes through the existing `startWorkout()`, so an already-running session offers resume-or-discard
exactly as it does from every other entry point.

## Secondary actions

| Action | Result |
|---|---|
| ⋮ → **Edit** | Opens the routine editor (S-009) |
| Back | Returns to wherever you came from |

## Components used

- CMP-011 — initials tile
- CMP-025 — exercise card *(the row shape)*

## Navigation out

- Start Workout -> S-015
- ⋮ Edit -> S-009
- Back -> S-004 or the program

## States

- **Empty:** a routine with no exercises — the list is replaced by an empty state, and
  **Start Workout is disabled** (`TemplateWithExercises.canStart` is already false).
- **Loading:** a spinner while the routine streams in.
- **Error:** routine not found (deleted while the screen was open) — pop back.
- **Success:** as drawn.
- **Never performed:** `Never performed` in place of the relative date, and the duration reads
  `estimated` rather than `your average`.
- **Nothing to say:** each stat slot disappears when it is empty. A routine with no sets shows no
  duration (`~0 min` reads as broken); a routine of untagged exercises shows no body-part line. Both
  empty leaves the tile as the single centred `Total sets` column it was before T-025.

## Edge cases

- **Routine deleted underneath the screen** — the stream emits null; pop rather than render a shell.
- **A session is already running** when Start is pressed — the existing resume-or-discard dialog.
- **An archived exercise** in the routine still lists, since the routine can still be run.
- **A very long routine name** wraps to two lines and ellipsises, as elsewhere.
- **A session left running for hours** still counts toward the average. T-020 lets the user edit the
  duration on the finish form, so an odd number is one they chose to keep; only a non-positive
  duration is dropped, as corrupt.
- **Deleting a logged workout** (T-014) removes it from the average, which is what deleting it
  should mean. Deleting the only one returns the routine to `estimated`.

## Open questions

- [x] Should the **estimated duration** be shown, and derived how? **Yes** — resolved by
      [T-025](../../tickets/T-025-routine-stats.md). Not sets × rest alone: measured from real
      sessions wherever there are any, with the formula as the never-performed fallback. A
      formula-only stat would be an invention that never gets truer; a measured-only stat would go
      missing precisely on the new routine you most want to size up.
- [x] Should the muscles worked be summarised from **our own taxonomy** (chips or text)? **Yes,
      as text** — resolved by [T-025](../../tickets/T-025-routine-stats.md). Body parts, not
      muscles. Chips were rejected: a chip implies a tap, and nothing here taps.
- [x] Should **Delete** join Edit in the ⋮ menu? **Yes** — resolved by
      [T-017](../../tickets/T-017-restore-routine-delete.md). The premise of the original deferral
      ("it already lives on the Workout tab") was invalidated when T-013 retired that tab, leaving
      Delete and Duplicate with no home at all. Both now sit beside Edit.

## Revision log
- 2026-08-25 — created from `ref-S030-routine-detail.png`. Owner decisions: the detail screen becomes
  the routine tap target with Edit demoted to ⋮; header carries total sets and last-performed only;
  exercise rows use the initials tile with the exercise image where one is set.
- 2026-08-25 — built as [T-011](../../tickets/T-011-routine-detail.md). Duration, the muscle figure
  and share remain unbuilt (see Open questions). The Workout tab still routes a routine tap to the
  editor and was left untouched, so it is now inconsistent with the Library and programs.
- 2026-08-27 — both remaining open questions closed by
  [T-025](../../tickets/T-025-routine-stats.md): the stats tile gains a measured-or-estimated
  duration and a body-part line. The anatomical figure stays unbuilt, now as a recorded decision
  rather than an open question — the reference's art must not be copied, and our taxonomy says the
  same thing in words.
