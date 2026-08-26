# CMP-018 — In-session numeric keypad

- **Status:** Draft
- **Used by:** S-015 (active session)
- **Our implementation:** `lib/core/widgets/app_keypad.dart`, `numeric_field.dart`
- **Last updated:** 2026-08-26

## Purpose

Replaces the system keyboard while logging. The OS keyboard is the worst moment in a session UI: it
appears mid-set, shifts the layout, has small keys and no domain actions. This one is app-built,
sized for a thumb, and carries the actions logging actually needs.

## Anatomy

Digits, `⌫`, a keyboard-switch, an **`RIR`** key, and **`Next`**. Mounted in the session's
`bottomNavigationBar` beneath the rest bar, so a running countdown is never hidden behind it.

## Props / inputs

Fields opt in by passing `keypadSortKey` to `NumericField`; that integer is the position in the entry
order `Next` walks. `keypadTag` rides along for the host's use — set rows pass the set id, which is
how the `RIR` key knows which set to write to. A null `keypadSortKey` leaves the field on the system
keyboard, which is why every field outside the session is untouched.

## Variants

The key set varies by field: `.` is offered for weight and withheld for reps.

## States

Attached to a focused editor, or detached (hidden). The focused value is pre-selected, so typing
overwrites rather than appends — correct when the value is a plan you are overriding.

## Interaction & gestures

`Next` commits and advances: weight → reps → the following set's weight, wrapping across sets. Keys
edit the controller directly, so the field is `readOnly` and the OS keyboard stays down. Sort keys
are spaced 1000 apart per exercise so one exercise's sets can never run into the next.

## Accessibility & touch targets

Keys are full-width thirds of the pad, comfortably over 48dp. **Known gap:** `readOnly` fields with a
custom pad are unusual for screen readers — untested.

## Do / Don't

- **Do** give any new opted-in field a sort key that fits the existing order.
- **Don't** use `tester.enterText` on these fields in tests — they are `readOnly` and ignore the
  platform text input. Use the `typeOnKeypad` helper.
- **Don't** let the pad cover the rest countdown.

## Open questions

- [ ] Moving RIR fully onto the pad would free the set row's fifth column, which is what `Previous`
      would need to become a per-row column (S-006).

## Revision log
- 2026-08-26 — written from the implementation (T-003).
