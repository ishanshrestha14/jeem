# S-028 — "Create Routine" (reference app)

- **Type:** screen (full-screen modal — `✕`, not a back arrow)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** S-009 (ours, `template_editor_screen.dart`)
- **Screenshots:** `ref-S028-create-routine-empty.png`, `-collapsed.png`, `-expanded.png`
- **Last updated:** 2026-08-23

## Purpose

Build the routine: name it, and prescribe what you intend to lift. This is where the numbers that
pre-fill a live session come from — the missing half of [T-002](../../tickets/T-002-prescription-schema.md).

## Layout

Top bar: **`✕`** · title `Create Routine` · **`Save`** (dim until the routine has a name).

### Empty (`-empty.png`)
`Routine title…` and `Notes…` as large inline placeholders — no boxes, no labels — then a
full-width white **`Add exercises`** button. Nothing else. The screen is the routine.

### With exercises, collapsed (`-collapsed.png`)
One row per exercise: thumbnail, name, then **its prescribed sets listed underneath**:

```
Barbell Deadlift front view
1   70kg x 8 reps
2   60kg x 6 reps
```

An exercise with nothing prescribed reads **`Press to add details`** instead. So the collapsed list
doubles as the summary of the whole plan — you can read a routine without opening anything.

### Expanded (`-expanded.png`)
Tapping an exercise opens it in place, revealing exactly the session's layout:

- `Notes…`
- **`⏱ Rest Timer: 3min`**
- A set table: **`Set · Previous · Kg · Reps ▾`**
- **`+ Add Set`**

## The finding: prescription is **per set**, not per exercise

The two sets read `70 kg × 8` and `60 kg × 6`. They differ. A routine does not carry one weight and
one rep target applied to every set — **each set carries its own**, which is how a top set followed
by back-off sets is expressed at all.

T-002 was planned as `defaultWeight` / `targetReps` / `targetRepsMax` columns on
`TemplateExercises` — one prescription per exercise. That cannot express this screen. The ticket has
been corrected: prescription needs a **row per planned set**.

Two more details from the same table:

- **`Previous` appears in the editor**, not just in a live session — you plan next week's numbers
  with last week's in front of you.
- **`Reps ▾` carries a dropdown caret** in the column header. That is the reps-vs-range mode toggle,
  set per exercise rather than per set — consistent with what the owner described.

## Data shown

| Element | Data | Our source | Notes |
|---|---|---|---|
| Title, Notes | routine name + notes | `WorkoutTemplates.name`, `.notes` | exists |
| Rest timer | per-exercise rest | `TemplateExercises.restSeconds` | exists |
| Set rows | **per-set** weight + reps | **missing** | T-002 |
| Reps mode | reps vs. range | **missing** | T-002 |
| Previous | last session's result | **missing** | shared with S-006 |

## Open questions

- [ ] Does `Save` discard on `✕`, or keep a draft?
- [ ] Is `Previous` here the same "best set of last session" as S-006, or the same set index?

## Revision log
- 2026-08-23 — created; corrected T-002's schema from per-exercise to per-set prescription.
