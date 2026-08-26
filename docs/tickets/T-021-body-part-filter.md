# T-021 — Filter the exercise library by body part (S-026)

- **Status:** **Done** (2026-08-26) — `flutter analyze` clean, 383 tests pass.
- **Priority:** Should
- **Effort:** S
- **Specs:** S-026, S-011, S-002, ADR-006
- **Last updated:** 2026-08-26

## Goal

The gap analysis named this one: *"No filtering by muscle group; no active-filter count."* The
library could only be searched by name, so [T-004](T-004-exercise-taxonomy.md) and
[T-005](T-005-plural-primary-muscles.md) tagged every exercise with body parts and nothing ever used
them for finding anything.

## Scope (in)

- A body-part chip per `BodyPart`, in the **same scrolling strip** as the existing Favourites chip —
  S-026's "one row doing two jobs".
- Tapping the active chip clears it, so no separate "All" chip is needed.
- The filter is app state, so the list and the picker agree and it survives navigating away.

## Scope (out)

- **The filter-count badge** (CMP-026). The reference needs one *because its filters are hidden
  behind an icon*; ours are visible chips, so the count is already on screen. Building a badge to
  count what you can see would be cargo-culting the pattern rather than the reason for it.
- The grid/list layout toggle, per-card bookmark and `?` affordances, and the `+` inside the picker.
- **`Recent Performed` first when adding mid-session.** Genuinely worth doing — S-026 is right that
  mid-set you almost always want something you have done before, and `exerciseHistory` (T-018)
  already gives us the data. Left as a follow-up rather than smuggled in here.

## Decisions

- **Filtered against `bodyPartsByExerciseProvider`**, the map the list already loads for its
  subtitles, rather than a new query or a query per row.
- **An untagged exercise is hidden by any body-part filter.** Untagged is the normal state early on
  (ADR-006), so this genuinely hides things — but a filter that also returned everything untagged
  would not be a filter. Pinned by a test so the consequence is deliberate rather than discovered.

## A real defect the tests caught

The first implementation filtered against `valueOrNull ?? const {}`. While the body-part map was
still loading, that made **every exercise fail the filter**, so selecting a chip emptied the list for
a frame — reading as *"you have no chest exercises"*, which the user has no way to distinguish from
the truth.

Now it passes through unfiltered until the map arrives. Showing everything briefly is a visible,
self-correcting state; showing nothing is a convincing lie.

Worth noting the test that caught it nearly missed it: `pumpUntilGone(find.text('Back Squat'))`
succeeded for the *wrong reason* — Squat had indeed gone, along with everything else. The test now
waits for the filtered state (the match present **and** the non-match absent) rather than for one row
to vanish.

## Files touched

- `lib/features/exercises/providers/exercise_providers.dart` — `exerciseBodyPartFilterProvider`,
  and the filter inside `filteredExercisesProvider`
- `lib/features/exercises/ui/exercise_list_screen.dart` — the chip strip

## Model / DB changes

**None.** The taxonomy already existed; nothing was reading it.

## Acceptance criteria

- [x] A chip per body part sits beside Favourites in one scrolling strip.
- [x] Selecting one filters the list.
- [x] Tapping the active chip clears the filter.
- [x] An untagged exercise is hidden by any body-part filter.
- [x] The list is never briefly empty while the map loads.
- [x] `flutter analyze` clean; `flutter test` passes (383).

## QA checklist (on device)

- [ ] Tag two exercises with different body parts; each chip shows only its own.
- [ ] Combine a chip with a search term and with Favourites.
- [ ] Clear-search / clear-filter empty states still offer a way back.

## Revision log
- 2026-08-26 — created and shipped.
