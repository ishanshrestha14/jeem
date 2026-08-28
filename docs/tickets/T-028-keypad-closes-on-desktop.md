# T-028 — The in-session keypad closed on every keystroke, on desktop only

- **Status:** **Done** (2026-08-28) — `flutter analyze` clean, 458 tests pass
- **Priority:** Must
- **Effort:** S
- **Specs:** CMP-018, S-006
- **Last updated:** 2026-08-28

## Goal

Owner-reported: entering a weight or reps in a live session on macOS closed the in-app numeric pad
after every single key. The pad reopened on the next tap, so a three-digit weight took three taps
plus three key presses, and often lost the value.

## Root cause

`TextField`'s default `onTapOutside` unfocuses the field on any pointer-down outside it — **and that
default fires only on desktop.** Flutter's implementation switches on `defaultTargetPlatform`: on
Android, iOS and Fuchsia it does nothing; on macOS, Windows and Linux it calls `unfocus()`.

The pad is, physically, outside the field it edits. So on macOS every key press:

1. pointer-down on the pad → `TextField` unfocuses the field
2. `NumericField._onFocusChanged` sees `hasFocus == false`
3. it calls `keypad.detach(editor)`
4. `AppKeypadController._active` becomes null and the pad renders `SizedBox.shrink()`

The key's own `onTap` still ran, which is why a single digit usually landed before the pad vanished.

**This has been broken since [T-003](T-003-numeric-keypad.md) shipped the pad.** It is not a
regression from [T-026](T-026-weight-unit-normalisation.md) — that ticket's entire `lib/` diff
contains no reference to focus, `TextField`, `readOnly` or the keypad. T-026 was suspected first and
cleared by inspection.

### Why 457 passing tests never caught it

**`flutter test` runs as `TargetPlatform.android`.** Under the test default the tap-outside handler
does nothing, so the whole existing keypad suite — which types multi-digit values and asserts they
persist — passes on a code path the shipping desktop build never takes.

This is the interesting part of the bug and the reason it survived review: the tests were not weak,
they were running on a different platform than the failure.

## The fix

Wrap `AppKeypad`'s root in **`TextFieldTapRegion`** (`lib/core/widgets/app_keypad.dart`). That is
precisely what the widget exists for: it puts its subtree into the text field's own tap group, so a
tap on the pad is no longer "outside" the field, on any platform.

One widget, no behaviour change on Android, and dismissal elsewhere still works — tapping a
non-field part of the screen still unfocuses, and the pad's own close key is untouched.

## Scope (out)

- **Auditing every other `TextField` in the app for the same desktop-only behaviour.** Only the
  session set rows pair a field with an in-app pad, so only they can hit this. Worth a sweep if any
  second in-app editor appears.
- Making the set fields accept a physical keyboard on desktop. They are `readOnly` by design
  (T-003) so the OS keyboard stays down; typing on a Mac keyboard still does nothing, which is
  consistent with the pad being the input method. **Owner should say whether that is acceptable on
  macOS** — see Open questions.

## Files touched

- `lib/core/widgets/app_keypad.dart` — the `TextFieldTapRegion` wrapper
- `test/widget/session_keypad_focus_test.dart` (new) — the platform-overriding regression test

## Acceptance criteria

- [x] Typing several digits on the pad keeps the field focused and the pad open, under
      `TargetPlatform.macOS`.
- [x] A test that **fails without the fix** and passes with it, verified by reverting the fix.
- [x] Android behaviour unchanged; full suite green.
- [x] `flutter analyze` clean.

## QA checklist

- [ ] macOS: tap a weight field, type `102.5` on the pad — all five keys land, pad stays open.
- [ ] macOS: `Next` still moves weight → reps → next set's weight.
- [ ] macOS: the pad's close key still dismisses it, and tapping the background still unfocuses.
- [ ] Android: enter a weight and reps as before — no change.

## Open questions

- [ ] Should the set fields accept a **physical keyboard** on desktop? They are `readOnly` so the
      OS keyboard stays down on a phone, but on macOS that means the keyboard in front of you does
      nothing. Making them editable on desktop only is a small change; leaving them is defensible
      since Android is the shipping target and macOS is the dev loop.

## Revision log

- 2026-08-28 — created and fixed. Found by owner testing on macOS; root-caused to Flutter's
  platform-dependent `onTapOutside` default, and to `flutter test` defaulting to Android, which is
  why the existing keypad suite passed throughout.
