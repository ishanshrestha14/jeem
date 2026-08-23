# T-004 — Muscle group + equipment taxonomy on exercises

- **Status:** **Done** (2026-08-23) — `flutter analyze` clean, 199 tests pass. APK build not verified (no Android SDK in this environment).
- **Priority:** Must (MVP scope, owner 2026-08-23)
- **Effort:** L
- **Specs:** S-002, S-025, S-026, CMP-022, CMP-024
- **Governed by:** [ADR-006](../decisions/ADR-006-exercise-library-phasing.md)
- **Roadmap item:** moved into MVP scope; prerequisite for the Explore tab (Phase 3)
- **Last updated:** 2026-08-23

## Goal

Make exercises browsable **by muscle group** and **by equipment** — the two organising axes of the
Explore tab (S-002). Neither is expressible today: `Exercises` has one nullable `category` text
column and nothing else.

## Scope (in)

- Add to `Exercises` (`lib/db/tables.dart`): `primaryMuscle`, `equipment`, **`isFavourite`**. The
  first two nullable so existing rows stay valid.
- **Secondary muscles** (owner-confirmed 2026-08-23; confirmed visually by S-025's red primary /
  blue secondary encoding): a **join table** `ExerciseSecondaryMuscles(exerciseId, muscle)`, since an
  exercise has several. Do not encode this as a delimited string column.
- **Merge `category` into `primaryMuscle`** (owner-confirmed): migrate existing values across, then
  drop `category`. One field, one meaning — no parallel taxonomy left behind.
- Decide and fix the **vocabularies** — a closed enum, not free text, or the grids will not group.
  Starting sets drawn from the reference app's own grid: quadriceps, hamstrings, glutes/hips, calves,
  forearms, neck, chest, back, shoulders, biceps, triceps, abs, cardio; barbell, dumbbell, cable,
  machine, bodyweight, band, other.
- Migration: **schema v3**. T-002 is blocked pending a screenshot, so T-004 lands first and takes
  v3; **T-002 then becomes v4**. Recorded here so the two cannot collide.
- Backfill the seeded exercises in `lib/db/seed_exercises.dart` with correct values.
- Expose primary muscle, secondary muscles and equipment in the exercise editor (S-012), all optional.
- **Favourites filter on the exercise list (S-011) is in scope for this ticket** (owner 2026-08-23):
  the `isFavourite` toggle plus a filter control. Without muscle tags in Phase A, favourites are the
  primary way to reach go-to exercises without searching every time.
- Extend JSON export/import to round-trip them.

## Scope (out)

- The Explore tab UI itself, and muscle-based filtering — separate ticket once this lands (Later).
- Per-exercise History / Progress panes and charts — **Later**, explicitly not MVP (owner 2026-08-23).
- The pre-built exercise catalogue — Phase B of ADR-006.
- Auto-tagging or inferring muscles from exercise names.
- Any anatomical or equipment artwork — see below.

## Files to touch

- `lib/db/tables.dart`, `lib/db/app_database.dart` (migration), `lib/db/seed_exercises.dart`
- `lib/features/exercises/data/exercise_repository.dart`, `providers/exercise_providers.dart`
- `lib/features/exercises/ui/exercise_editor_screen.dart`
- `lib/core/services/backup_service.dart`

## Model / DB changes

Two nullable columns on `Exercises`, backed by enums in Dart. Nullable rather than defaulted, so
"untagged" stays distinguishable from "wrongly tagged as chest".

## Edge cases

- **User-created exercises** may be left untagged — the grid needs an `Untagged` bucket, or those
  exercises become unreachable by browsing (search still finds them).
- **Migration ordering with T-002** — both bump `schemaVersion`. Whichever lands second must take the
  next number; do not develop them in parallel without agreeing the order.
- **Duration/stretch exercises** may have no meaningful equipment. Nullable covers it.
- **Pre-v4 backups** must still import (fields absent → null).
- **`category` values may not map cleanly** onto the muscle vocabulary (a value like "Stretch" or
  "Push" is not a muscle). Map what maps, leave the rest null, and **do not silently drop data** —
  log or preserve unmapped values so nothing is lost in the migration.
