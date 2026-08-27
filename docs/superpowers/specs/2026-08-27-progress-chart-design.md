# Progress chart (CMP-019) — design

- **Date:** 2026-08-27
- **Status:** Approved (owner, 2026-08-27) — not yet planned or built
- **Delivers:** T-026 (weight-unit normalisation) then T-027 (the Progress pane)
- **Specs touched:** S-025, CMP-019, ADR-003, ADR-004

## Why this is our design, not the reference's

Every ticket since T-011 built our surface against a reference spec. **This one cannot.**
S-025's `Progress` pane was never screenshotted — the spec marks it
`UNVERIFIED — presumably charts it`. There is nothing to match.

So the pane is **ours**, designed from our own data and recorded as such. Where later work compares
it against the reference, the honest answer is that we never saw theirs.

## What it shows

**Estimated 1RM over time, one line, one point per session.**

The point for a session is the **best e1RM across the sets logged that day**, via the existing
`estimatedOneRepMax` (Epley capped at 12 reps, ADR-004). Not an average: a session's best set is what
represents it, the convention `Previous` (T-009) and Records already use, so "better lift" keeps
meaning one thing across the app.

e1RM rather than any of ADR-004's other three metrics because it is the only one that captures
progress made by **adding reps** as well as by adding load — the common case under our rep-range
templates, and the exact argument ADR-004 already makes for including it.

A metric switcher across all four was considered and rejected: four times the design surface, and it
makes the user choose before they can read anything.

## Where the data comes from

`exerciseHistory(...)` already returns precisely the right shape — completed sessions only, newest
first, only logged sets, and sessions where the exercise was skipped already omitted. The pane needs
**no new query**; it maps over what the History pane already watches.

New pure function beside it:

```
List<ProgressPoint> exerciseProgress(List<ExerciseHistoryEntry>, {required String displayUnit})
```

- A set with no weight or no reps contributes nothing.
- A session whose sets were all bodyweight-only yields **no point**, rather than a zero.
- **Duration-logged exercises get no Progress pane at all.** ADR-004 already gives them no records;
  an e1RM for a plank is meaningless. The tab is absent for them rather than empty.

## The unit problem this uncovered — T-026

**There is no weight-unit conversion anywhere in `lib/`.** Sessions snapshot their own `weightUnit`;
Settings lets the unit change at any time; so history can hold both kg and lb. Three places compare
or aggregate weights **across** sessions, and none of them reads that field:

| Site | What goes wrong today |
|---|---|
| `computePersonalRecords` | A 100 lb lift (45 kg) out-ranks a 60 kg one on all four metrics |
| `weekly_summary.dart` | Home's weekly volume **and its week-on-week delta** sum kg and lb together |
| `previousBestByExercise` | T-009's `Previous` line can name the wrong set as better |

This is a **live bug, not one this work introduces** — a chart merely makes it visible, as a cliff in
the line, where Records shows only a quietly wrong number.

### T-026's decision

**Storage is untouched.** A session keeps recording the unit it was logged in; that is the correct
record of what happened, and rewriting history to a single unit would destroy it.

What changes: every **comparison or aggregation across sessions** converts to the current setting
unit first. Pure helpers, applied at the three sites above, one test per site proving a mixed-unit
history now ranks and sums correctly.

ADR-003 (volume as total weight moved) gains a revision note: volume is now stated in the display
unit, summed after conversion.

**T-026 ships first.** The chart is the surface that would make its absence most visible, and it is
a behaviour change deserving its own tests rather than riding along inside a charting ticket.

## How it is drawn — hand-rolled, no dependency

No charting package. We need exactly one chart type, dark-only, inside a design system that already
has its own tokens; `fl_chart` would be a sizeable dependency whose visual language we would spend
the ticket overriding. The Phase B rule ("no new dependencies without asking") is what forced this to
be a conscious choice, and the answer is no.

Two layers, and the split is the point:

### `chart_geometry.dart` — pure

