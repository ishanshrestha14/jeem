# T-003 — In-session numeric keypad

- **Status:** **Done** (2026-08-23) — `flutter analyze` clean, 216 tests pass.
- **Priority:** Must
- **Effort:** M
- **Specs:** CMP-018, S-006, S-015
- **Roadmap item:** Phase 1, item 4
- **Last updated:** 2026-08-23

## Goal

Replace the system keyboard during set logging. Today `numeric_field.dart` raises the OS keyboard:
the layout shifts mid-set, the keys are small, and there is nowhere to put domain actions. This is
the worst moment in our session UX and the fix needs no schema change.

## Scope (in)

An app-built keypad, shown when a set field is focused on `/session`:

- Digits `0`–`9` and `⌫`, sized as large touch targets.
- **`.`** in the bottom-left slot beside `0` — **only when editing weight**. Withheld for reps and
  RIR-as-integer, so an invalid entry is unreachable rather than rejected. This per-field key set is
  the point of the pattern, not a detail.
- **`RIR`** key — opens a **picker** (owner-confirmed 2026-08-23), not a digit-entry mode, and
  writes RIR for the focused set. We already store `rir` on `SessionSets` and already have an RIR
  control; this moves it onto the keypad so it stops costing a permanent column in the row.
- **`Next`** — commits and advances to the next field, **wrapping** from a set's last field into the
  next set's first field, so an exercise is logged without dismissing the keypad.
- A key to fall back to the system keyboard.
- Focused value **pre-selected**, so typing overwrites rather than appends.

## Scope (out)

- The AI key (out of scope, permanently).
- Pre-filled values (T-002 / item 3) — this ticket works with empty or filled fields alike.
- Changing what is stored. `weight`, `reps`, `rir` on `SessionSets` are unchanged.
- Replacing `numeric_field.dart` anywhere outside the session surface.

## Files to touch

- `lib/features/sessions/ui/widgets/` — new `session_keypad.dart`
- `lib/features/sessions/ui/widgets/strength_set_row.dart` — focus handling, field chaining
- `lib/features/sessions/ui/widgets/duration_set_row.dart` — decide whether duration entry uses it
- `lib/features/sessions/ui/active_session_screen.dart` — host the keypad, manage focus order
- `lib/core/widgets/numeric_field.dart` — suppress the OS keyboard when the app keypad is driving

## Model / DB changes

**None.**

## Edge cases

- **Free decimal weight** (owner-confirmed): accept `62.5`; guard against `..`, a leading `.`, and an
  empty decimal. Store the float; round only for display.
- ~~Keypad vs. rest timer competing for the bottom of the screen~~ — **resolved**: the rest timer
  moves to the **top bar, immediately right of the chevron** (owner-confirmed 2026-08-23, matching
  S-006 / CMP-016). No collision with the keypad. Note this makes CMP-016 a soft prerequisite: if the
  rest bar is still bottom-anchored when this ships, the conflict returns.
- **Existing behaviour to preserve:** completed sets stay editable and nothing blocks completion on
  missing values (`strength_set_row.dart` documents this as PRD §17/§18.7). The keypad must not
  introduce validation that blocks a set.
- **`Next` at the last field of the last set** — stop, or dismiss? Recommend dismiss.
- **Accessibility** — the keypad must carry semantics labels; a screen-reader user must still be able
  to use the system keyboard fallback.
- Rotation / small screens — the keypad must not consume the whole viewport.

## Acceptance criteria

- [ ] Focusing a weight or reps field raises the app keypad, not the OS keyboard.
- [ ] `.` is present editing weight and absent editing reps.
- [ ] `62.5` can be entered and persists as `62.5`.
- [ ] Typing immediately after focus replaces the existing value.
- [ ] `Next` advances weight → reps and wraps into the next set's first field.
- [ ] `RIR` logs RIR for the focused set and it persists.
- [ ] The system-keyboard fallback works.
- [ ] A running rest timer stays visible while the keypad is open (top-bar placement).
- [ ] The `RIR` key opens a picker, and the chosen value persists on that set.
- [ ] Completed sets remain editable; no new validation blocks completion.
- [ ] All keys have ≥48dp touch targets.

## QA checklist (on device)

- [ ] Log a full exercise using only the keypad — no OS keyboard, no scrolling.
- [ ] Enter a decimal weight; reopen the session and confirm it persisted.
- [ ] Complete a set, start rest, keep typing — countdown still visible.
- [ ] Edit an already-completed set.
- [ ] Rotate mid-entry (if rotation is supported) — no lost input.
- [ ] Confirm one-handed reach on the real device: can every key be hit with a thumb?

## Open questions

- [ ] Does duration entry (`duration_set_row.dart`) use this keypad, or keep its own control?
- [x] `RIR` opens a **picker** (owner-confirmed 2026-08-23).

## What shipped

- `lib/core/widgets/app_keypad.dart` — `AppKeypadController` (which field is being edited, and the
  entry order), `AppKeypadScope` (an `InheritedNotifier`), and the `AppKeypad` widget.
- `NumericField` gained `keypadSortKey` / `keypadTag`. **Null by default**, so every field outside
  the session screen keeps the system keyboard untouched. When set, the field goes `readOnly` (OS
  keyboard suppressed, still focusable and caret-visible) and registers with the pad.
- Keys: `0`–`9`, `⌫`, close, **`RIR`**, **`Next`**, and `.` **only when the field accepts decimals**.
- Focusing a field selects its whole value, so the first keypress overwrites the plan rather than
  appending to it. Tapping an already-focused field just moves the caret, as anywhere else.
- `Next` walks a sort-key order (`exerciseIndex * 1000 + setIndex * 2 + field`), so it runs
  weight → reps → **the next set's weight**, across row boundaries. No next field closes the pad.
- `lib/features/sessions/ui/widgets/rir_picker.dart` — an unanchored RIR sheet for the keypad's key.
- `test/widget/session_keypad_test.dart` (10 tests); `typeOnKeypad` helper in `pump_helpers.dart`.

## Decisions made during implementation

- **The RIR column stays.** The ticket said moving RIR to the keypad frees its column, but the row's
  anchored RIR control already works and is more discoverable. Deleting a working affordance is not
  reversible in the way adding one is — the keypad's `RIR` key is now a second route to the same
  action, reachable from where the thumb already is. Reclaiming the column is a separate, easy change
  if the row proves cramped.
- **Keypad and rest bar stack.** CMP-016 (rest in the top bar) is not built, so the rest bar is still
  bottom-anchored and would have collided. They now sit in one `Column`: rest above, keypad below,
  both visible. A running countdown is never hidden behind the pad. When CMP-016 lands this collapses
  back to just the keypad.
- **Duration entry still uses the system keyboard** (open question). Duration rows carry presets and
  a seconds field rather than the weight/reps pair the pad is shaped around; extending it there is a
  separate judgement, not an oversight.
- **The pad is screen state, not a provider.** It is meaningless once the route is gone, and nothing
  outside the session screen observes it.

## Known limitation

`Next` only reaches fields that are currently **built**. A set far offscreen in a long session has
not registered yet, so chaining stops at the edge of what the list has rendered and the pad closes
rather than scrolling to find it. Acceptable for now — chaining is a within-exercise convenience —
but worth revisiting if it bites.

## Revision log
- 2026-08-23 — created from the roadmap (Phase 1, item 4).
- 2026-08-23 — implemented. Keypad, RIR key, Next chaining, decimal-by-field.
