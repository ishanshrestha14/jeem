# CMP-015 — Set table row

- **Status:** Draft
- **Used by:** S-015 (active session)
- **Our implementation:** `lib/features/sessions/ui/widgets/strength_set_row.dart`,
  `duration_set_row.dart`, `set_row_decoration.dart`
- **Last updated:** 2026-08-26

## Purpose

One set, logged. The densest row in the app and the one touched most often mid-workout, so it is
built for a thumb and for reading at arm's length.

## Anatomy

Ledger grammar, not a card: `[28 badge][flex 3 weight][flex 2 reps][flex 3 RIR][56 done]`. No box
chrome — the column headers above the exercise name the columns once, and the current row gets a 1px
writing line under its numeric cells.

## Props / inputs

| Name | Type | Required | Notes |
|---|---|---|---|
| `set` | `SessionSet` | yes | Carries both the plan (`planned*`) and what was logged |
| `isCurrent` | `bool` | yes | Drives the background, leading bar and writing line |
| `weightUnit` | `String` | yes | The session's unit; used for semantics, not rendered in the row |
| `keypadSortKey` | `int?` | no | Position in the keypad's `Next` order; null keeps the system keyboard |
| callbacks | | yes | complete, weight, reps, RIR, long-press |

## Variants

`StrengthSetRow` (weight · reps · RIR) and `DurationSetRow` (duration). They share
`setRowDecoration` so a background state added to one cannot silently miss the other.

## States

| State | Appearance |
|---|---|
| **Pending** | Plan shown muted as a *hint*; outlined ✓ ring |
| **Current** | `surfaceHigh` background, 3px chalk leading bar, writing line |
| **Complete** | Full-width `completedRow` chalk wash, filled ✓ disc, dimmed set number |
| **Current + complete** | Takes the **current** treatment; the disc still marks it done |

Values stay editable in every state (PRD §17) — completion never disables a field.

## The two kinds of prior information

The row shows both, and they must not be confused:

- **The plan** (T-008) — the routine's prescription, muted, in Kg/Reps. A **hint**, not a value:
  nothing is written until the set is completed or typed into. Completing an untouched row
  materialises it, so a set that goes to plan is one tap and no typing.
- **The past** — `Previous`, last session's best set. Ours is one line per exercise rather than a
  column (T-009); see S-006.

## Interaction & gestures

Tap a numeric cell to raise the in-app keypad (CMP-018) — the field is `readOnly`, so the OS keyboard
never appears. Tap ✓ to complete; tap again to un-complete, which **keeps** the materialised values.
Long-press is the row's context gesture.

## Accessibility & touch targets

The done control is 56x56. Numeric fields carry vertical padding lifting them to ≥48dp (PRD §16.3),
which costs no layout because the row is 56dp regardless. The weight field carries an explicit
`Semantics` label naming the unit, since the unit is only in the header visually.

## Do / Don't

- **Do** keep the completed wash faint — the numerals must stay the loudest thing in the row.
- **Don't** colour completion green: `success` is chalk here, deliberately (design system §1).
- **Don't** disable a field on completion.
- **Don't** add a fifth numeric column without first moving RIR onto the keypad; the row does not fit
  one on a phone.

## Revision log
- 2026-08-26 — written from the implementation (T-003, T-008, T-009, T-010).
