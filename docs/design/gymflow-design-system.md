# GymFlow design system — "logbook / instrument"

The app is a **logbook with a timer**, used one-handed, mid-workout, between sets.
It is not a social fitness app. The characteristic thing in its world is **numbers**:
weight, reps, RIR, seconds remaining. Numerals are the hero; everything else is
quiet labelling.

Two rules govern every decision here:

1. **Colour is scarce and means "live".** A running rest timer is the only thing on
   screen allowed to be saturated. Completed work fills chalk-white, like a tick in a
   paper log — not green. If everything is coloured, nothing reads as urgent.
2. **No box chrome.** Structure comes from hairline rules and alignment, not from
   outlined input boxes and filled cards. Outlined `InputDecoration` is what makes the
   current build read as stock Android; it is banned inside set rows.

---

## Colour tokens

Dark only. Extend the existing `SemanticColors` ThemeExtension — keep the current
field names so existing call sites keep compiling, and add the two new ones.

| Token | Hex | Use |
|---|---|---|
| `ink` (scaffold bg) | `#0A0B0D` | App background. Deeper than the old `#0F1115`. |
| `surface` | `#131519` | Sheets, raised groupings. |
| `surfaceHigh` *(new)* | `#1B1E24` | The current set row only. |
| `line` *(new)* | `#262A31` | Every hairline rule. 1px, never thicker. |
| `chalk` (onSurface) | `#EDEAE3` | Primary text and numerals. Warm off-white, not pure white. |
| `muted` | `#767C86` | Column headers, secondary labels, inactive digits. |
| `success` | `#EDEAE3` | Completed state. Deliberately chalk, NOT green. |
| `completedRow` *(new)* | `#EDEAE3` @ 5% | A completed set row's full-width wash. The same chalk as `success`, spread thin — see "Completed row" below. |
| `rest` | `#4CC9F0` | Running rest timer. Cool = recovery. The one saturated colour. |
| `warning` | `#FFB627` | Paused state only. |
| `danger` | `#E63946` | Destructive actions only. |

`ColorScheme` should be built explicitly (`ColorScheme.dark(...)`), **not**
`ColorScheme.fromSeed`. Seeded schemes are what produce the generic Material look.

---

## Typography

Two widths of one superfamily. The width contrast is the pairing.

- **Barlow Condensed** — every numeral: weights, reps, RIR, set numbers, the rest
  countdown, elapsed time. Condensed digits also fit far more characters per pixel,
  which is what relieves the narrow-column overflow.
- **Barlow** — exercise names, buttons, body copy, labels.

Assets are already downloaded to `assets/fonts/`:
`BarlowCondensed-{Regular,Medium,SemiBold,Bold}.ttf`, `Barlow-{Regular,Medium,SemiBold}.ttf`

Register both families in `pubspec.yaml` with correct weight mappings
(Regular=400, Medium=500, SemiBold=600, Bold=700).

### Scale

| Role | Family | Size | Weight | Notes |
|---|---|---|---|---|
| Rest countdown (sheet) | Condensed | 64 | 700 | tabular figures |
| Rest countdown (bar) | Condensed | 34 | 700 | tabular figures |
| Set numerals (kg/reps/RIR) | Condensed | 22 | 600 | tabular figures |
| Set number | Condensed | 15 | 600 | |
| Elapsed time | Condensed | 20 | 600 | tabular figures |
| Exercise name | Barlow | 17 | 600 | |
| Body | Barlow | 15 | 400 | |
| Column header / micro-label | Barlow | 11 | 600 | uppercase, letterSpacing 1.2, `muted` |

Every numeric style carries `fontFeatures: [FontFeature.tabularFigures()]` so digits
do not jitter as they change.

---

## The set row — this is the signature element

Rows read as **ledger lines**, not cards. Column headers appear **once per exercise**,
above the rows — never repeated per row.

```
 SET    KG     REPS    RIR
─────────────────────────────────
  1    80.0     8       2      ●
▌ 2    80.0     8       2      ○     ← current
  3    77.5     7       1      ○
```

Structure per row:

