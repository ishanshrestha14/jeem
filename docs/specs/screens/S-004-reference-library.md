# S-004 — Library ("Your library") (reference app)

- **Type:** screen (primary tab)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** ours, `library_screen.dart`
- **Screenshots:** `ref-S004-library.png`, `ref-S004-library-create-sheet.png`
- **Last updated:** 2026-08-23

## Purpose

Everything **you** made: programs, routines, exercises. Not a dashboard and not
a launchpad — a flat, sortable list you come to in order to *edit* something, where Workout is where
you come to *do* something.

## Layout

1. **Top bar** — avatar (left) · title **`Your library`** · **`+`** (right)
2. **Filter chips** — `Programs` · `Routines` · `Exercises`, pill-shaped, one selected. Not tabs
   with their own scroll positions: they filter the single list below
3. **Section bar** — a **sort control** on the left (`↑↓ Recent`) and a **grid/list toggle** on the
   right
4. **The list** — one row per item: a **square thumbnail tile** (~64dp, rounded), a title, and a
   subtitle giving the item's own count

## Row anatomy

Three kinds of row share one shape, which is what makes the screen read as a single list rather
than a stack of sections:

| Row | Tile | Title | Subtitle |
|---|---|---|---|
| Create | `+` glyph on a plain dark tile | `Create new program` | *(none)* |
| Favorites | bookmark glyph on a plain dark tile | `Favorites` | `0 routines` |
| An item | the item's image | `Pull B` | `1 routine` |

Worth noting: **the create action is a row in the list, not a floating button** — it sits at the top
of the very list it adds to.

## The `+` create sheet

`ref-S004-library-create-sheet.png`. The top-bar `+` is **not** a shortcut for the selected chip: it
opens a modal sheet offering all three kinds, so adding the other kind never means switching filter
first.

| Icon | Title | Subtitle |
|---|---|---|
| folder | **Program** | `Create a program with your routines` |
| clipboard | **Routine** | `Create a reusable workout routine` |
| dumbbell | **Exercise** | `Create a custom exercise` |

Each row is a large circular icon avatar plus title and subtitle, with a drag handle above. The
subtitles carry real weight: "Create a program with your routines" is the clearest statement anywhere
in the app of what a program *is* — a container for routines.

`Favorites` is a **pseudo-item**: it looks exactly like a real entry and carries its own count.

## Data shown

| Element | Data | Our source | Notes |
|---|---|---|---|
| Chips | programs / routines / exercises | `templates`, `exercises` | **We have no "program" concept** — a program groups routines; our top-level object is the routine |
| Item subtitle | contained-item count | `TemplateSummary.exerciseCount` | Theirs counts routines-in-a-program; ours counts exercises-in-a-routine |
| Favorites count | favourited items of the active kind | `Exercises.isFavourite` | **Routines have no favourite flag** — only exercises do |
| Thumbnail | user image | none | Per [ADR-006](../../decisions/ADR-006-exercise-library-phasing.md) we use generated initials tiles (CMP-011), not images |
| Sort | `Recent` | `lastPerformedAt` | Other sort options UNVERIFIED |

## Gaps this opens

- **No `Programs` concept.** A program is a collection of routines (`Pull B` holds 1 routine). Ours
  has no grouping above the routine. Dropping the chip is the honest short-term answer.
- **No favourite flag on routines.** Exercises have one (T-004); routines do not.
- **No grid layout** for either list, so the grid/list toggle has nothing to switch to yet.

## Open questions

- [x] The top-bar `+` opens a three-option create sheet, not the selected chip's create action.
- [ ] What sort options does `Recent` open?
- [ ] Does the `Exercises` chip show the same row shape, or the card grid from S-026?

## Revision log
- 2026-08-23 — created from `ref-S004-library.png`, after our own Library screen drifted from it.
- 2026-08-23 — added the `+` create sheet from `ref-S004-library-create-sheet.png`.
