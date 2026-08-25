# S-003 — Workout tab (reference app)

- **Type:** screen (primary tab)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** S-008 (ours, `workout_screen.dart`)
- **Screenshots:** `ref-S003-workout-tab-empty.png`, `ref-S003-workout-tab-logged.png`
- **Last updated:** 2026-08-23

## Purpose

The launchpad. Answers one question — *what am I doing today?* — and gets the user into a session in
as few taps as possible. Unlike Home (a social feed), this tab is purely functional and personal.

## Layout & sections

1. **Top bar** — avatar (left) · **month + day** (`August 23`, centred) · calendar icon (right)
2. **Week strip** — 7 columns, weekday initials above dates. Today is labelled **`TODAY`** instead of
   its initial and its date sits in a filled accent circle. Note: the week starts at *today*
   (23, 24, 25 …), it is **not** a Mon–Sun calendar week
3. **Workouts / empty state** — see states below
4. **Suggested routines** — horizontal carousel of routine cards
5. **Insights** — horizontal carousel of metric tiles
6. **`Log another workout`** row (only when a workout exists that day)
7. **FAB** — `▶ Start new workout`, bottom-right, floating above the nav

## States

### Empty (`ref-S003-workout-tab-empty.png`)
- Heading **`No workouts today`**
- A **filled row CTA**: `▶ Start new workout` / *"Add exercises and start logging"* with a chevron —
  a full-width tappable row, not a button
- Suggested routines and Insights still render (Insights shows `100% Recovered`, `🔥 0`)
- The FAB is *also* present, so start-workout is offered **twice simultaneously**. Both lead to the
  ad-hoc empty session (S-006)

### Populated (`ref-S003-workout-tab-logged.png`)
- Heading **`Workouts`**, then one card per session: icon tile, routine name (`pull B`), timestamp
  (`Today at 01:27 AM`), and **Duration / Volume** as a two-column stat pair
- Suggested-routines section is **gone** once a workout is logged for that day
- Insights updates (`97% Recovered`, `🔥 1 week`, `AI feedback`)
- `+ Log another workout` row appears at the bottom

The empty↔populated diff is instructive: the app **removes suggestions once you've trained**, rather
than leaving a stale "do this next" prompt. Fewer decisions after the work is done.

## Data shown

| Element | Data | Our source | Notes |
|---|---|---|---|
| Date header | Current month + day | — | |
| Week strip | 7 days from today | sessions by date | UNVERIFIED whether days with sessions are marked |
| Workout card | name, time, duration, volume | `sessions` | Same volume metric as S-006 |
| Suggested routine card | Large coloured tile with **initials** (`PU`), routine name + template name | `templates` | The tile is a generated colour + initials, **not** an image — cheap to reproduce and a good pattern for us |
| Insights tiles | `% Recovered` ring, streak, AI feedback | — | Mostly **out of scope** (see below) |

## Primary actions

| Action | Result | Destination |
|---|---|---|
| FAB `Start new workout` | Starts an **empty ad-hoc session** | S-006 |
| Row CTA `Start new workout` | Same as FAB | S-006 |
| Tap suggested routine | Start that routine (UNVERIFIED: starts vs. previews) | S-006 |
| Tap workout card | Open that session's detail (UNVERIFIED) | — |
| Calendar icon | Calendar view | UNVERIFIED |
| `+ Log another workout` | Another session same day | S-006 |

## Components used

- CMP-005 — week strip / date header
- CMP-006 — suggested-routine card
- CMP-007 — insights tile carousel
- CMP-011 — initials-tile routine thumbnail
- CMP-012 — workout summary card

## Out of scope from this surface

- **`AI feedback`** tile — no AI, no network.
- **`% Recovered`** ring — implies a recovery model we don't have. The *ring tile form* is reusable
  for something we can compute; the recovery metric itself is not.
- Streak (`🔥`) — computable offline, but a motivation feature, not a training one. Later at best.

## Edge cases

- Two workouts in one day — `Log another workout` implies the list stacks. UNVERIFIED how it looks.
- Suggested routines with no history — a fresh install has nothing to suggest from. UNVERIFIED.
- `Duration 0min` renders for a session under a minute (visible in both shots) — it does not round up
  or show seconds. Ours should probably show `<1min`.

## Open questions

- [ ] Does the week strip mark days that have sessions?
- [ ] Does tapping a suggested routine start it immediately or preview it first?
- [ ] Where do suggestions come from — last performed, rotation order, or something else?

## Revision log
- 2026-08-23 — created from `ref-S003-workout-tab-empty.png` + `ref-S003-workout-tab-logged.png`.
- 2026-08-25 — built as [T-013](../../tickets/T-013-workout-tab.md), replacing our routine-list
  Workout tab (S-008). **Deviations:** the week strip shows weekday initials and a trained dot rather
  than dates, reusing CMP-020's Sunday–Saturday week from the You tab — two contradictory week models
  would be worse than differing from the reference; no Insights row (we have no recovery or streak
  model and will not invent one); no avatar or calendar icon, neither having a destination here.
  Suggestions rank least-recently-performed first, never-performed leading.