Given points, a rect and a target tick count, returns tick values, tick positions, and the polyline
offsets. It makes two decisions:

- **Round ticks** by the standard 1 / 2 / 2.5 / 5 x 10^n step selection, targeting 4-5 ticks, so the
  axis reads 70 / 75 / 80 / 85 and never 71.3 / 76.8.
- **A non-zero baseline**, padded past the observed range. Zero-basing an e1RM chart spends most of
  its height on empty space and flattens exactly the change you opened the pane to see.

  This is the one place a chart of this kind can mislead, so the mitigation is fixed in the design:
  **every tick is labelled.** The numbers carry the scale; the shape alone is never the whole claim.

### The painter — dumb

Strokes gridlines, the polyline, and one dot per session. No measurement, no decisions. Everything it
draws was computed by the layer above.

### Why not one painter that does both

Fewer files, and defensible for a single chart — but the scale arithmetic would then be reachable
only through golden tests or by reading pixels. This repo has no goldens and tests pure functions
first (`routine_estimate.dart`, `weekly_summary.dart`, `personal_records.dart` are all this shape).
The split keeps the hard part an ordinary `expect`.

### Why not a generic reusable chart widget

CMP-019 as a parameterised series-in-chart-out component is the YAGNI trap: one caller, and
generalising from a single example reliably produces the wrong abstraction. If a second chart appears
— a body-weight trend, volume over time on the You tab — **that** is the moment to extract, with two
real callers to generalise from.

## The x-axis

**Real dates, all history.** Each point sits at its actual date, so an eight-week layoff shows as an
eight-week flat gap.

This is the honest reading, and it makes the most common real question — *did I stall, or did I just
stop going?* — answerable from the shape alone. Evenly-spaced-by-session was rejected for exactly
that reason: it puts a March session next to a July one and makes a comeback look like uninterrupted
progress.

No range selector (3m / 6m / all). CMP-019's registry line mentions a range, but it is a second
interactive surface to design and test before we know whether any exercise has enough history to need
it. Revisit when one does.

## States

| State | Behaviour |
|---|---|
| No sessions | The existing `EmptyState`, as the History pane uses |
| **One** session | The dot and its value, **no line** — one session is not a trend, and a flat line through it would imply one |
| All values identical | Range is zero, so geometry pads artificially rather than dividing by zero: a flat line at a labelled value, which is the honest picture of a plateau |
| Two or more | As drawn |
| Duration-logged exercise | No Progress tab at all |

## Testing

- **`chart_geometry`** — unit tests: tick selection across ranges, point mapping into a rect,
  the zero-range case, the single-point case. No rendering.
- **`exerciseProgress`** — unit tests: best-set-per-session, sets without weight or reps skipped,
  bodyweight-only session yields no point, unit conversion applied.
- **T-026's three sites** — one test each, on a mixed-unit history.
- **The pane** — widget tests for which state renders, and that a duration-logged exercise has no
  tab. **No golden tests.**

## Out of scope

- Touch tooltips / point selection. Ours to build if wanted later; not needed to read a trend.
- The other three ADR-004 metrics as switchable series.
- A range selector.
- Any second chart anywhere in the app.
- `Leaderboard` (social, already out of scope on S-025).

## Order of work

1. **T-026** — weight-unit normalisation. Pure helpers, three call sites, ADR-003 revision note.
2. **T-027** — `exerciseProgress`, `chart_geometry.dart`, the painter, the pane as S-025's fourth
   tab. New spec entry recording the pane as **ours**; CMP-019 moves from Candidate to Built.

## Open questions

- [ ] Which unit does "current setting" mean at the moment of comparison — the live Settings value,
      re-derived whenever it changes? Assumed yes; it makes records and charts move when you switch
      units, which is correct but worth confirming it is not surprising.
- [ ] Should T-026 backfill anything, or purely normalise at read time? Assumed read-time only,
      consistent with "storage is untouched".
