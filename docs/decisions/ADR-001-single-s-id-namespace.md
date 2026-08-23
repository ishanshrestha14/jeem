# ADR-001 — One S-ID namespace for both apps, with a `Source` field

- **Status:** Accepted
- **Date:** 2026-08-23
- **Decides:** open question 3 from the bootstrap session ("S-IDs for our MVP surfaces too, or reference-app only?")

## Context

Phase A documents two things at once: the reference app's UX (patterns to learn from) and our existing MVP (the thing being improved). The gap analysis in `05-gap-analysis.md` compares them row by row, and every ticket has to point at both "what exists" and "what we want".

Three options were on the table:

1. **Reference-app only.** S-IDs describe the reference app; our MVP is described in prose. Cheap, but gap-analysis rows have nothing stable to point at on our side, and tickets end up quoting file paths instead of specs.
2. **Two namespaces** (e.g. `S-` for reference, `MS-` for ours). Clear separation, but doubles the registry, and every cross-reference has to remember which prefix it's in.
3. **One namespace, `Source` field.** Every surface in either app gets the next S-ID; the spec's `Source` field says `reference` | `ours` | `both`.

## Decision

**Option 3.** A single monotonically increasing S-ID sequence covers surfaces in both apps.

- Every S spec carries `Source: reference | ours | both`.
- Every S spec carries `Counterpart:` — the S-ID of the equivalent surface in the other app, or `none (gap)`.
- A surface is `Source: both` **only** when it is genuinely the same surface we are evolving in place (same job, same position in the IA). Two apps' different takes on the same job stay as two S-IDs linked by `Counterpart`, because the gap between them is the thing worth documenting.
- Our MVP surfaces are seeded now, from `lib/`, so gap analysis and tickets have targets from day one.

### Sub-decision: tab panes are not their own S-ID

A tabbed screen (reference Explore, reference Profile) is **one** S-ID; its tabs are documented as sections of that spec. A tab pane graduates to its own S-ID only if it becomes independently navigable (deep-linkable, or reachable from somewhere other than its parent's tab bar). Rationale: the tab bar is the surface's own chrome — splitting it produces specs that can never be entered on their own, and inflates the registry without adding decisions.

## Consequences

- The registry mixes both apps, so **`Source` must be read**, not assumed, on every row. `02-screen-inventory.md` therefore keeps `Source` as a leading column.
- Gap analysis becomes one table of `S-00X (ours) vs S-00Y (reference)` pairs, and "no counterpart" rows are exactly the feature gaps.
- Renumbering never happens: if a surface we own is later replaced by something modelled on a reference surface, the old S stays and is marked `Superseded by S-0YY`.
- Slight cost: an S-ID alone doesn't tell you which app it's in. Accepted — the inventory is one lookup away, and `Counterpart` makes pairs explicit.

## Alternatives considered

Options 1 and 2 above. Option 1 was rejected because it makes the gap analysis unanchored on our side, which is the half that turns into tickets. Option 2 was rejected as bookkeeping overhead for a two-app, single-author project.
