# S-026 — Exercise browser / picker (reference app)

- **Type:** screen (full-screen modal — opened with `✕`, not a back arrow)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** S-011 (`exercise_list_screen.dart`) and S-014 (`exercise_picker_sheet.dart`)
- **Screenshots:** `ref-S026-exercise-browser-picker.png`, `ref-S026-add-exercises-mid-session.png`
- **Last updated:** 2026-08-23

## Purpose

Find an exercise — to add to a routine, to add mid-session, or just to read about. The `✕` and the
`+` mark it as a modal picker rather than a browsing destination, but it is the same surface reached
from Explore's muscle grid (S-002).

## Two entry contexts, one surface

- **From Library/Explore** — titled `Exercises` (`ref-S026-exercise-browser-picker.png`)
- **From a live session** — titled **`Add Exercises`** (`ref-S026-add-exercises-mid-session.png`),
  and the first section becomes **`Recent Performed`** rather than `All Exercises`

Same chrome, same cards, same filter strip — only the title and the leading section change. Mid-set,
what you want is almost always something you have done before, so recency beats alphabetical. Cheap
for us: we already have session history to sort by.

## Layout

1. **Top bar** — `✕` · title `Exercises` · **search** · **filter** (with a **badge showing the active
   filter count**, `1`) · **`+`** (create a new exercise)
2. **Muscle filter strip** — horizontally scrolling. The **first chip is a bookmark = Favourites**,
   then one chip per muscle group, each a small anatomical figure with the muscle tinted red. The
   selected chip is outlined
3. **`All Exercises`** + a **layout toggle** (grid ⇄ list) on the right
4. **Card grid**, 2 columns. Each card: **bookmark toggle** (top-left) · **`?` info affordance**
   (top-right) · illustration · **name** · **muscle group** as a subtitle

## Patterns worth taking

- **Favourites as the first filter chip**, sitting inside the same strip as the muscle groups rather
  than in a separate control. One row does two jobs.
- **A filter badge** showing how many filters are active — cheap, and it stops invisible filtering
  from being confusing when a search returns almost nothing.
- **Per-card bookmark and info** — favouriting and reading never require opening the exercise. The
  `?` is the counterpart to our "i" icon (S-013).
- **Create (`+`) lives in the picker.** You can add a missing exercise without leaving the flow you
  are in — directly relevant to ADR-006, where every exercise starts as a user-created one.

## Data shown

| Element | Data | Our source | Notes |
|---|---|---|---|
| Muscle chips | muscle taxonomy | **missing** — [T-004](../../tickets/T-004-exercise-taxonomy.md) | |
| Favourites chip | per-exercise favourite flag | **missing** — T-004 | |
| Card subtitle | **body part**, not muscle | **missing** | `Back`, `Biceps`, `Shoulders` — the coarse axis (see [S-027](S-027-reference-create-exercise.md)) |
| Filter badge | count of active filters | — | |

## Out of scope

The illustrations are licensed artwork. Our cards are **text + icon** until a properly licensed
library exists (owner decision 2026-08-23, [ADR-006](../../decisions/ADR-006-exercise-library-phasing.md)).

## Components used

- CMP-022 — taxonomy chip/cell · CMP-024 — favourite toggle
- CMP-025 — exercise card *(new)* · CMP-026 — filter-count badge *(new)*

## Open questions

- [ ] What is in the filter sheet, beyond muscle group — equipment, logging type?
- [ ] Does the grid/list toggle persist between visits?
- [x] Same surface in two contexts — `Exercises` vs `Add Exercises` with a `Recent Performed` section.
- [ ] How many exercises does `Recent Performed` show before falling back to the full list?

## Revision log
- 2026-08-23 — created from `ref-S026-exercise-browser-picker.png`.
- 2026-08-23 — added the mid-session variant (`Add Exercises` + `Recent Performed`); card subtitle
  identified as **body part**, not muscle.

## Revision log
- 2026-08-26 — [T-021](../../tickets/T-021-body-part-filter.md) built the filter strip: Favourites
  first, then a chip per body part, in one scrolling row as this spec describes. **The filter-count
  badge (CMP-026) was deliberately not built** — the reference needs one because its filters hide
  behind an icon; ours are visible chips, so the count is already on screen. Still open here:
  `Recent Performed` as the leading section when the picker is opened mid-session, the grid/list
  toggle, per-card bookmark and `?`, and `+` inside the picker.
