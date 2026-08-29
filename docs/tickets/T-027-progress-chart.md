# T-027 — Progress chart: estimated 1RM over time (CMP-019)

- **Status:** In progress
- **Priority:** Should
- **Effort:** L
- **Specs:** S-025, CMP-019, ADR-004, [design](../superpowers/specs/2026-08-27-progress-chart-design.md)
- **Last updated:** 2026-08-29

## Goal

S-025's fourth pane. [T-018](T-018-exercise-detail.md) built About · History · Records and stopped
there because charting was new to this codebase. This adds Progress: one line, one point per
session, the best estimated 1RM you hit that day.

## Scope (in)

- `exerciseProgress` — history to points, in the display unit.
- A pure chart-geometry module: y-domain, round ticks, x-axis labels, point mapping.
- A hand-rolled `CustomPainter` line chart. **No charting dependency.**
- The Progress tab on S-025, absent for duration-logged exercises.

## Scope (out)

- **`fl_chart` or any charting package** — explicitly rejected in the design.
- Touch tooltips or point selection.
- The other three ADR-004 metrics as switchable series.
- A range selector (3m / 6m / all).
- Any second chart elsewhere in the app.

## Model / DB changes

**None.** `schemaVersion` stays 6. Every input already exists.

## Acceptance criteria

- [ ] The Progress tab charts one point per session, oldest left.
- [ ] Axis ticks are round numbers and bracket every point.
- [ ] A gap in training shows as horizontal distance, since points sit at real dates.
- [ ] One session draws a dot and no line; no sessions shows the empty state.
- [ ] A duration-logged exercise has no Progress tab.
- [ ] `flutter analyze` clean; full suite green.

## QA checklist

- [ ] Open a well-trained exercise — the line reads left to right and the axis labels are round.
- [ ] Open one performed once — a single dot, no line.
- [ ] Open one never performed — empty state, no chart.
- [ ] Open a stretch (duration-logged) — no Progress tab at all.

## Revision log

- 2026-08-29 — created from the approved design.
