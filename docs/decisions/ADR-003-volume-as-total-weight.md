# ADR-003 — Volume is total weight moved, shown on every session

- **Status:** Accepted (with one open question)
- **Evidence:** `ref-S006-session-active.png` — reference app shows `Volume 0 kg` at zero progress rather than hiding the stat, confirming the consistency argument below
- **Date:** 2026-08-23
- **Relates to:** CMP-002 (live session stats strip), S-006, S-015

## Context

The reference app's active session shows three live stats: **duration · volume · sets**
(see [00-overview §4.1](../research/reference-app/00-overview.md#41-session-chrome)). Owner confirmed
volume there means **total weight moved**.

Our domain complicates this: exercises have a logging type of `strength` (weight × reps) or
`duration` (stretch, timed holds). A duration-only session — the Stretch template — has no weight to
total, so a naive volume stat reads `0 kg` or has to be hidden, which makes the stats strip change
shape depending on which routine you started.

## Decision

**Volume = total weight moved**, summed across completed strength sets as `Σ (weight × reps)`.
Owner-confirmed worked example: 10 kg × 6 reps = **60 kg**, summed over every set in the session.

**The stats strip shows the same three stats on every session**, including duration-only ones,
rather than swapping its layout per routine type. Consistency of the session chrome wins over
per-routine precision: the strip is glanced at mid-set, and a strip that rearranges itself between
routines costs more than a `0 kg` costs.

Marked **"we can change later if necessary"** by the owner — this is a deliberately reversible
choice, not a load-bearing one.

## Open question (does not block)

The owner's phrasing — *"let's show weight for all workout to keep active session UI consistent"* —
admits two readings:

- **(a)** *Show the volume **stat** on all sessions, including duration-only ones.* ← what this ADR
  assumes.
- **(b)** *Show a weight **input field** on all set rows, including duration exercises,* so every set
  row looks the same.

Reading (a) is assumed because it follows directly from the stats-strip context. Reading (b) is a
much larger change — it touches the set-row widgets (`strength_set_row.dart`,
`duration_set_row.dart`), the data model, and what a "duration" exercise even means. **To be
confirmed before any ticket implements it.**

## Consequences

- `session_progress_header.dart` (CMP-002) needs a volume computation over completed strength sets.
- Duration-only sessions display `0 kg` volume. Acceptable; revisit if it reads as broken on device.
- Units are UNVERIFIED — kg is assumed throughout; no unit preference was found in
  `settings_repository.dart`.
- Whether *incomplete* sets count toward volume is UNVERIFIED. Assumption: **completed sets only**,
  matching the idea of "weight actually moved".

## Alternatives considered

- **Swap the third stat per routine type** (volume for strength, total hold time for duration).
  More accurate, but the session chrome would change shape between routines — rejected on the
  consistency argument above.
- **Hide volume when zero.** Same objection: a stat that vanishes is a layout that jumps.
