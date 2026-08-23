# T-005 — Correct the exercise taxonomy: body parts + plural muscles (schema v4)

- **Status:** **Done** (2026-08-23) — `flutter analyze` clean, 200 tests pass. APK build not verified (no Android SDK here).
- **Priority:** Must (corrects T-004)
- **Effort:** L (was M, widened 2026-08-23)
- **Specs:** S-025, S-027, S-002, S-026
- **Corrects:** [T-004](T-004-exercise-taxonomy.md)
- **Last updated:** 2026-08-23

## Goal

Two defects in the v3 taxonomy, found from two screenshots:

1. **Primary is plural.** `ref-S025-exercise-detail-target-muscles.png` lists two primaries for one
   exercise (Latissimus dorsi + Middle trapezius). v3 has a single `primaryMuscle` column.
2. **Body part and muscle are separate axes.** `ref-S027-create-exercise-form.png` shows
   `Body Parts` **and** `Primary muscles` as distinct fields. v3 has one `Muscle` enum doing both
   jobs — which is why it awkwardly mixes granularities (`chest`, `abs` are body parts;
   `deltsFront`, `hipFlexors` are muscles).

Both are **modelling errors in what just shipped**, not new features. The evidence for each was
absent from the screenshots available when T-004 was designed; the assumptions were mine.

### Why two axes rather than one

They do different jobs, and the reference app uses them in different places:

| | Body part | Muscle |
|---|---|---|
| Granularity | `Back`, `Chest`, `Biceps` | `Latissimus dorsi`, `Middle trapezius` |
| Used for | picker card subtitles, Explore grid grouping, filter strip | the Target Muscles legend, primary/secondary roles |
| Cardinality | plural | plural, with a role |

Collapsing them forces one vocabulary to be both browsable (needs ~8 buckets) and precise (needs
~30 values). That is the tension already visible in our v3 enum.

## Why fix it now rather than live with it

Compound movements are the majority of the library, and they are exactly where one primary is wrong:
a row is lats **and** mid-traps, a deadlift is hamstrings **and** glutes **and** erectors. A muscle
filter built on a single primary would silently under-report half the library — and the filter UI
(Explore, Phase 3) is built directly on this data. Fixing after that UI exists means changing both.

The dataset is also at its smallest and most disposable right now: 55 seeded exercises, one user,
one device.

## Scope (in)

Two relations, replacing the v3 column-plus-join-table pair:

```
ExerciseMuscles(exerciseId, muscle, role)   role: primary | secondary
PRIMARY KEY (exerciseId, muscle)

ExerciseBodyParts(exerciseId, bodyPart)
PRIMARY KEY (exerciseId, bodyPart)
```

A muscle appears at most once per exercise, so it cannot be both primary and secondary — the same
invariant the editor enforces today, now enforced by the key.

**New `BodyPart` enum** (proposed, ~10): `chest` · `back` · `shoulders` · `arms` · `core` · `legs` ·
`glutes` · `calves` · `neck` · `cardio`. Deliberately coarse — this is the browse axis.

**`Muscle` stays as-is for now.** Retuning it toward finer anatomical names (splitting `biceps` into
biceps brachii / brachialis, `upperBack` into trapezius / rhomboids) is a **separate** pass; doing
it inside a structural migration would make both harder to review.

**Backfill:** every v3 `primaryMuscle` becomes a `primary` row, every `ExerciseSecondaryMuscles` row
becomes a `secondary` row, and each exercise's body parts are derived from its seed tags. Derivation
is a straight map (`lats`/`upperBack`/`lowerBack` → `back`; `biceps`/`triceps`/`forearms` → `arms`;
`quadriceps`/`hamstrings` → `legs`; …) — mechanical, and reviewable in the appendix before it runs.

- Schema **v4**: create `ExerciseMuscles`, migrate every `primaryMuscle` value to a `primary` row and
  every `ExerciseSecondaryMuscles` row to a `secondary` row, drop the old column and table.
- `seed_exercises.dart`: `primaryMuscle` → `primaryMuscles` (a list). **Values stay as tagged** —
  this ticket changes cardinality, not anyone's tags. Revisiting individual exercises that deserve a
  second primary is a follow-up, deliberately not bundled here.
- Repository: `primaryMuscles(id)`, `setMuscles(id, primary:, secondary:)`, and filtering that
  matches **any** role.
- Editor: primary becomes multi-select chips, mirroring secondary; body parts become a third
  multi-select. Everything stays optional except the name (S-027).
