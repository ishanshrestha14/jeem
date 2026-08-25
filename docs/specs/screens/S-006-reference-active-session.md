# S-006 — Active session (reference app)

- **Type:** screen (full-screen takeover)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** S-015 (ours, `active_session_screen.dart`)
- **Screenshots:** `ref-S006-session-numeric-keypad.png` (editing + RIR + Records) · `ref-S006-session-active.png` (zero progress) · `ref-S006-session-active-inprogress.png` (expanded, logging) · `ref-S006-session-empty-adhoc.png` (ad-hoc empty) · `ref-S006-session-finish-confirm.png` (finish validation) · `ref-S006-session-minimised-wip-bar.png` (minimised)
- **Last updated:** 2026-08-23

## Purpose

The surface the user lives on while training. Everything else in the app prepares for or reflects on
this screen. It takes over the full screen, and it is the only place sets are logged.

Sessions started **from a routine** and sessions started **empty from the FAB** land on this same
surface — the routine only pre-seeds the exercise list. (Owner-confirmed; see
[00-overview §4.3](../../research/reference-app/00-overview.md#43-empty--ad-hoc-sessions).)

## Entry points

- Workout tab (S-003) → start a routine
- Workout tab (S-003) → FAB → empty ad-hoc session
- **WIP bar → Resume**, from any tab (CMP-001)
- **App restart while a session is live** — relaunch opens directly onto this screen, even if the
  session was minimised to the WIP bar when the app was killed (owner-confirmed 2026-08-23)

## Layout & sections

Top to bottom, as captured:

1. **Top bar** — chevron (left) · **rest-timer slot** (beside it) · **Finish** (right, pill button)
2. **Stats box** — a single outlined rounded container. **Column count is dynamic**: three columns
   (**Duration · Volume · Sets**) normally, **four** once personal records exist
   (**+ Records**, shown as a `PR` medal glyph + count). Verified in
   `ref-S006-session-numeric-keypad.png`. Corrects the earlier "fixed three-column strip" reading —
   the strip does reflow, just not for zero values
3. **Exercise list** — one row per exercise, in routine order. **Single-open accordion**: tapping a
   row expands it in place and collapses any other; collapsed rows show only name + `n/m done`
4. **Bottom actions** — **Add exercises** (filled, high-emphasis) above **More** (muted, low-emphasis)

Note the vertical rhythm: generous space between the stats box and the list, and the two bottom
buttons are full-width stacked, not side by side.

## The accordion — expanded exercise (the core logging model)

`ref-S006-session-active-inprogress.png` answers the biggest open question: **rows expand inline,
they do not push a screen.** An expanded exercise reveals, top to bottom:

1. **Thumbnail + name + 3-dot** (unchanged from collapsed, but the `n/m done` line disappears)
2. **`Notes…`** — a per-exercise free-text field, placeholder-styled when empty
3. **`⏱ Rest Timer: 3min`** — accent-coloured, tappable. **Rest is configured per exercise**, and
   the config lives *inside the exercise*, not in a settings sheet. This matches our per-exercise
   custom rest, but ours is buried in a sheet (S-010/S-017)
4. **Set table** — a real table with column headers

### Set table

| Column | Contents | Notes |
|---|---|---|
| **Set** | Row number, accent-coloured (`1`, `2`, `3`) | |
| **Previous** | **Best set of the last session** for this exercise, formatted `60kg x 6`; `—` with no history | Owner-confirmed: it is the *best* set, not the same-numbered set — so the same value repeats down every row. **We have no equivalent.** The single most valuable missing feature for progressive overload |
| **Kg** | Weight | Completed rows show a solid value; pending rows show the **routine's prescribed weight** in muted text (`60` greyed) — a pre-filled real value, not a placeholder |
| **Reps** | Reps | Completed rows show the actual (`6`); pending rows show the **routine's prescribed reps or rep range** (`6-8`) in muted text |
| ✓ | Circular check button | **Green filled** when complete; **grey filled** when pending. Always a solid circle — never an empty checkbox |

- The **completed row is tinted green** across its full width — set state is legible from arm's
  length, which is the whole point. *(Ours adopts the full-width wash and not the colour: chalk at
  5%, per the design system — [T-010](../../tickets/T-010-completed-row-wash.md).)*
- **`+ Add Set`** — full-width muted button below the table, so set count is editable per session.

### Where the pre-filled values come from — **the routine, not history**

Owner-confirmed 2026-08-23, correcting an earlier inference. The muted `60` and `6-8` in pending rows
are **the routine's prescription**, captured when the routine was built. Building a routine sets, per
exercise:

- number of sets
- **reps *or* rep range** — a small dropdown toggles which mode that exercise uses
- **RIR**
- weight

So the session surface has **two independent sources of prior information**, and they must not be
confused:

| | Source | Meaning |
|---|---|---|
| Muted `Kg` / `Reps` values | **The routine** | *What you planned to do* |
| **`Previous`** column | **Last session** | *What you actually did last time* |

Design lesson worth stealing wholesale: *pending rows are pre-filled with the plan rather than left
blank*. Logging a set that goes to plan is one tap on the ✓ — no typing at all. The `Previous` column
sits alongside so you can see whether the plan is still right.

**Implication for us:** our templates carry exercises and custom rest, but **no prescribed
weight/reps/rep-range/RIR**. Reproducing this needs a template-level prescription model — a data
change, not a UI change. Our per-set RIR dropdown already exists on the logging side; the reference
app puts RIR on the *plan* side too.

### Editing a value — the custom numeric keypad

`ref-S006-session-numeric-keypad.png`. Tapping any `Kg` or `Reps` cell replaces the system keyboard
with an **app-built keypad**, and this is where RIR lives:

| Key | Purpose |
|---|---|
| `0`–`9`, `⌫` | Numeric entry |
| `.` | **Context-dependent** — occupies the bottom-left slot beside `0` when editing **Kg**, and is *absent* when editing **Reps**, since reps can't be fractional. (Not visible in the screenshot because focus was on a Reps cell.) The keypad reshapes itself to the field it is serving |
| Keyboard glyph | Switch back to the system keyboard |
| **`RIR`** | Log reps-in-reserve **for that specific set** — a modal/inline step off the keypad, not a table column |
| ✨ (accent) | AI assist — **out of scope** |
| **`Next`** | Commit and advance to the next field. **Wraps across rows** — the last field of a set advances into the first field of the next set, so a whole exercise can be logged without dismissing the keypad |

The edited cell is underlined with its content **pre-selected**, so typing replaces rather than
appends — correct behaviour when the pre-filled value is a plan you're overriding. A white marker
runs down the **left edge of the active row**.

**This answers where RIR went.** It is not a column; it is a key on the keypad, reachable only while
editing a set. That keeps the table at four columns and readable at arm's length, while still
capturing RIR per set. Our MVP puts RIR in an always-visible per-set dropdown — more discoverable,
but it costs permanent horizontal space in the row.

Note the economics of a custom keypad: it removes the system keyboard's latency and layout shift,
guarantees the digits are large touch targets, and gives room for domain keys (`RIR`, `Next`). For a
surface used mid-set with chalky hands, that is a strong argument — and it's a self-contained widget,
not a data change.

The **per-field key set** is the subtle part: showing `.` for weight and withholding it for reps
makes an invalid entry unreachable rather than merely rejected. That's validation done as layout,
which is cheaper and kinder than an error message. A system keyboard can only approximate this with
input types.

## Rest timer

When a set is checked, the rest timer takes over the **top-bar slot beside the chevron**, becoming
an accent-filled pill with a stopwatch icon and a **counting-down** value (`02:55`, `02:36`), with a
**thin accent progress bar spanning the top of the content area** beneath it.

- Before any set is completed, the same slot holds a plain outline stopwatch icon — so the top bar
  does not reflow when rest starts; the slot is always reserved. **UNVERIFIED:** what tapping the
  idle stopwatch does (probably a manual rest start).
- Rest is global chrome, not attached to the exercise row that triggered it — the user can scroll
  away and still see the countdown.

## Finish flow

Three surfaces, in order:

1. **Validation modal** (`ref-S006-session-finish-confirm.png`) — fires when sets are left unfilled.
   Lists **every** affected exercise by name, then **`Finish Anyway`** (filled, high emphasis) over
   **`Resume Workout`** (plain text). Note the ordering: the destructive-ish option is the visually
   dominant one, because the user already declared intent by tapping Finish.
2. **`Finish Workout` form** → S-023
3. **Celebration / share card** → S-024

`Finish` is **genuinely disabled at 0 completed sets** — dim in `ref-S006-session-active.png` and
`ref-S006-session-empty-adhoc.png`, fully accent-filled once one set is logged. Open question 2
resolved.

## Ad-hoc empty session

`ref-S006-session-empty-adhoc.png`: stats box (`0:00:04 / 0 kg / 0`), then a large void, then
**Add exercises** / **More** floating in the vertical middle. No illustration, no explanatory copy,
no heading — the two buttons *are* the empty state. Consistent with the zero-progress state's
refusal to nag.

## Data shown

| Element | Data | Our source | Notes |
|---|---|---|---|
| Duration | Elapsed session time, `H:MM:SS` (`0:05:07`) | `active_session_controller` | Live-ticking; the only stat in an accent colour |
| Records | `PR` medal + **lifetime** PR count (`4`) | none | Column only present once records exist. Four metrics tracked — [ADR-004](../../decisions/ADR-004-pr-metrics.md) |
| Volume | Total weight moved, `0 kg` → `360 kg` → `720 kg` → `920 kg` | derive: `Σ weight × reps` | Shows `0 kg` rather than hiding — confirms [ADR-003](../../decisions/ADR-003-volume-as-total-weight.md). `60 kg × 6 = 360 kg` verified on screen |
| Sets | Completed set count, `0` | count of completed sets | Completed only, not planned |
| Exercise thumbnail | Line-art illustration, rounded square, with a small `?` badge | `image_storage_service` | `?` badge is UNVERIFIED — likely the info affordance (our S-013 "i" icon) |
| Exercise name | Full name, wraps to 2 lines | `exercises.name` | Not truncated — wrapping is preferred over ellipsis |
| Progress line | `0/3 done` | completed / planned sets | Per-exercise, secondary colour |
| Overflow | 3-dot vertical, accent colour | — | Per-exercise menu; contents UNVERIFIED |
| Per-exercise notes | `Notes…` free text | new | Only visible when expanded |
| Per-exercise rest | `Rest Timer: 3min` | `template_exercise.restSeconds` | Editable inline, not via a sheet |
| Previous | Prior session's result per set | **missing** | `—` when no history |

## Primary actions

| Action | Result | Destination |
|---|---|---|
| Chevron (top left) | Minimise to WIP bar; session keeps running | previous tab |
| **Finish** | End the session. Disabled at 0 sets. Validation modal if fields are unfilled → S-023 | S-023 |
| **Add exercises** | Add exercises to the live session | picker (our S-014) |
| Tap exercise row | **Expands inline** (accordion) to notes + rest + set table | stays |
| Tap ✓ on a set row | Marks the set complete, tints it green, starts the rest countdown | stays |
| **+ Add Set** | Appends a set row to that exercise | stays |

## Secondary actions

| Action | Result |
|---|---|
| Stopwatch icon (top bar) | Idle state of the rest-timer slot; becomes the countdown pill during rest. Tap behaviour UNVERIFIED |
| Tap `Rest Timer: 3min` | Edit that exercise's rest duration (UNVERIFIED how) |
| `Notes…` | Per-exercise note entry |
| Per-exercise 3-dot | Per-exercise menu (reorder? remove? rest? notes?) — contents UNVERIFIED |
| **More** | UNVERIFIED — session-level options; likely our S-017 session settings counterpart |
| `?` badge on thumbnail | UNVERIFIED — probably exercise info |

## Components used

- CMP-002 — live session stats strip *(this screenshot is its primary reference)*
- CMP-004 — add-exercise affordance inside a live session
- CMP-001 — minimised-session bar (on exit via chevron)
- CMP-003 — set-completion-triggered rest timer (not visible in this state)

## Navigation out

- chevron → minimise, any tab, WIP bar visible
- Finish → confirmation modal → summary
- Add exercises → exercise picker

## States

- **Zero-progress (captured):** `0:05:07 / 0 kg / 0`, every exercise `0/3 done`. Notable — the
  session has been running 5 minutes with nothing logged, and the UI shows no nagging or empty-state
  messaging. The exercise list *is* the empty state.
- **Empty ad-hoc:** no exercise rows at all; **Add exercises** carries the whole screen. NEEDED: `ref-S006-session-empty-adhoc.png`
- **In progress:** some sets complete, volume and sets non-zero. NEEDED: `ref-S006-session-active-inprogress.png`
- **Resting:** rest timer visible after a set is marked. NEEDED: `ref-S006-session-rest-timer.png`
- **Minimised:** replaced by WIP bar (CMP-001)
- **Finishing:** confirmation modal. NEEDED: `ref-S006-session-finish.png`
- **Restored after app kill:** returns full-screen (owner-confirmed)

## Edge cases

- **Finish is visually de-emphasised at zero progress** — the pill reads dimmer than an active
  control. UNVERIFIED whether it is genuinely disabled at 0 sets, or just low-contrast styling. This
  matters: it's the difference between "you can't finish an empty session" and a styling choice.
- Long exercise names wrap to two lines and the row grows; the layout does not truncate.
- Volume shows `0 kg` for a duration-only routine rather than hiding the column.
- Session survives app kill and reopens full-screen — so "minimised" is not persisted, only "active".

## Open questions

**Resolved 2026-08-23 by this screenshot batch:**
- [x] Rows **expand inline** (accordion), no per-exercise screen.
- [x] Finish is **genuinely disabled** at 0 completed sets.
- [x] The top-bar stopwatch is the **rest-timer slot**, reserved so the bar never reflows.

**Open:**
- [x] **Single-open accordion** — expanding one collapses the others (owner-confirmed 2026-08-23).
- [ ] What is in the per-exercise 3-dot menu, and behind **More**?
- [ ] Does tapping the idle stopwatch start a manual rest?
- [x] The muted `60` is a **real pre-filled value from the routine**, not a placeholder — one-tap
      logging confirmed (owner-confirmed 2026-08-23).
- [x] The `6-8` range is **set on the routine**, via a reps-vs-range dropdown chosen per exercise at
      build time (owner-confirmed 2026-08-23).
- [x] Editing a pre-filled value writes **only to that session** — never back to the routine
      (owner-confirmed 2026-08-23). Matches our snapshot-at-start model.
- [x] RIR is logged from a **`RIR` key on the custom numeric keypad**, per set — not a table column.
- [x] `Previous` shows the **best set** of the previous session, not the same-numbered set.
- [x] Decimals: a `.` key sits bottom-left beside `0` **when editing Kg**, and is withheld when
      editing Reps (owner-confirmed 2026-08-23).
- [x] `Records / PR` is a **lifetime** count, not per-session.
- [x] `Next` **wraps** into the first field of the following set.
- [x] PR metrics are **weight · estimated 1RM · volume · reps**, lifetime, per exercise —
      [ADR-004](../../decisions/ADR-004-pr-metrics.md).
- [x] Weight entry is **free decimal**, not stepped.
- [ ] Which 1RM formula? The observed 20 kg × 12 → ~25 kg is more conservative than Epley/Brzycki/
      Lombardi all predict. Ours only needs internal consistency — see ADR-004.

## Revision log
- 2026-08-23 — created from `ref-S006-session-active.png` (zero-progress state); logged 4 open questions.
- 2026-08-23 — keypad refinements: `.` key is **context-dependent** (present for Kg, withheld for
  Reps); `Next` wraps across set rows; `Records` is a **lifetime** count. Resolved 3 open questions,
  opened 2.
- 2026-08-23 — added the custom-keypad section from `ref-S006-session-numeric-keypad.png`: RIR is a
  keypad key (not a column), `Next` chains fields, values are pre-selected on focus. Corrected the
  stats strip to a **dynamic 3-or-4 column** container (Records/PR appears once records exist) and
  `Previous` to **best set of last session**. Raised CMP-018. Resolved 3 open questions, opened 3.
- 2026-08-23 — owner corrections: accordion is **single-open**; pre-filled Kg/Reps come from **the
  routine's prescription** (sets · reps-or-range via dropdown · RIR · weight), *not* from session
  history — so `Previous` and the muted values are two distinct sources. Noted the resulting
  template data-model gap. Resolved 3 open questions, opened 2.
- 2026-08-23 — major expansion from 4 more screenshots: documented the accordion logging model, the
  set table (Previous / pre-filled Kg / target rep range / green completed row / + Add Set), the
  top-bar rest-timer slot, the 3-step finish flow, and the ad-hoc empty state. Resolved 3 open
  questions, opened 5. Raised S-023, S-024, CMP-011–CMP-014.
- 2026-08-24 — [T-008](../../tickets/T-008-plan-prefill.md) built the pre-filled `Kg`/`Reps` cells.
  **Deviation:** the muted value is a *hint*, materialised into the logged columns when the set is
  completed, rather than a value pre-written at session start — the one-tap behaviour this spec
  requires, without an abandoned session claiming lifts nobody did. `Previous` and the green
  completed-row tint remain unbuilt.
- 2026-08-24 — [T-009](../../tickets/T-009-previous-best.md) built `Previous`. **Deviation:** one
  muted `Last · 70kg x 6` line per exercise rather than a per-row column — the value is the best set
  of the last session, so this spec already notes it is identical down every row, and our set row
  carries a RIR column the reference moved onto its keypad. Absent rather than `—` with no history.
  "Best" is the highest estimated 1RM (ADR-004); "last session" is the most recent one that
  *contained* the exercise. Only the green completed-row tint of CMP-015 remains unbuilt.
- 2026-08-25 — [T-010](../../tickets/T-010-completed-row-wash.md) built the completed-row wash,
  closing CMP-015. **Deviation:** the wash is **chalk at 5%, not green** — the design system's first
  principle reserves colour for "live", and `success` is already deliberately chalk. A row that is
  both current and complete takes the current treatment.
