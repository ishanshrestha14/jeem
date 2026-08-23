# S-025 — Exercise detail (reference app)

- **Type:** screen (pushed, 3 sub-tabs)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** S-013 (ours, `exercise_info_sheet.dart`) — ours is a sheet, this is a screen
- **Screenshots:** `ref-S025-exercise-detail-about.png`, `ref-S025-exercise-detail-target-muscles.png`
- **Last updated:** 2026-08-23

## Purpose

Everything known about one exercise: how to do it, what you've done, and whether you're improving.
Our S-013 covers only the first of those three, and only as a bottom sheet.

## Layout

Top bar: back arrow · exercise name (`Bench Press`) · 3-dot overflow.
**Sub-tabs:** **`About`** · `History` · `Progress` · `Records` · `Leaderboard` — five, not three.
The second screenshot shows the tab strip scrolled, revealing `Records` and `Leaderboard` (the
latter is social, out of scope). Per ADR-001 these are sections of this spec.

### About pane

1. **Animated demonstration** — a looping figure animation on a white card, with a **pause control**
   (top-right) and a **fullscreen control** (bottom-right). Not a static image: it plays by default
2. **Action chips** — a horizontally scrolling row: `Favorites` (bookmark) · `YouTube` · `Share` ·
   `How t…` (cut off, likely "How to")
3. **`Target Muscles`** — front and back anatomical figures with **primary muscles in red** and
   **secondary muscles in blue**, followed by a **legend that lists them by name**:

   > ● **Primary** — Latissimus dorsi, Middle trapezius
   > ● **Secondary** — Biceps brachii, Brachialis, Posterior deltoid

   The coloured dot ties each list to its tint on the figure. Note the **anatomical naming**
   ("Latissimus dorsi", not "Lats") — finer than our vocabulary, which folds brachialis into
   `biceps` and trapezius/rhomboids into `upperBack`.

### History pane / Progress pane
UNVERIFIED — not captured. `History` presumably lists past sessions containing this exercise;
`Progress` presumably charts it (cf. CMP-019 on S-005).

## What this confirms for our model — and where we got it wrong

**Primary is plural.** `ref-S025-exercise-detail-target-muscles.png` lists **two primary muscles**
(Latissimus dorsi *and* Middle trapezius) alongside three secondaries. The first About screenshot
showed only the red/blue figures, with no name list, so single-vs-multiple primary was not visible —
and [T-004](../../tickets/T-004-exercise-taxonomy.md) shipped `primaryMuscle` as **one nullable
column**.

The correct shape is **one many-to-many relation carrying a role**, not a column plus a join table:

| | Shipped in v3 | Correct |
|---|---|---|
| Primary | single `primaryMuscle` column | 0..n |
| Secondary | `ExerciseSecondaryMuscles` join table | 0..n |

Compound movements are exactly where this bites: a row is lats *and* mid-traps; a deadlift is
hamstrings *and* glutes *and* spinal erectors. Forcing one primary makes the muscle filter lie about
half the library. See **T-005**.

## Out of scope

- **YouTube** and **Share** — network features.
- The animated demonstrations and anatomical figures are **licensed artwork**. Not to be reproduced,
  traced, or approximated. Our About pane is text-first until we license or commission assets
  (ADR-006).

## Components used

- CMP-009 — sub-tab bar
- CMP-023 — action chip row *(new)*
- CMP-024 — favourite (bookmark) toggle *(new)*

## Open questions

- [ ] What is in the `History`, `Progress` and `Records` panes?
- [ ] How many primaries can an exercise have — is two a cap, or just this exercise?
- [ ] What is in the 3-dot overflow?
- [ ] Is "How to" text instructions, or a video?

## Revision log
- 2026-08-23 — created from `ref-S025-exercise-detail-about.png`.
- 2026-08-23 — added `ref-S025-exercise-detail-target-muscles.png`: **primary is plural** (two listed),
  named legend under the figures, and the tab strip is five tabs (+ Records, Leaderboard). Raised
  T-005 to correct the v3 schema.
