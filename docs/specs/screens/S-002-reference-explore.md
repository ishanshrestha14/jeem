# S-002 — Explore tab (reference app)

- **Type:** screen (primary tab, 3 sub-tabs)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** S-011 (ours, `exercise_list_screen.dart`)
- **Related:** S-026 (the browser/picker this grid leads into), S-025 (exercise detail)
- **Screenshots:** `ref-S002-explore-exercises.png`
- **Last updated:** 2026-08-23

## Purpose

Browse and search the exercise library. In the reference app it also hosts community content
(`Programs`, `Coaches`) — **both out of scope**, so for us this tab is the exercise repository alone,
with **no sub-tabs** (ADR-005).

## Layout

1. **Search field** — pinned at the top, full-width rounded, `Search exercises…`. Search is the
   first thing on the screen, not hidden behind an icon
2. **Sub-tabs** — `Programs` · **`Exercises`** · `Coaches`, each an icon above a label. *Ours: none*
3. **Muscle-group grid** — 3 columns; each cell is an anatomical illustration with the target muscle
   tinted red, captioned (`Quadriceps femoris`, `Hamstrings`, `Hips`, `Calves`, `Forearms`, `Neck`).
   `Cardio` is included in the same grid with a treadmill illustration rather than an anatomy figure
4. **`By equipment`** — a second grid below, photographic equipment renders (barbell, dumbbells,
   a bodyweight/push-up figure)

## The finding that matters: we have no taxonomy

Our `Exercises` table (`lib/db/tables.dart`) has a single nullable **`category`** text column. There
is **no muscle group and no equipment field at all**. Browsing by muscle *or* by equipment — the two
organising axes on this entire screen — is not expressible against our current schema.

This is a second data-model gap, independent of the prescription gap (T-002), and it blocks any
faithful version of this tab. See **T-004**.

Note also that both grids here lean on **licensed artwork** — anatomical renders and equipment
photography. We will not reproduce those. **Decided (ADR-006): text + icon cells for now**, with a
properly resourced visual library as a later phase. Accepted consequence: our Explore is markedly
plainer than the reference app's, and in Phase A the muscle grid may be nearly empty — which is why
the **pinned search field carries browsing** until tagging exists.

## Data shown

| Element | Data | Our source | Notes |
|---|---|---|---|
| Search | free text over exercise names | `exercise_repository` | We already have search (`exercise_list_screen`) |
| Muscle-group cells | muscle taxonomy + count | **missing** | Needs a `muscleGroup` field |
| Equipment cells | equipment taxonomy | **missing** | Needs an `equipment` field |

## Primary actions

| Action | Result |
|---|---|
| Search | Filter exercises |
| Tap a muscle group | Exercises for that muscle (UNVERIFIED: filtered list vs. dedicated screen) |
| Tap equipment | Exercises for that equipment |

## Components used

- CMP-022 — taxonomy grid cell *(new)*
- CMP-009 — sub-tab bar *(not adopted — we have one pane)*

## Open questions

- [ ] What does tapping a muscle group open?
- [ ] Is an exercise tagged with **one** primary muscle or **several**?
- [x] A flat list exists — `All Exercises` on S-026, with a grid/list toggle.
- [ ] Does the equipment grid scroll further than the three visible cells?

## Revision log
- 2026-08-23 — created from `ref-S002-explore-exercises.png`; raised the muscle/equipment taxonomy
  gap and T-004.