```
[ 28  ][      flex 3      ][  flex 2  ][  flex 3  ][ 56 ]
 set#         weight          reps         RIR       done
```

- **No `InputDecoration` outlines.** Numeric cells are borderless `TextField`s,
  centred condensed numerals, `isDense: true`, `contentPadding: EdgeInsets.zero`,
  `border: InputBorder.none`. A 1px `line` rule sits under the *current* row's cells
  only — a writing line, not a box.
- **RIR must not use `DropdownButtonFormField`.** Its internal decoration is what
  overflows at 7px. Use a bare `InkWell` + `showMenu` (or `PopupMenuButton` with
  `child:`) rendering only the value text (`2`, `1.5`, `—`). No arrow chrome, no border.
- **Current row**: `surfaceHigh` background, plus a 3px `chalk` bar on the leading edge.
  No border box.
- **Completed row**: a full-width `completedRow` wash (`chalk` at 5%); numerals stay
  full `chalk` (values remain legible and editable — PRD §17); the done control becomes
  a filled `chalk` disc with an `ink` glyph. Dim only the set-number cell, not the values.
  The wash is what makes set state readable at arm's length; it is deliberately faint,
  because the numerals must stay the loudest thing in the row. S-006 draws this green —
  we do not, per §1: colour is scarce and means "live"
  ([T-010](../tickets/T-010-completed-row-wash.md)).
- **A row that is both current and complete** takes the *current* treatment. "Where you
  are" is the more specific signal, and the filled disc still marks the row done.
- **Done control**: 56×56 hit area, a 24px ring (`muted`, 1.5px) when pending, a
  filled `chalk` disc when complete. No Material checkbox.
- **Row separators**: 1px `line`, inset to start at the KG column so the set-number
  gutter stays open.

Duration rows follow the same grammar with `SET / DURATION` columns.

### Narrow widths

Below ~360dp logical width, the RIR column drops its header and renders value-only at
the same size; the reps column keeps priority. Never let a cell go below 32dp — clip or
drop a column instead of squeezing. Verify at 320dp.

---

## Rest timer — the second signature

A scoreboard clock, not a Material progress bar.

**Compact bar** (in `bottomNavigationBar`, so the exercise list shrinks rather than
being covered):

```
   1:24                    NEXT  Bench Press · Set 2
 ━━━━━━━━━━━━━━━━╸─────────────────────────────────
   −15   +15    ⏸    ⏭
```

- Countdown: condensed 34/700, tinted `rest` running, `warning` paused, `chalk` finished.
- Progress: a **1px hairline rule** spanning full width that drains left-to-right, with
  a 6px round cap at the leading edge. Not a `LinearProgressIndicator` with a track —
  the untravelled portion is `line`, the travelled portion is `rest`.
- Next target: `NEXT` as an 11px muted micro-label, then the label in Barlow 15/400.
- Controls: text buttons `−15` / `+15` in condensed 17/600, then icon buttons. All ≥48dp.

**Expanded sheet**: same clock at 64/700, centred; the hairline becomes a **240px ring**
(`CustomPainter`, 2px stroke, `line` track, `rest` progress, round cap, starting at 12
o'clock). Buttons ≥56dp tall, `line`-outlined, no fills except the primary action.

**Finished state**: countdown replaced by `REST COMPLETE` as an 11px letterspaced
micro-label above a single full-width primary action (`Next set` / `Next exercise`).

---

## What to remove

- `ColorScheme.fromSeed` — replace with an explicit `ColorScheme.dark`.
- Outlined `InputDecorationTheme` inside set rows.
- `DropdownButtonFormField` in `strength_set_row.dart`.
- `LinearProgressIndicator` in the rest bar.
- Any remaining `Card` chrome around set rows.
- Default `CircularProgressIndicator` in the rest sheet (replaced by the ring painter).

## Quality floor

- Tap targets ≥48dp; the done control 56dp.
- Contrast: `chalk` on `ink` is ~15:1; `muted` on `ink` ~5:1. Do not go below `muted`
  for anything the user must read.
- Respect `MediaQuery.disableAnimations` / reduced motion for the drain animation.
- Verify layout at 320dp, 360dp and 430dp logical widths.
