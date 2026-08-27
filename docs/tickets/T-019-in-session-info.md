# T-019 — The in-session ℹ opens the exercise detail screen

- **Status:** **Done** (2026-08-26) — `flutter analyze` clean, 370 tests pass.
- **Priority:** Should
- **Effort:** S
- **Specs:** S-025, S-013, S-015
- **Last updated:** 2026-08-26

## Why

[T-018](T-018-exercise-detail.md) shipped the exercise detail screen but left the ℹ on a live
session's exercise card opening the old S-013 info sheet. That was **my assumption, not a decision**
— the question went unanswered — and the owner subsequently chose the other option: one surface for
an exercise everywhere.

It is the better answer for a reason I had underweighted: the detail screen carries **History**, and
"what did I lift last time" is a question you have mid-workout, not only while browsing.

## Scope (in)

- The ℹ pushes `/exercises/:id/detail`.
- A fallback to the S-013 sheet when the session's snapshot has **no `exerciseId`**.

## The fallback is not defensive padding

A session snapshots its exercises **by value**, so a session can outlive the exercise it was built
from — an ad-hoc entry, or one deleted since. In that case there is no detail screen to open, because
there is no exercise row to open it for. The snapshot still carries name, description, notes and
image, so the sheet still says something useful. Covered by a test that nulls `exerciseId` on a live
session and asserts the sheet appears instead.

S-013 therefore stays; it is no longer the primary path.

## Files touched

- `lib/features/sessions/ui/widgets/session_exercise_card.dart`

## An existing test had to change

`the exercise card header does not overflow at 320dp` tapped ℹ and asserted the **sheet** opened, as
proof the icon was genuinely hit-testable and not merely on-screen. That proof still works, but the
thing that opens is now a screen, so it asserts that instead — and the test needed the routed harness,
since `context.push` throws without a `GoRouter` ancestor.

Worth noting the assertion was well chosen by whoever wrote it: it survived the behaviour change
because it tested *reachability* via a real consequence, rather than testing the sheet.

## Edge cases

- **No `exerciseId` on the snapshot** — the sheet, as above.
- **The exercise deleted while the detail screen is open** — the screen pops itself (T-018).
- The session keeps running underneath; this is a push, and backing out returns to it.

## Acceptance criteria

- [x] Tapping ℹ mid-session opens the detail screen on About.
- [x] A snapshot with no `exerciseId` opens the sheet instead.
- [x] The session is still running when you come back.
- [x] `flutter analyze` clean; `flutter test` passes (370).

## QA checklist (on device)

- [x] Mid-session, tap ℹ → detail opens; History shows previous sessions for that lift.
- [x] Back returns to the running session with the timer intact.

## Revision log
- 2026-08-26 — created and shipped, correcting T-018's assumption once the owner answered.