- **Favourites in Phase A**: with most exercises untagged (ADR-006), the favourites filter is the
  primary way to shorten a long flat list — so `isFavourite` must be usable before any tagging
  exists.

## Artwork — decided

**Text + icon cells** (owner decision 2026-08-23). No illustrations, no traced or approximated
anatomy. A properly resourced visual library is Phase B of
[ADR-006](../decisions/ADR-006-exercise-library-phasing.md).

## Acceptance criteria

- [ ] Schema migrates with no data loss.
- [ ] Every seeded exercise has a primary muscle and equipment value.
- [ ] An exercise can carry several secondary muscles, and they persist.
- [ ] `category` values are migrated into `primaryMuscle` with nothing silently lost; `category` is gone.
- [ ] An exercise can be favourited, and the flag survives a restart.
- [ ] Untagged exercises remain visible and findable — untagged is the **normal** state in Phase A.
- [ ] The exercise editor can set and change both.
- [ ] Exercises can be queried by muscle group and by equipment.
- [ ] Untagged exercises remain findable via search.
- [ ] Export/import round-trips both fields; older backups still import.
- [ ] `flutter test` passes, including a migration test.

## QA checklist (on device)

- [ ] Upgrade over an existing install — exercises, templates and history intact.
- [ ] Edit an exercise's muscle/equipment; reopen and confirm it persisted.
- [ ] Create a new exercise leaving both blank — no crash anywhere.
- [ ] Export, reinstall, import — tags return.

## Open questions

- [x] `category` **merges** into `primaryMuscle` (owner-confirmed 2026-08-23).
- [x] **Primary + secondaries** (owner-confirmed 2026-08-23).
- [x] Equipment stays **single-valued** for MVP (owner 2026-08-23). Multi-equipment cases go in the
      notes field; migrate later only if it proves painful.

## What shipped

- `Muscle` (20 values) and `Equipment` (7 values) enums in `lib/db/tables.dart`.
- `Exercises`: `+primaryMuscle`, `+equipment`, `+isFavourite`; `−category`.
- New `ExerciseSecondaryMuscles` join table, cascade-deleted with its exercise.
- Schema **v3** migration: adds columns, creates the join table, backfills tags by exercise name,
  drops `category` via `TableMigration`, then **inserts seed exercises the install is missing**.
- `seed_exercises.dart` rewritten: typed tags, **34 → 55 exercises** (21 added from the owner's real
  routine, 2026-08-23).
- `muscleLabel` / `equipmentLabel` in `core/utils/formatting.dart` — written out, not derived from
  enum names, so renaming a value can never silently change UI copy.
- Editor: primary-muscle and equipment dropdowns, secondary-muscle `FilterChip`s (the primary is
  excluded from the secondary list — a muscle can't be both).
- List: per-row favourite star, a `Favourites` filter chip, and a **third empty state** for
  "filtered to favourites, none yet" — distinct from "empty library" and "search matched nothing",
  because the right CTA differs in each.
- Backup: round-trips all new fields plus the join table; unknown enum values and missing keys
  degrade to null rather than failing the whole import.
- Tests: `test/db/migration_v2_to_v3_test.dart` builds a real v2 database and upgrades it.

## Deviations from the plan

- **One-time seed backfill added.** Not in the original scope. `seedIfEmpty` no-ops when any
  exercise exists, so on an existing install the 21 new exercises would never have appeared. The
  backfill runs inside the v3 upgrade — **once**, not per launch, so a deliberately deleted exercise
  is not resurrected on every start. Archived and soft-deleted rows count as present.
- **Seed grew 34 → 55**, from two owner messages during implementation.

## Revision log
- 2026-08-23 — created from `ref-S002-explore-exercises.png`.
- 2026-08-23 — implemented. Schema v3, 55 seed exercises, favourites filter, migration test.
