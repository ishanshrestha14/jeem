# T-007 — Rebuild the You tab against S-005

- **Status:** Mini-plan submitted — awaiting go
- **Priority:** Should
- **Effort:** M
- **Specs:** S-005, ADR-004
- **Last updated:** 2026-08-23

## Goal

The You tab is currently my invention — a history tile and a paragraph of apology. S-005 shows what
it should be. Rebuild the **Overview** pane against the screenshots, using only data we actually
have.

## What S-005's Overview contains, and what we can honestly build

| Section | Buildable now? | Why |
|---|---|---|
| Stat chart carousel | **No** — deferred | Needs charting, which is entirely new for us. A card per metric with a line chart over a date range and a delta vs. the previous period. Own ticket. |
| Muscle Recovery | **Never** — out of scope | Needs a recovery model we do not have, and the anatomical artwork is licensed. |
| `This week…` | **No** | Cut off below the fold in the screenshot; nothing to build from. |
| **Workout Log** | **Yes** | A week dot-strip over `S M T W T F S` plus `See full workout history`. Pure date query over completed sessions. |
| **Personal Records** | **Yes** | Per exercise: headline value, the achieving set, and the date. Computable from logged sets; metrics fixed by [ADR-004](../decisions/ADR-004-pr-metrics.md). |

## Scope (in)

- **Workout Log** — seven dots under weekday initials, trained days filled, today marked; then a
  `See full workout history` link pushing the existing `HistoryScreen`.
- **Personal Records** — a list per exercise showing `70 kg` with `70kg x 8 reps` beneath and the
  date achieved, exactly the shape S-005 uses: a record is worth more as *a value plus the set that
  produced it* than as a bare number.
  - Metrics per ADR-004: **weight · estimated 1RM · volume · reps**, lifetime, per exercise.
  - **Epley for 1RM, capped at 12 reps**, rounded to 0.5 kg — proposed in ADR-004 and confirmed
    here unless you say otherwise. It only ever compares against our own history, so it needs to be
    self-consistent, not to match anyone else's number.
  - Duration-logged exercises get no records (ADR-004) — the Stretch routine will never appear here.
- Settings stays a top-bar gear.

## Scope (out)

- The four **sub-tabs** (Overview · Exercises · Measures · Photos). Only Overview has content;
  building a tab bar where three of four panes are empty repeats the mistake the roadmap warned
  about with the five-tab shell. The bar arrives with its second pane.
- Charts, Muscle Recovery, the calendar button, the share action, the avatar.

## Files to touch

- `lib/features/profile/ui/you_screen.dart` — rebuild
- `lib/features/profile/ui/widgets/` — new: `week_dot_strip.dart` (CMP-020), `pr_row.dart` (CMP-021)
- `lib/features/records/` — new: PR computation over session history
- tests: PR computation, the dot-strip, the screen

## Edge cases

- **No history at all**: the dot-strip renders seven empty dots rather than disappearing, and PRs
  show an empty state. A tab that vanishes section by section as data runs out is worse than one
  with a stable shape.
- **PRs are lifetime**, so the computation walks all sessions. Fine at this dataset's size; it wants
  caching before it is walking years of data, and that is a follow-up, not a pre-optimisation.
- **Float comparison** on weights (free decimal since T-004): round for display, never for
  comparison, or 62.5 and 62.499 become the same record.
- **A first session sets records on everything** — noisy but correct, and self-correcting.
- Week boundaries: the strip should start on the same weekday every week, so "this week" does not
  shift under you mid-week. Assuming Monday unless you say otherwise.

## Acceptance criteria

- [ ] The dot-strip marks days with a completed session, and today is distinguishable.
- [ ] `See full workout history` opens the existing history screen.
- [ ] PRs list per exercise with value, achieving set and date.
- [ ] Duration-only exercises never appear in PRs.
- [ ] Empty history gives a stable, honest empty state rather than a collapsing layout.
- [ ] `flutter analyze` clean; full suite passes.

## Open questions

- [ ] Week starts **Monday** or Sunday? The screenshot's strip reads `S M T W T F S`, which suggests
      Sunday — worth confirming, since it changes what "this week" means.
- [ ] Should PRs show **one row per exercise** (its best) or one per metric? S-005 shows one row per
      exercise with a weight headline; assuming that.

## Revision log
- 2026-08-23 — created from `ref-S005-you-overview-log-prs.png` and `-charts-recovery.png`.
