# S-030 — Routine detail

- **Type:** screen
- **Status:** Implemented
- **Source:** reference app
- **Screenshots:** ref-S030-routine-detail.png
- **Last updated:** 2026-08-25

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
   showing the muscles worked. *(Ours: Total sets only — see Open questions.)*
5. **Exercise list** — one row per exercise: thumbnail, name, and a prescription line
   `3 sets · 6 reps · 60kg`.
6. **Start Workout** — full-width, high-emphasis, pinned to the bottom above the system bar.

## Data shown

| Element | Data | Source (our app) | Notes |
|---|---|---|---|
| Name | Routine name | `WorkoutTemplate.name` | |
| Last performed | Relative + absolute date of the last session from this routine | `TemplateSummary.lastPerformedAt` | Already computed for the Library's "Recent" sort |
| Total sets | Count of planned sets across all exercises | `TemplateWithExercises.totalSets` | Row count since schema v6 (T-002) |
| Duration | Estimated minutes | **none** | We do not have this. Would be invented from sets × rest |
| Muscles worked | Anatomical figure | **none** | We have the taxonomy (T-005) but no figure, and the reference's art must not be copied |
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
- **Never performed:** `Never performed` in place of the relative date.

## Edge cases

- **Routine deleted underneath the screen** — the stream emits null; pop rather than render a shell.
- **A session is already running** when Start is pressed — the existing resume-or-discard dialog.
- **An archived exercise** in the routine still lists, since the routine can still be run.
- **A very long routine name** wraps to two lines and ellipsises, as elsewhere.

## Open questions

- [ ] Should the **estimated duration** be shown, and derived how? (sets × rest + a per-set constant?)
- [ ] Should the muscles worked be summarised from **our own taxonomy** (chips or text), given the
      reference's anatomical figure cannot be reproduced?
- [ ] Should **Delete** join Edit in the ⋮ menu? It currently lives only on the Workout tab
      (`workout_screen.dart`), and duplicating it needs a reason beyond the reference having a ⋮.

## Revision log
- 2026-08-25 — created from `ref-S030-routine-detail.png`. Owner decisions: the detail screen becomes
  the routine tap target with Edit demoted to ⋮; header carries total sets and last-performed only;
  exercise rows use the initials tile with the exercise image where one is set.
- 2026-08-25 — built as [T-011](../../tickets/T-011-routine-detail.md). Duration, the muscle figure
  and share remain unbuilt (see Open questions). The Workout tab still routes a routine tap to the
  editor and was left untouched, so it is now inconsistent with the Library and programs.
