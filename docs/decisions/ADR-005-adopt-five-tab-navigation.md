# ADR-005 — Adopt the reference app's 5-tab navigation

- **Status:** Accepted — **implemented 2026-08-23**
- **Date:** 2026-08-23
- **Supersedes:** the "do not copy 5 tabs uncritically" recommendation in
  [05-gap-analysis.md §4](../research/reference-app/05-gap-analysis.md)

## Context

Our MVP ships four tabs — `Home · Workout · History · Profile` — via
`StatefulShellRoute.indexedStack` in `lib/app/router.dart`. The reference app ships five:
`Home · Explore · Workout · Library · You`.

The gap analysis recommended keeping four, on the grounds that two of Explore's three panes
(Programs, Coaches) are out of scope and a tab would be half-empty.

**Owner decision (2026-08-23): match the reference app's navigation.** The rationale is that we are
taking a large amount of UX from that app, and a matching shell keeps every borrowed surface in the
position it was designed for. Screen specs stop needing translation, and the owner's muscle memory
transfers directly.

That reasoning holds, and it outweighs the half-empty-tab objection: an Explore tab containing only
the exercise repository is still a legitimate tab, and it is the tab our exercise library should
have had all along (today it is a pushed route, one level too deep).

## Decision

Adopt **five tabs: `Home · Explore · Workout · Library · You`**, in that order, matching the
reference app's positions.

### Tab mapping

| # | Tab | Contents for us | Built from |
|---|---|---|---|
| 1 | **Home** | Weekly summary (workouts · duration · volume + delta chips), then recent completed sessions | S-007 `home_screen.dart` |
| 2 | **Explore** | The exercise repository: pinned search, then **browse by muscle group and by equipment**. **No sub-tabs** — Programs and Coaches are out of scope | S-011 `exercise_list_screen.dart`, promoted from `/exercises`. **Requires [T-004](../tickets/T-004-exercise-taxonomy.md)** — we have no muscle/equipment fields |
| 3 | **Workout** | Date header + week strip, today's sessions, our templates, suggested routines, FAB | S-008 `workout_screen.dart` |
| 4 | **Library** | Our content: templates/routines, custom exercises, favourites | S-008 + S-011 authoring paths |
| 5 | **You** | Stats hub with 4 sub-tabs (Overview · Exercises · Measures · Photos). Overview carries the **Workout Log → full history** and **Personal Records**. **Settings demoted to a top-bar gear** | S-019 `history_screen.dart` + S-020 `settings_screen.dart` both move here |

### Two consequences that need resolving, not deferring

1. **The History tab moves into `You` → Overview.** *(Owner decision, 2026-08-23, revising the
   earlier "absorbed by Home" note.)* The reference app's Overview pane carries a **Workout Log**
   section — a week dot-strip plus a `See full workout history` link — and that link is where our
   `HistoryScreen` lives. No history is lost from the product; only the tab is. This is a better fit
   than Home: Home is recap, Overview is the analysis surface, and it keeps the full list one
   deliberate tap away instead of occupying a permanent tab.
2. **Explore and Library overlap on exercises.** In the reference app, Explore is *everyone's*
   content and Library is *yours* — a distinction that mostly evaporates once the community half is
   gone, since every exercise in our app is ours. Resolution: **Explore is the browse/search surface
   over all exercises; Library is the authoring surface** (create, edit, favourite, and manage
   templates). Same data, different verbs. If that split still feels thin after living with it, the
   fallback is to fold Explore's contents into Library and drop to four tabs — recorded here so the
   option isn't forgotten.

### What is not adopted

Tab *positions and labels* are adopted. Tab *contents* are not: no Programs, no Coaches, no feed,
no likes/comments/share, no challenges. Matching navigation is not a licence to import the social
product ([00-overview §5](../research/reference-app/00-overview.md#5-explicitly-out-of-scope)).

## Consequences

- `app_shell.dart` grows from four to five destinations. The hand-built nav bar (deliberately not a
  Material `NavigationBar`, to avoid the stock pill indicator) must stay legible at five items —
  **check label truncation at 5 items on a narrow screen** before considering this done.
- `router.dart` gains two `StatefulShellBranch`es (Explore, Library); `/exercises` is promoted from a
  pushed route to a branch root; `/profile` stops building `SettingsScreen` and gets a real `You`.
- Settings needs a new home (top-bar icon on You) and a route that is no longer a tab.
- Deep links change. Ours is a personal APK with no external links, so no compatibility burden.
- **The five tabs are not equally ready.** You is nearly empty until the stats hub exists, and
  Library needs an authoring surface. The roadmap sequenced the shell last for that reason; the owner
  chose to land it first instead (2026-08-23) and fill the screens after. Both new tabs therefore ship
  as honest hubs — real counts, real entry points, and plain text saying what does not exist yet —
  rather than placeholders dressed up as content.
- **Found on implementation:** five labels no longer fit a narrow phone. The nav bar is hand-built,
  so nothing caught it — the labels silently wrapped to a second line and overflowed. Labels are now
  `FittedBox(scaleDown)`, and a test asserts no overflow at 320dp.

## Alternatives considered

- **Keep four tabs.** The gap analysis's recommendation. Rejected by the owner in favour of matching
  the reference app, for spec-fidelity and muscle-memory reasons that hold up.
- **Five tabs immediately, contents later.** Rejected: a `You` tab that shows nothing is worse than
  no tab. Sequenced in the roadmap instead.