- Info sheet: two labelled groups with the reference's coloured-dot legend — `● Primary` / `● Secondary`.
- List/picker subtitle: **body parts**, not muscles (matching S-026's cards).
- Backup: export/import `exerciseMuscles` and `exerciseBodyParts`; **read the v3 keys too** so a
  backup taken between yesterday and today still imports.

## Scope (out)

- Re-tagging exercises to add second primaries — separate pass, needs your judgement per exercise.
- Finer anatomical vocabulary (splitting `biceps` → biceps brachii / brachialis, etc.). A separate
  pass once the browse UI shows whether the coarse terms actually get in the way.
- `Recent Performed` in the picker (S-026) — a good pattern, but a query change, not a schema one.
- Additional `Exercise Type` values beyond our two logging types.
- Any Explore browse UI.

## Files to touch

`lib/db/tables.dart` · `lib/db/app_database.dart` · `lib/db/seed_exercises.dart` ·
`lib/features/exercises/data/exercise_repository.dart` · `providers/exercise_providers.dart` ·
`ui/exercise_editor_screen.dart` · `ui/exercise_list_screen.dart` · `ui/exercise_picker_sheet.dart` ·
`ui/exercise_info_sheet.dart` · `lib/features/templates/ui/template_editor_screen.dart` ·
`lib/core/services/backup_service.dart` · `lib/core/utils/formatting.dart` ·
`test/db/migration_v2_to_v3_test.dart` (extend to v4) · exercise/backup/template tests

## Edge cases

- **A v2 install upgrading straight to v4** must pass through both steps — v2 → v3 → v4 in one open.
  The existing v3 test proves the first leg; extend it rather than replace it.
- **Untagged exercises** produce no rows at all. `LEFT JOIN`, never `INNER`, or they vanish from the
  list entirely.
- **v3-era backups** carry `primaryMuscle` + `exerciseSecondaryMuscles`; import must still accept
  them. Backups are the one artefact that outlives the schema.
- **Ordering.** The reference lists "Latissimus dorsi" before "Middle trapezius" — possibly
  significant, possibly alphabetical. We have no order column; if display order turns out to matter,
  that is another change. Assuming unordered for now.
- The editor must stop a muscle being selected as both roles — now a key violation, not just untidy.

## Acceptance criteria

- [ ] An exercise can carry two or more primary muscles.
- [ ] An exercise can carry one or more body parts, independent of its muscles.
- [ ] Picker and list subtitles show body parts.
- [ ] v3 → v4 migrates every existing primary and secondary with nothing lost.
- [ ] v2 → v4 in a single open produces the same result.
- [ ] A muscle cannot be both primary and secondary for one exercise.
- [ ] Untagged exercises still appear everywhere they did before.
- [ ] v3-era and pre-v3 backups both still import.
- [ ] Info sheet shows Primary and Secondary as separate labelled groups.
- [ ] `flutter analyze` clean; full suite passes; migration tests cover v2→v4 and v3→v4.

## QA checklist (on device)

- [ ] Upgrade over the v3 install — every tag survives, nothing duplicated.
- [ ] Give an exercise two primaries; reopen and confirm both persisted.
- [ ] Export → reinstall → import; both primaries return.
- [ ] Import the backup taken before this ticket — still works.

## What shipped

- `BodyPart` (10 values) and `MuscleRole` (primary/secondary) enums.
- **`ExerciseMuscles(exerciseId, muscle, role)`** — replaces the `primaryMuscle` column *and*
  `ExerciseSecondaryMuscles`. The composite key makes "a muscle cannot hold both roles" a database
  invariant.
- **`ExerciseBodyParts(exerciseId, bodyPart)`** — the coarse browse axis, settable independently.
- `bodyPartForMuscle()` — the derivation map, used by both the migration and seeding so the two axes
  start consistent without 55 hand-written lists.
- Schema **v4**, covering both upgrade paths: **v2 → v4** in one open (tags staged during the v3 leg,
  written once v4's tables exist) and **v3 → v4** (raw-SQL read of the departing column and table).
- Repository: `ExerciseTaxonomy`, `taxonomy()`, `setTaxonomy()`, `watchBodyPartsByExercise()`.
- Editor: three chip sections — body parts, primary muscles, secondary muscles.
- Info sheet: a `Target muscles` block with the reference app's coloured-dot legend
  (● Primary / ● Secondary), rendering nothing at all when untagged.
- List and picker subtitles now show **body parts**, capped at two with `+n`.
- Backup: exports `exerciseMuscles` + `exerciseBodyParts`, and **reads all three generations** —
  pre-v3 (no taxonomy), v3 (`primaryMuscle` + `exerciseSecondaryMuscles`), v4.
- `test/db/migration_test.dart` (renamed from `migration_v2_to_v3_test.dart`) covers v2→v4, v3→v4,
  and a fresh v4 install.

## Decisions made during implementation

- **Body parts derive from primary muscles until you touch them.** The editor tracks primaries
  automatically and stops the moment you edit body parts by hand; anything already stored counts as
  deliberate. Tagging an exercise shouldn't mean entering the same information twice, but derivation
  must never overwrite a considered choice.
- **`Muscle` values were not retuned.** Still coarse (`biceps`, not biceps brachii + brachialis).
  Out of scope, as planned — a structural migration and a vocabulary change should be reviewable
  separately.
- **Seed primaries stay single-valued.** The cardinality is now there; deciding that Barbell Row
  deserves `upperBack` as a second primary is a judgement pass, deliberately not bundled.
- **`insertOrIgnore` on taxonomy imports**, so a malformed backup with a muscle in both roles imports
  with primary winning rather than failing outright.

## Revision log
- 2026-08-23 — created from `ref-S025-exercise-detail-target-muscles.png`; corrects T-004.
- 2026-08-23 — widened after `ref-S027-create-exercise-form.png`: body parts are a **separate axis**
  from muscles, so v4 adds `ExerciseBodyParts` and a `BodyPart` enum alongside the role-based
  `ExerciseMuscles`. Effort M → L.
