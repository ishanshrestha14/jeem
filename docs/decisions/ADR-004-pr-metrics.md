# ADR-004 — Personal records: four metrics, estimated 1RM included

- **Status:** Accepted (formula choice open)
- **Date:** 2026-08-23
- **Relates to:** S-006 (`Records` stat), CMP-002, CMP-012

## Context

The reference app's session stats strip grows a fourth column, `Records 🏅 n`, once personal records
exist — a **lifetime** count (owner-confirmed). Our MVP has **no personal-record concept anywhere in
`lib/`**: nothing computes, stores, or displays a PR.

Owner confirmed the reference app tracks PRs on four metrics, and that we should scope to the same
four for now:

1. **Weight** — heaviest load lifted for the exercise
2. **Estimated 1RM** — derived from a working set (owner's example: 20 kg × 12 reps yields an
   estimated ~25 kg single)
3. **Volume** — best `Σ weight × reps`, per exercise
4. **Reps** — most reps performed in a set

This also explains `Records 4` appearing after only two sets: several metrics can each set a record
from the same set, and a first-ever session sets records on all of them by definition.

## Decision

Track PRs on **exactly those four metrics**, per exercise, computed over **lifetime** history.
Nothing else — no bodyweight-relative records, no per-rep-range records, no time-windowed records.

Estimated 1RM is **included despite being derived**, because it is the only one of the four that
rewards progress made by adding reps rather than load — the common case in our templates, which
carry rep ranges.

## Open: which 1RM formula

The owner's observed example does not pin the formula down, and the common ones disagree at 12 reps:

| Formula | 20 kg × 12 → |
|---|---|
| Epley | 28.0 kg |
| Brzycki | 28.8 kg |
| Lombardi | 27.2 kg |

The reference app appeared to show ~25 kg, which is more conservative than all three — so it is
either a different formula, a rep-count cap, or a misreading of the screen. **UNVERIFIED.**

**Not a blocker.** Our own choice only needs to be consistent with itself, since the number is
compared against our own history, never against the reference app's. Proposal, to confirm at
implementation time: **Epley**, capped at 12 reps (accuracy collapses past that), rounded to 0.5 kg.

## Consequences

- Requires a PR computation over all historical sets, and somewhere to cache it — recomputing
  lifetime records on every set completion will not stay cheap as history grows.
- **Weight is free-decimal** (owner-confirmed), so PR comparisons are float comparisons; round for
  display, never for storage or comparison.
- Duration-logged exercises (stretch) have no weight, reps, or volume in this sense. They get **no
  PRs** under this ADR. Consistent with [ADR-003](ADR-003-volume-as-total-weight.md), which already
  accepted that duration work contributes nothing to volume.
- A first session sets records on everything, which is noisy but harmless and self-correcting.
- Order of work: PRs depend on nothing else, but nothing else depends on them either — this is
  additive, and safely deferrable to a later phase than the prescription model (CMP-017).

## Alternatives considered

- **Weight-only PRs.** Simplest, and cheap to compute. Rejected: it ignores progress made by adding
  reps within a range, which is exactly how rep-range programming advances.
- **No PRs at all.** Defensible for a single-user app, but this is one of the few reference features
  that is pure motivation-per-line-of-code, with no social layer attached.
