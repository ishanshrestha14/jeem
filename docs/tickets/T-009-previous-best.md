# T-009 — `Previous`: last session's best set (CMP-015)

- **Status:** **Done** (2026-08-24) — `flutter analyze` clean, 275 tests pass.
- **Priority:** Must
- **Effort:** M
- **Specs:** S-006, CMP-015, ADR-004
- **Roadmap item:** the second half of CMP-015, after [T-008](T-008-plan-prefill.md)
- **Last updated:** 2026-08-24

## Goal

S-006 calls `Previous` *"the single most valuable missing feature for progressive overload"*. T-008
put the **plan** in front of you; this puts **what you actually did last time** beside it, so you
can see whether the plan is still right.

## Scope (in)

- A `previousBestByExercise` pass over completed sessions: `exerciseId ?? name` → the best set of the
  most recent session that contained that exercise.
- One muted line per exercise in the live session — `Last · 70kg x 6` — above the column headers.

## Scope (out)

- A per-row `Previous` **column** — see the deviation below.
- The green full-width completed-row tint (the last unbuilt piece of CMP-015).
- Anything on the history or You surfaces; this is the session screen only.

## Files touched

- `lib/features/sessions/domain/previous_best.dart` (new) — the pure pass and its `PreviousBest`.
- `lib/features/sessions/providers/previous_best_provider.dart` (new) — derives it from
  `historyProvider`, the way `personalRecordsProvider` does.
- `lib/features/sessions/ui/widgets/previous_best_line.dart` (new) — the presentational line.
- `lib/features/sessions/ui/widgets/session_exercise_card.dart` — renders it when expanded.

## Model / DB changes

**None.** Everything needed is already in the completed-session snapshots.

## Decisions

- **"Best" is the highest estimated 1RM** (owner-confirmed 2026-08-24), reusing
  `estimatedOneRepMax` — Epley capped at 12 reps, [ADR-004](../decisions/ADR-004-pr-metrics.md).
  It ranks 70x5 above 60x8 without letting 100x1 outrank 95x8. Ties fall to the heavier set.
- **"Last session" means the most recent session that *contained* the exercise**, not the previous
  session outright. On a split you may not have benched for a week, and blanking `Previous` because
  yesterday was leg day would hide the number the feature exists to show.
- **Derived, not stored** — same reasoning as `personalRecordsProvider`: the completed-session list
  is already watched and in memory, and this app allows editing *completed* sets, which any cached
  table would have to invalidate on.

## Deviation from S-006

The reference app puts `Previous` in a **per-row column**. Ours is **one line per exercise**
(owner-confirmed 2026-08-24), because:

- The value is the *best* set of the last session, so S-006 itself notes it is **identical down every
  row** — a column would repeat one number three times.
- Our set row carries a **RIR column the reference moved onto its keypad** (CMP-018). A fifth numeric
  column would have to shrink the values you are actually reading mid-set.

The per-row column stays open as a follow-up if RIR ever moves to the keypad.

Also: with no history the line is **omitted entirely**, where S-006 specifies `—`. A table cell must
hold its column open; a header line has no column, so an exercise you have never done has no line.

## Edge cases

- **Exercise never done before** — no line.
- **Last session's sets left unlogged or incomplete** — that session answers nothing, and the
  next-older one is consulted instead.
- **Sets missing a weight or reps** are ignored; an exercise with only such sets has no line.
- **Duration-logged exercises** are skipped entirely — no weight or reps to compare (ADR-004).
- **Ad-hoc or since-deleted exercises** match by name, since the snapshot may carry no `exerciseId`.
- **Unit** comes from the *session*, not a global setting.

## Acceptance criteria

- [x] The best set is the highest estimated 1RM, and a lighter set can win on it.
- [x] The most recent session *containing* the exercise is read, not simply the last session.
- [x] A session with no completed set for the exercise is looked past.
- [x] Sets missing a weight or reps are ignored.
- [x] Duration-logged exercises produce nothing.
- [x] An exercise with no id is keyed by name.
- [x] The line reads `Last · 70kg x 6`, muted, in the session's own unit.
- [x] No history renders no line at all.
- [x] End-to-end: a finished session's best set appears on the next session's card, joined by
      `exerciseId` across two independent snapshots.
- [x] `flutter analyze` clean; `flutter test` passes (275).

## QA checklist (on device)

- [ ] Log a session, finish it, start the same routine again — `Last · …` shows the best set.
- [ ] A routine exercise you have never done shows no line.
- [ ] Train a split: an exercise skipped yesterday still shows its own last result, not blank.
- [ ] A duration exercise shows no line.
- [ ] Edit a completed set in history — the line updates.

## Tests

- `test/sessions/previous_best_test.dart` — nine cases on the pure pass.
- `test/widget/previous_best_line_test.dart` — five on the rendered line.
- `test/widget/active_session_test.dart` — one end-to-end, proving the cross-snapshot join.

## Revision log
- 2026-08-24 — created and shipped. Placement and the definition of "best" resolved by the owner.
