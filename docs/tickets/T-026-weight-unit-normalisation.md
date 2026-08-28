# T-026 — Normalise weights to the display unit before comparing

- **Status:** Done (2026-08-28)
- **Priority:** Must
- **Effort:** M
- **Specs:** ADR-003, ADR-004, [design](../superpowers/specs/2026-08-27-progress-chart-design.md)
- **Last updated:** 2026-08-28

## Goal

There is **no weight-unit conversion anywhere in `lib/`**. Sessions snapshot their own `weightUnit`,
Settings lets the unit change at any time, so history can hold both kg and lb — and three places
compare or aggregate weights across sessions without reading that field.

This is a **live bug**, found while designing the progress chart (T-027) rather than introduced by
it. Today a 100 lb lift (45 kg) out-ranks a 60 kg one on every personal record.

## Scope (in)

- `convertWeight` helpers in `core/utils/`.
- `computePersonalRecords`, `previousBestByExercise`, `weeklySummary` take a `displayUnit`.
- The providers behind them watch the settings unit, so a switch recomputes immediately.
- Home's volume delta stops hardcoding `kg`.

## Scope (out)

- **Any migration or backfill.** Read-time only, owner-confirmed 2026-08-28. Storage is untouched.
- The progress chart itself — that is [T-027](T-027-progress-chart.md).
- Unit conversion in the *live* session UI. A running session has one unit throughout; nothing
  there compares across sessions.

## Model / DB changes

**None.** `schemaVersion` stays 6.

## Acceptance criteria

- [x] A mixed kg/lb history ranks personal records by true weight.
- [x] `Previous` names the genuinely heavier set across a unit change.
- [x] Weekly volume sums after conversion; the delta is computed before rounding.
- [x] Switching the unit in Settings restates all three with no history edit.
- [x] Home's volume delta shows the user's unit, not a hardcoded `kg`.
- [x] `flutter analyze` clean; full suite green (454 tests pass, 13 added on this branch).

## QA checklist (on device)

- [ ] Log a session in kg, switch to lb, open You — records restate immediately.
- [ ] Home's weekly volume and its delta both read in the current unit.

## Revision log

- 2026-08-28 — created from the T-027 design doc, which uncovered the bug.
- 2026-08-28 — shipped. Records, `Previous` and weekly volume all convert first; the three providers
  watch the settings unit so a switch restates them with no history edit. Also decided here: a
  logged `0` is bodyweight, not a 0 kg record — `computePersonalRecords` skipped only `null` before.
