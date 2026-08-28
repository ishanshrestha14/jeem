# Progress chart (CMP-019) — design

- **Date:** 2026-08-27 (revised 2026-08-28)
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

### Which sets count

- **`weight == null` or `reps == null` or `reps <= 0`** — contributes nothing.
- **`weight <= 0`, including an explicitly logged `0`** — contributes nothing. A zero-weight set is
  bodyweight work, and an e1RM of 0 is not a lift; plotted, a single one would drag the y-domain to
  zero and flatten every real point above it.

  **This diverges from `computePersonalRecords`, deliberately.** That function skips only `null`, so a
  logged `0` currently sets a 0 kg weight record and a 0 e1RM record. That looks like a latent bug in
  records rather than a convention worth matching — but changing it is a behaviour change to a
  shipped surface, so it is **noted for T-026 to decide** (same file, same pass) and not silently
  altered here. Until then the two disagree, and this document is where that is written down.
- A session whose sets all fail the above yields **no point**, rather than a zero.
- **Duration-logged exercises get no Progress pane at all.** ADR-004 already gives them no records;
  an e1RM for a plank is meaningless. The tab is absent for them rather than empty.

### Sets over the Epley cap

`estimatedOneRepMax` clamps reps to 12 internally, so clamping is not optional at the call site.
**Sets above 12 reps are included, as-clamped** — not excluded, and not handled specially.

Included rather than excluded because excluding them would drop whole sessions for anyone training in
high-rep ranges, and because the chart sits on the same screen as the Records pane: both must agree
about what a set is worth, or the same session reads as two different numbers one tab apart.

**The consequence, stated plainly:** a 20-rep set and a 12-rep set at the same load produce an
identical e1RM, so the line **understates progress made purely by adding reps beyond 12**. That is
inherited from ADR-004's cap, which accepted it knowingly — the cap exists because every 1RM estimate
degrades past about a dozen reps, and without it a light high-rep set out-ranks a heavy single.

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

### The unit is per session, confirmed

**Verified against the schema, not assumed.** `weightUnit` is a column on **`WorkoutSessions`**
(`tables.dart:236`) and nowhere else — `SessionSets` carries `weight` as a bare `real().nullable()`
with no unit of its own. Every set in a session is therefore in that session's unit, and the helper
signature converts per session:

```
double toDisplayUnit(double weight, {required String from, required String to})
```

Had the unit been per set, this would have had to be threaded through `SessionSet` and applied
set-by-set inside each loop. It does not.

**Conversion constant: 1 lb = 0.45359237 kg**, exact by definition. Applied as a multiply in one
direction and a divide in the other, never as two separately-rounded constants, so a kg -> lb -> kg
round trip returns the value it started with.

### Invalidation on a unit switch — the real risk

**Confirmed: nothing is memoised or cached.** `personalRecordsProvider` and `previousBestProvider`
are both plain Riverpod `Provider`s that recompute from `historyProvider` on every change, exactly as
their own doc comments describe, and `computePersonalRecords` / `previousBestByExercise` are pure
functions with no internal cache. **There is no cache keyed without the unit, because there is no
cache.**

That is the good news and also the trap. Both providers currently watch **only** `historyProvider`.
Once their results depend on the display unit, they must also `ref.watch` the settings unit provider —
otherwise switching kg to lb changes nothing on screen until some unrelated history edit happens to
retrigger them, leaving records and `Previous` visibly stale in the new unit.

**So T-026 must add that watch, and test it**: change the unit, assert the derived values change with
no history edit in between. This applies to `weeklySummary`'s provider on the same grounds.

Should caching ever be introduced (ADR-004 anticipates it "once it is walking years of data"), the
display unit becomes part of the cache key. Recorded here so that future change does not reintroduce
the bug this ticket fixes.

### Display rounding for converted sums

Converting lb to kg produces fractions, so summed volume is almost never a round number. Fixed rule,
so the weekly summary and any future chart cannot disagree:

