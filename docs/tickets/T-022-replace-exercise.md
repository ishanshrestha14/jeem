# T-022 — Replace an exercise in a routine (S-029)

- **Status:** **Done** (2026-08-26) — `flutter analyze` clean, 391 tests pass.
- **Priority:** Should
- **Effort:** S
- **Specs:** S-029, S-028, S-014
- **Last updated:** 2026-08-26

## Goal

The only substantial gap the S-027/S-028/S-029 review turned up. S-029 calls it *"genuinely useful
when a machine is taken"*, which is exactly the case: you want the same plan against a different
movement, not to rebuild it set by set — delete-and-re-add loses every prescribed number.

## Scope (in)

- `TemplateRepository.replaceExercise(templateExerciseId, newExerciseId)`.
- A **Replace exercise** action in the routine exercise sheet (S-010), opening the existing picker.

## Scope (out), and why

The rest of S-029 is not a gap so much as a different product:

| Their action | Why not |
|---|---|
| Add warm-up sets | New concept — warm-ups presumably do not count toward volume or records, which is a model change, not a menu item |
| Add to superset | New model *and* new session behaviour; S-029 itself puts it out of scope |
| Video & history | History now exists on S-025 ([T-018](T-018-exercise-detail.md)); video is network, out of scope |
| Add pinned note | We have per-exercise notes; "pinned" implies surfacing mid-session, which is a session-UI change |
| Per-exercise unit | Ours is per-session (`WorkoutSessions.weightUnit`); making it per-exercise touches every logged value |

## Decisions

- **Position is untouched.** A replacement takes the place of what it replaced; re-sorting the
  routine because you swapped a machine would be surprising.
- **Numbers that cannot transfer are cleared, and only those.** Swapping strength for duration
  leaves weight and reps meaningless — they would render as nonsense in the set table *and*
  snapshot into the next session. The set **count** survives, because "three sets" is still what you
  planned.
- **The sheet asks; the editor acts.** The settings sheet owns no database, so `onReplace` is a
  callback in the same shape as its existing `onChanged`. The row is absent when no handler is
  given, so it never appears somewhere it cannot work.
- **The sheet closes before the picker opens.** The picker is itself a sheet, and stacking two is
  worse than replacing one.
- **A snackbar names the swap.** The row you were looking at is now a different exercise; saying so
  is better than letting it change silently under you.

## Files touched

- `lib/features/templates/data/template_repository.dart` — `replaceExercise`
- `lib/features/templates/ui/template_exercise_settings_sheet.dart` — the action
- `lib/features/templates/ui/template_editor_screen.dart` — the handler

## Model / DB changes

**None.**

## Edge cases

- **Picking the same exercise** is a no-op, not a pointless write.
- **Cancelling the picker** changes nothing.
- **An unknown replacement id** throws before anything is written — the lookup is the first
  statement inside the transaction, so a routine cannot be left pointing at nothing.
- **Same logging type** keeps the whole prescription untouched.

## Acceptance criteria

- [x] The exercise changes and the prescribed sets survive.
- [x] Its position in the routine is unchanged.
- [x] Swapping strength ⇄ duration clears only the numbers that cannot transfer, keeping the count.
- [x] An unknown replacement changes nothing.
- [x] The action is absent where no handler is supplied.
- [x] `flutter analyze` clean; `flutter test` passes (391).

## QA checklist (on device)

- [x] Routine editor → an exercise's settings → Replace exercise → pick another; the sets stay.
- [x] Replace a strength exercise with a duration one; the set count survives, the numbers clear.
- [x] Start the routine afterwards — the session snapshots the replacement, with the kept plan.

## Revision log
- 2026-08-26 — created and shipped, from the S-027/S-028/S-029 review pass.
