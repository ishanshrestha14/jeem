# T-027 — Progress chart: estimated 1RM over time (CMP-019)

- **Status:** **Done** (2026-08-29)
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

- [x] The Progress tab charts one point per session, oldest left.
- [x] Axis ticks are round numbers and bracket every point.
- [x] A gap in training shows as horizontal distance, since points sit at real dates.
- [x] One session draws a dot and no line; no sessions shows the empty state.
- [x] A duration-logged exercise has no Progress tab.
- [x] `flutter analyze` clean; full suite green.

## QA checklist

- [ ] Open a well-trained exercise — the line reads left to right and the axis labels are round.
- [ ] Open one performed once — a single dot, no line.
- [ ] Open one never performed — empty state, no chart.
- [ ] Open a stretch (duration-logged) — no Progress tab at all.

## Revision log

- 2026-08-29 — created from the approved design.
- 2026-08-29 — **Done.** `exerciseProgress` (`d127580`), y-axis geometry (`f00e33a`), time-axis ticks
  (`8c1cd28`), the `LineChart` widget (`ed095fe`), and the Progress pane on S-025 (`c366e26`). Every
  task passed review with spec ✅ and quality approved. 30 tests added (458 before the branch, 488
  after); `flutter analyze` clean. **One deviation from the design:** the geometry section's 5%
  pre-padding of the observed range was dropped before choosing the tick step — it produced a 65-90
  domain for 70-85 data (40% of the plot height empty) and contradicted the design's own worked
  examples. Choosing the step from the raw span and snapping outward reproduces both worked examples
  exactly; see the design doc's revision log for 2026-08-29. The four QA checklist items below are
  left unticked — they need a device or macOS run, not just a green test suite.
