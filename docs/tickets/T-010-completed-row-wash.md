# T-010 — Completed-row wash (CMP-015, final piece)

- **Status:** **Done** (2026-08-25) — `flutter analyze` clean, 281 tests pass.
- **Priority:** Should
- **Effort:** S
- **Specs:** S-006, CMP-015, design system
- **Last updated:** 2026-08-25

## Goal

Set state should be legible at arm's length. Until now completion showed only as a dimmed
set-number cell and a 24dp disc — hard to read at half a metre with a bar in your hands. A
completed row now carries a full-width wash.

This closes CMP-015, the highest-detail pattern in the reference teardown.

## The colour question, and why this ticket is not green

S-006 records the completed row as **tinted green across its full width**. Building that literally
would break our own first principle:

> Colour is scarce and means "live". A running rest timer is the only thing on screen allowed to be
> saturated. Completed work fills chalk-white, like a tick in a paper log — not green.
> — `docs/design/gymflow-design-system.md` §1

`SemanticColors.success` already carries the same instruction in code. So the *intent* of the
reference's green is adopted — full-width, readable across the room — and its colour is not. The
wash is `success` chalk at 5%.

Owner-confirmed 2026-08-25, choosing the wash over closing the item as won't-do.

## Scope (in)

- New `SemanticColors.completedRow` token: `#EDEAE3` at 5%.
- A shared `setRowDecoration` helper, used by both set-row widgets.
- The wash on completed strength **and** duration rows.

## Scope (out)

- Any change to the numerals, the set badge, or the done control — all three already match the
  design system's "completed row" spec.
- The exercise card's own completed treatment (a `success` left border), which already exists.

## Files touched

- `lib/core/theme/semantic_colors.dart` — the token, plus `copyWith`/`lerp`.
- `lib/features/sessions/ui/widgets/set_row_decoration.dart` (new) — the shared rule.
- `lib/features/sessions/ui/widgets/strength_set_row.dart`, `duration_set_row.dart` — both now call
  the helper instead of carrying their own copy.
- `docs/design/gymflow-design-system.md` — the token table and the "Completed row" entry.

## Model / DB changes

**None.**

## Why a shared helper

The two row widgets had drifted into carrying **identical** copies of the background rule. Adding a
third state to both by hand is exactly how they would stop matching, so the rule moved into one
function that both call. Reviewed as part of this ticket rather than as unrelated refactoring: it is
the code being changed.

## Edge cases

- **Current *and* complete** — a completed set stays editable and can still be the focused row
  (PRD §17). The current treatment wins (`surfaceHigh` + the 3px leading bar); the filled disc still
  marks it done. No blending of the two backgrounds.
- **Un-completing a set** removes the wash; it animates out over the existing 200ms
  `AnimatedContainer`, so it fades rather than snapping.
- **Duration rows** get the identical treatment through the same helper.

## Acceptance criteria

- [x] A completed strength row carries the `completedRow` wash.
- [x] A pending row carries none.
- [x] A row that is both current and complete keeps `surfaceHigh`.
- [x] Duration rows behave identically.
- [x] The wash is `success`'s chalk at under 10% alpha — a green regression fails the test.
- [x] `flutter analyze` clean; `flutter test` passes (281).

## QA checklist (on device)

- [ ] Complete a set — the row washes, and it reads as done from across the room.
- [ ] The numerals are still clearly the loudest thing in the row.
- [ ] Un-complete it — the wash fades out.
- [ ] Focus a completed row — it takes the current treatment, not the wash.
- [ ] A duration exercise behaves the same.

## Tests

- `test/widget/set_row_completed_tint_test.dart` — six cases across both row types, including the
  chalk-not-green pin.

## Revision log
- 2026-08-25 — created and shipped. Green rejected against the design system; owner chose the wash.
