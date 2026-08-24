# T-008 — Pre-fill live session rows from the plan (CMP-015)

- **Status:** **Done** (2026-08-24) — `flutter analyze` clean, 260 tests pass.
- **Priority:** Must
- **Effort:** M
- **Specs:** S-006, CMP-015
- **Roadmap item:** the payoff for [T-002](T-002-prescription-schema.md)
- **Last updated:** 2026-08-24

## Goal

T-002 put the routine's prescription onto every session set
(`plannedWeight` / `plannedReps` / `plannedRepsMax`) and then showed none of it. A pending row still
looked identical whether you had planned 60kg x 8 or planned nothing at all. Make the plan visible in
the row, and make a set that goes to plan **one tap with no typing** (S-006, "where the pre-filled
values come from").

## Scope (in)

- Pending set rows show the snapshotted plan, muted, in the `Kg` and `Reps` cells.
- A planned rep range reads as `8-10`; a single target reads as `8`.
- Completing a row whose logged value is still empty **materialises the plan into the logged
  columns** in the same write that stamps `completedAt`.

## Scope (out)

- The **`Previous` column** (last session's best set) — a separate, independent job.
- The green full-width tint on completed rows.
- Per-session `+ Add Set`.
- Duration rows: `durationSeconds` and `rir` are already snapshotted straight into the logged
  columns at session start, so they need nothing.

## Files touched

- `lib/core/widgets/numeric_field.dart` — new `hintText`, rendered in the field's own numerals
  recoloured to `SemanticColors.muted`, in both the dense (set-row) and boxed decorations.
- `lib/core/utils/formatting.dart` — `formatPlannedReps(reps, repsMax)` → `8` / `8-10` / null.
- `lib/features/sessions/ui/widgets/strength_set_row.dart` — passes the two hints. No layout change.
- `lib/features/sessions/providers/active_session_controller.dart` — `completeSet` fills empty
  `weight` / `reps` from the plan.

## Model / DB changes

**None.** Schema stays at v6; T-002 already persists everything this needs.

## Deviation from S-006

The spec records the muted `60` as *"a real pre-filled value from the routine, not a placeholder"*.
We render it as a **hint** and materialise it on completion instead. The user-visible behaviour is
the same — muted number, one-tap to log it — but nothing is written to the logged columns until the
user acts.

Why: pre-writing the plan into `weight`/`reps` at session start would leave an abandoned session
full of sets claiming results nobody lifted, and `totalVolume` and the PR queries read exactly those
columns. A hint keeps *planned* and *done* distinguishable right up to the moment the user says
otherwise, which is the same reason T-002 gave the two their own columns.

## Edge cases

- **Rep range, one tap** — logs the **lower bound** (owner-confirmed 2026-08-24). The honest floor of
  what was asked for; the top of the range would record reps that may not have happened.
- **A typed value always wins.** Only a still-empty column is filled, so an edit is never overwritten
  by the plan.
- **No plan** — the row hints nothing and completion leaves the logged columns null, exactly as
  before this ticket.
- **Un-completing a set** leaves the materialised values in place. Once logged they are real numbers
  the user can edit or clear; silently un-writing them would lose a genuine edit made after the tap.
- **Weight planned but reps not** (or the reverse) — the two are filled independently.

## Acceptance criteria

- [x] A pending row shows the planned weight and reps, muted.
- [x] A planned range renders `8-10`.
- [x] A row with no plan shows nothing.
- [x] A logged value is shown instead of its hint.
- [x] Completing an untouched planned set logs the planned weight and reps.
- [x] A range logs its lower bound.
- [x] A typed value survives completion untouched.
- [x] Completion with no plan leaves the logged values empty.
- [x] The planned columns themselves are never written by completion.
- [x] `flutter analyze` clean; `flutter test` passes (260).

## QA checklist (on device)

- [ ] Start a session from a routine with a prescription — pending rows show muted numbers.
- [ ] Tap ✓ on an untouched row — the number turns solid and the session volume moves.
- [ ] Type over a hint, then tap ✓ — what you typed is what is logged.
- [ ] Start a session from a routine with no prescription — rows are blank, as before.
- [ ] A duration-logged exercise is unaffected.

## Tests

- `test/sessions/plan_prefill_test.dart` — the five materialisation cases.
- `test/widget/set_row_plan_hint_test.dart` — the five hint-rendering cases.

## Revision log
- 2026-08-24 — created and shipped. Rep-range-on-tap resolved to the lower bound by the owner.
