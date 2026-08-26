# CMP-020 — Week dot strip

- **Status:** Draft
- **Used by:** S-005 (You), S-003 (Workout tab)
- **Our implementation:** `lib/core/widgets/week_dot_strip.dart`
- **Last updated:** 2026-08-26

## Purpose

Seven days at a glance: which of them you trained. Small enough to sit above other content without
competing with it, and readable without a legend.

## Anatomy

A `Row` of seven equal columns. Each carries a weekday initial above a dot; the dot is filled on days
with a completed workout, and today's column is marked.

## Props / inputs

| Name | Type | Required | Notes |
|---|---|---|---|
| `trainedDays` | `Set<DateTime>` | yes | Any time of day; normalised to dates internally |
| `today` | `DateTime` | yes | Passed in rather than read from the clock, so it is testable |

## Variants

None. Both hosts render it identically — deliberately, since two week strips that looked different
would imply two different weeks.

## States

Per day: **trained**, **untrained**, and **today** (which is orthogonal — today can be either).

## The week runs Sunday–Saturday

Not a rolling seven days from today, which is what the reference app uses (S-003). A rolling week
shifts under you mid-week: the same workout moves position each day, and "this week" never means the
same thing twice.

The definition lives in [`weekStart`](../../../lib/core/utils/formatting.dart), shared with S-001's
weekly summary. This is load-bearing: if the strip and the summary disagreed about which week you are
in, the strip could fill a dot for a workout the summary had not counted, and nothing would flag it.

## Interaction & gestures

None. It reports; it does not navigate.

## Accessibility & touch targets

Not interactive, so no target rules apply. **Known gap:** the dots carry their meaning by fill alone
and expose no semantics — a screen reader gets seven bare weekday letters. Worth fixing; see below.

## Do / Don't

- **Do** pass `today` in rather than calling `DateTime.now()` inside.
- **Do** use `weekStart` for any new "this week" calculation rather than writing another one.
- **Don't** add a second week model for a different surface.

## Open questions

- [ ] Add per-day semantics ("Monday, trained") so the strip is not fill-only for screen readers.
- [ ] Should a day with a *cancelled* session read as untrained? It does today, which seems right.

## Revision log
- 2026-08-26 — written from the implementation; moved from `features/profile/ui/widgets/` to
  `core/widgets/` at the same time, since S-003 uses it too.