- **Sum and compare in full `double` precision.** Never round before aggregating or comparing —
  the same rule ADR-004 already states for weight ("round for display, never for storage or
  comparison"), and for the same reason: rounding first makes genuinely different values tie.
- **Round only at the point of display, to a whole unit** — `12450 kg`, never `12450.3 kg`. Volume is
  a magnitude read at a glance; a decimal on a five-digit number is noise.
- **The week-on-week delta is computed from the unrounded sums, then rounded once** for display.
  Rounding each week first and subtracting would let two weeks differing by 0.4 kg display a 1 kg
  delta.
- Individual weights keep their existing display formatting (`formatWeight`, which trims trailing
  zeros); this rule governs **sums**, not single lifts.

ADR-003 (volume as total weight moved) gains a revision note: volume is stated in the display unit,
summed after conversion, at full precision and rounded only to draw.

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
offsets.

**The y-domain and the ticks are computed in this order, and the order is load-bearing:**

1. **Observed range** — `min` and `max` of the point values.
2. **Pad** it outward by a fraction of the span (5% each side), so the extreme points are not welded
   to the frame edge.
3. **Choose the tick step** from the *padded* span, by the standard 1 / 2 / 2.5 / 5 x 10^n selection,
   targeting 4-5 ticks.
4. **Snap the domain edges outward to tick boundaries** — floor the low edge to a multiple of the
   step, ceil the high edge. The domain is now exactly a whole number of steps wide.
5. **Emit ticks** from the snapped low edge, stepping to the snapped high edge.

Doing step 3 before step 4 is what makes the axis read 70 / 75 / 80 / 85 rather than 71.3 / 76.8. If
the domain were snapped first and the step chosen after, the step would be derived from an already-
adjusted span and the two would disagree.

**The domain always brackets the data.** Snapping outward, never inward, is what guarantees it: after
step 4 the low edge is at or below the observed minimum and the high edge at or above the observed
maximum, so no point can fall outside the plotted rect. This is asserted directly (see Testing) rather
than left as a property of the arithmetic.

**A non-zero baseline** falls out of the above: the domain is padded around the data, not anchored at
zero. Zero-basing an e1RM chart spends most of its height on empty space and flattens exactly the
change you opened the pane to see.

This is the one place a chart of this kind can mislead, so the mitigation is fixed in the design:
**every tick is labelled.** The numbers carry the scale; the shape alone is never the whole claim.

**Zero-range** (every value identical) has no span to pad, so step 2 cannot produce one. It is
special-cased: pad by a fixed fraction of the value itself before step 3, which yields a labelled flat
line rather than a division by zero.

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

**Real dates, all history.** Each point sits at its actual date, so an eight-week layoff occupies
eight weeks of **horizontal distance**.

**Correcting an earlier draft of this document:** it claimed a layoff "shows as a flat gap". It does
not. The polyline still connects the last session before the break to the first one after it, so the
gap renders as a single long segment — and if you came back stronger, that segment *slopes upward*.
Nothing is flat about it. What real dates buy is only that the segment is **wide**: the eye reads
distance, so a long gap is visually distinguishable from a dense run of sessions. That is a weaker
claim than the original, and the true one.

It is still the right axis. The common question — *did I stall, or did I just stop going?* — is
answerable from a wide segment but not from evenly-spaced points, which put a March session adjacent
to a July one and make a comeback look like uninterrupted progress.

**Possible, not committed:** breaking or dashing the segment across an unusually long gap, so the
line stops asserting continuity it does not have. It needs a threshold ("unusually" relative to what
— the median inter-session interval for that exercise?), and a wrong threshold is worse than none.
Deferred until the chart exists and there is real history to look at.

## X-axis tick labels

Granularity is chosen from the **span** (last date minus first), targeting **3-5 labels**:

| Span | Granularity | Format | Example |
|---|---|---|---|
| < 8 weeks | ~weekly | `d MMM` | `4 Aug` |
| 8 weeks to 2 years | monthly | `MMM` | `Aug` |
| > 2 years | quarterly | `MMM yy` | `Aug 26` |

Ticks land on **period boundaries, not on data points** — the first month (or week, or quarter)
boundary at or after the domain start, then stepping by whatever interval yields 3-5 labels. Labelling
session dates instead would bunch labels wherever training was dense, which is exactly where the axis
needs to stay readable.

**A year is appended whenever the domain crosses a calendar year**, at any granularity, so `Dec` and
`Jan` can never be read as the same year. Formatting uses `intl`, already a dependency.

A single-point chart draws one label, at that point's date.

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

**`chart_geometry`** — unit tests, no rendering:

- Tick selection on a clean range (70-85 -> 70 / 75 / 80 / 85).
- **An ugly range: 61.2 to 63.9.** The interesting case, and the one the algorithm order exists for.
  Ticks must be round values at a round step (61 / 62 / 63 / 64 at step 1), not the padded raw edges
  and not 61.2 / 62.1 / 63.0.
- **Bracketing, asserted directly:** for several ranges including the ugly one, every input value
  lies within `[domainMin, domainMax]` after snapping. This is the property that keeps a point from
  being drawn outside the plot rect, so it is tested as a property rather than inferred from the
  arithmetic.
- Domain edges are exact multiples of the chosen step.
- Zero-range (all values equal) yields a valid domain and does not divide by zero.
- Single point.
- Point mapping into a rect: first and last x land on the rect's edges; a mid-range value maps
  proportionally.

**X-axis labels** — unit tests: each span band picks its granularity (`d MMM` / `MMM` / `MMM yy`),
labels land on period boundaries rather than session dates, 3-5 labels result, and a domain crossing
a calendar year appends the year.

**`exerciseProgress`** — unit tests: best set per session wins; `null` weight or reps skipped;
**`weight: 0` skipped**; a session of only such sets yields no point; a >12-rep set is included with
its e1RM clamped; conversion applied from the session's unit to the display unit.

**T-026** — one test per site (`computePersonalRecords`, `weekly_summary`, `previousBestByExercise`)
on a mixed kg/lb history, **plus** the invalidation test: change the display unit, assert derived
values change with no history edit in between. Plus a kg -> lb -> kg round-trip returning the
original.

**The pane** — widget tests for which state renders (empty, single point, line), and that a
duration-logged exercise has no Progress tab. **No golden tests.**

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

## Revision log

- 2026-08-27 — created and approved.
- 2026-08-28 — revised against owner review:
  1. **Corrected a false claim.** The x-axis section said a layoff "shows as a flat gap"; the
     polyline connects across the gap, so it renders as one wide, often sloping, segment. Real dates
     buy horizontal distance, not flatness. A broken or dashed segment across long gaps is recorded
     as a possible option, not committed — it needs a threshold, and a wrong threshold is worse than
     none.
  2. Sets over the Epley cap: stated explicitly as **included, as-clamped**, with the consequence
     (progress from reps beyond 12 is understated) written down.
  3. Geometry algorithm order fixed: pad, choose step from the padded span, then snap edges outward
     to tick boundaries. Added the ugly-range (61.2-63.9) and bracketing tests.
  4. X-axis tick labels specified: granularity by span, ticks on period boundaries, year appended
     when the domain crosses one.
  5. `exerciseProgress` contract: **`weight: 0` is skipped as bodyweight**, and the deliberate
     divergence from `computePersonalRecords` (which skips only `null`) is recorded for T-026.
  6. Verified there is **no memoisation to key wrongly** — but both providers watch only
     `historyProvider`, so T-026 must add a watch on the settings unit or a switch leaves stale
     values. Test required.
  7. Verified `weightUnit` is **per session**, not per set (`tables.dart:236`); helper signature
     unchanged. Conversion constant fixed at 1 lb = 0.45359237 kg.
  8. Display rounding for converted sums fixed: full precision to sum and compare, round to a whole
     unit only to draw, delta computed before rounding.