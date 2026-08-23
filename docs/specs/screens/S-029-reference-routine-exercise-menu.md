# S-029 — Routine exercise options (reference app)

- **Type:** bottom sheet
- **Status:** Draft
- **Source:** reference
- **Counterpart:** S-010 (ours, `template_exercise_settings_sheet.dart`)
- **Screenshots:** `ref-S029-routine-exercise-menu.png`
- **Last updated:** 2026-08-23

## Purpose

Everything you can do to one exercise *within* a routine. Opened from its 3-dot in S-028.

## Contents

Titled with the exercise name, then:

| Action | For us |
|---|---|
| **Video & history** | Partly — our S-013 info sheet has description/notes; no per-exercise history yet (S-025) |
| **Add warm-up sets** | **New concept.** Warm-up sets presumably do not count toward volume or records |
| **Add pinned note** | We have per-exercise notes; "pinned" implies it surfaces during the session |
| **Add to superset** | **New concept** — grouping exercises to alternate between. Out of scope for now |
| **Replace exercise** | **New.** Swap the exercise, keeping its prescribed sets — genuinely useful when a machine is taken |
| **Unit (kg)** | **Per-exercise** weight unit. Ours is per *session* (`WorkoutSessions.weightUnit`) |
| **Remove exercise** | Exists, separated below a divider as the destructive one |

## Worth noting

Our equivalent sheet carries **rest and target sets** — configuration. Theirs carries **actions**,
because the numbers live in the set table on S-028 itself rather than behind a sheet. That is the
better split: the thing you change often is on the surface, and the sheet holds what you do rarely.

## Out of scope

Video (network), supersets (new model, new session behaviour).

## Open questions

- [ ] Do warm-up sets count toward volume, records, or the session's set count?
- [ ] Does "pinned note" show during the live session, and where?

## Revision log
- 2026-08-23 — created from `ref-S029-routine-exercise-menu.png`.
