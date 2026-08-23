# S-005 — "You" tab (reference app)

- **Type:** screen (primary tab, 4 sub-tabs)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** S-020 (ours — but ours is *only* Settings; this is the largest IA gap)
- **Screenshots:** `ref-S005-you-overview-charts-recovery.png`, `ref-S005-you-overview-log-prs.png`
- **Last updated:** 2026-08-23

## Purpose

The reflection half of the app: everything that accumulates *because* you trained. Per
[ADR-005](../../decisions/ADR-005-adopt-five-tab-navigation.md) this replaces our `/profile` tab,
which today builds `SettingsScreen` directly.

## Layout

**Top bar:** avatar · title `You` · **share** · **calendar** · **settings gear**.
Settings is one icon among three — not a tab, not a screen you navigate to. Confirms CMP-010.

**Sub-tabs** (per ADR-001, sections of this spec, not separate S-IDs):
`Overview` · `Exercises` · `Measures` · `Photos`, with an underline indicator on the active tab.

## Overview pane — sections in order

### 1. Stat chart carousel
Swipeable cards, three dots. Card anatomy: metric name (`Workouts`) · **big value** (`2 workouts`) ·
**delta chip** (`▲ 2`, green) · date range (`Jun 7, 2026 - Aug 29, 2026`) · comparison label
(`vs. previous 3 mo.`) · **line chart** with plotted points and a filled gradient beneath.

The neighbouring card (`Volume`, `4…`) peeks in from the right edge. Same three metrics as everywhere
else in the app — workouts, duration, volume — here plotted over months rather than a week.

### 2. Muscle Recovery — **out of scope**
Heading + subtitle + a **ring gauge** (`86%`), then a horizontal row of anatomical body diagrams,
each muscle group tinted red by fatigue with a coloured percentage pill beneath (`100%` green,
`77%` amber, `52%` red). `View all`.

Out of scope: it needs a recovery model we don't have, and the anatomical artwork is licensed content
we would never reproduce. **The ring-gauge + percentage-pill pattern is reusable** for something we
can actually compute.

### 3. `This week…`
Cut off below the fold. NEEDED: a scrolled screenshot.

### 4. Workout Log
Heading + subtitle *"See patterns in your workout history."* Then a **week dot-strip**: a row of
seven dots under `S M T W T F S`, the trained day filled accent, untrained days small and grey, with
a ▼ marker above the current position. Ends with a **`See full workout history`** link.

**This is where our History lives** (owner decision, 2026-08-23): the dot-strip is the at-a-glance
summary, and `See full workout history` pushes the full list.

### 5. Personal Records
Heading + subtitle *"See your best lifts and trends over time."* Then one row per exercise:
thumbnail · exercise name · **date achieved** (`23 Aug 2026`) · right-aligned **headline value**
(`70 kg`) with the **achieving set** beneath it (`70kg x 8 reps`).

Confirms [ADR-004](../../decisions/ADR-004-pr-metrics.md) in practice: the record is shown as *a
value plus the set that produced it*, which is more useful than a bare number and costs nothing extra
to store.

## Data shown

| Element | Data | Our source | Notes |
|---|---|---|---|
| Chart cards | workouts / volume / … over a date range vs. previous period | `sessions` | Needs period aggregation; charting is new for us |
| Workout Log dots | which days of the week were trained | `sessions.startedAt` | Cheap — a date query |
| PR rows | exercise, value, achieving set, date | **none — no PR concept in `lib/`** | ADR-004 |
| Muscle recovery | fatigue per muscle group | none | Out of scope |

## Components used

- CMP-009 — sub-tab bar · CMP-010 — top-bar utilities · CMP-013 — delta chip
- CMP-019 — stat chart card *(new)*
- CMP-020 — week dot-strip *(new)*
- CMP-021 — PR row *(new)*

## Open questions

- [ ] What is in `This week…`?
- [ ] What do the `Exercises`, `Measures`, `Photos` panes contain?
- [ ] Does `See full workout history` push a list, or open the calendar?
- [ ] Does the PR list show one row per exercise (best only), or one per metric?

## Revision log
- 2026-08-23 — created from two Overview screenshots; History rehomed here per owner decision.
