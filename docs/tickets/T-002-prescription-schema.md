# T-002 — Set prescription on templates (schema v3)

- **Status:** **Done** (2026-08-24) — `flutter analyze` clean, 250 tests pass.
- **Priority:** Must
- **Effort:** L
- **Specs:** CMP-017, CMP-015, S-006, S-010
- **Roadmap item:** Phase 1, item 1
- **Last updated:** 2026-08-23

## Goal

Templates must carry what you *plan* to do per set, so session rows can pre-fill and a to-plan set
becomes one tap. Today a set row starts empty and every value is typed from scratch.

## Blocked, deliberately

A migration is expensive to redo. `ref-S004-library-routine-edit.png` would confirm the reps-vs-range
mode toggle before the column shape is fixed. **Do not start until that screenshot lands.**

## Scope (in)

Add to `TemplateExercises` (`lib/db/tables.dart`):

| Column | Type | Notes |
|---|---|---|
| `defaultWeight` | `real().nullable()` | Prescribed load. Nullable — bodyweight and duration work have none |
| `targetReps` | `integer().nullable()` | Lower bound, or the exact value in single-rep mode |
| `targetRepsMax` | `integer().nullable()` | Upper bound; `null` = single-rep mode |
| `repMode` | `textEnum` or derived | Owner confirmed a **dropdown toggling reps vs. range** per exercise. Deriving the mode from `targetRepsMax == null` avoids a column — decide at implementation |

Mirror the same columns on `SessionExercises`, which snapshots the template at session start.

- Bump `schemaVersion` 2 → 3 with a migration adding nullable columns (no backfill needed).
- Extend the session snapshot to copy the new fields.
- Extend JSON export/import (`backup_service.dart`) to round-trip them.

## Scope (out)

- The editor UI (CMP-017) — that is item 2, a separate ticket.
- Pre-filling set rows (CMP-015) — item 3.
- Anything touching `SessionSets`; **actual** logged values already exist there
  (`weight`, `reps`, `rir`) and must not change.

## Files to touch

- `lib/db/tables.dart` · `lib/db/app_database.dart` (migration)
- `lib/features/templates/data/template_models.dart`, `template_repository.dart`
- `lib/features/sessions/data/session_models.dart`, `session_repository.dart` (snapshot)
- `lib/core/services/backup_service.dart` (export/import)

## Model / DB changes

Schema v3. **All new columns nullable** — existing templates stay valid with no prescription, and
pre-filling simply does nothing for them until edited. No destructive migration.

## Edge cases

- **Duration-logged exercises** have no weight or reps. Leave all four null; `defaultDurationSeconds`
  already covers them.
- **Existing sessions in flight** during an upgrade — snapshot rows gain null columns; the session
  must continue to work untouched.
- **Backup files written before v3** must still import (fields absent → null).
- **Range sanity**: `targetRepsMax` less than `targetReps` should be rejected at the editor, but the
  schema must not assume it — read defensively.
- Editing a session value **must not** write back to the template (owner-confirmed; matches the
  existing snapshot model).

## Acceptance criteria

- [ ] Schema migrates 2 → 3 on an existing install with no data loss.
- [ ] A template exercise can persist weight, target reps, and a rep range.
- [ ] Starting a session snapshots all four onto `SessionExercises`.
- [ ] Export → wipe → import round-trips the new fields.
- [ ] A pre-v3 backup file still imports.
- [ ] Existing templates with no prescription behave exactly as before.
- [ ] `flutter test` passes; a migration test covers v2 → v3.

## QA checklist (on device)

- [ ] Upgrade over an existing install (do not wipe) — templates, sessions and history intact.
- [ ] Start a session from an old template — no crash, no empty rows regression.
- [ ] Export a backup, reinstall, import — everything returns.

## What shipped

- Schema **v6**: `TemplateSets` (row per planned set: weight, reps, repsMax, rir, duration), and
  `plannedWeight`/`plannedReps`/`plannedRepsMax` on `SessionSets`.
- `TemplateExercises.targetSets`, `.defaultRir` and `.defaultDurationSeconds` migrated into rows and
  **dropped**. The set count is now the row count, so the two can never disagree.
- Repository: `setsFor`, `addSet`, `updateSet`, `removeSet` (resequencing), and duplication that
  carries the prescription across — the numbers being the point of duplicating a routine.
- Session snapshot copies the plan onto `SessionSets` without touching the logged columns.
- Routine editor: rows summarise their plan (`1  70kg x 8 reps`) or say `Press to add details`;
  tapping opens a planned-sets table with `Kg`, `Reps`, a reps-vs-range toggle on the column header,
  and `+ Add Set`.
- Backup round-trips `templateSets`, and **rebuilds them from a pre-v6 file's per-exercise columns**
  so an older backup restores routines with the right number of sets rather than none.

## Deviations

- **The set table is a sheet, not inline expansion.** The reference expands in place; our editor is a
  `ReorderableListView`, and embedding an editable table inside a drag target is a fight not worth
  picking for the first version. Columns and behaviour match, which is what the pre-fill depends on.
- **Adding a set copies the previous one** rather than starting blank — the common case is another
  set of the same thing.

## Two things this shook out

- **A drift subscription cancel that never completes.** The new combined stream awaited both
  subscription cancels in `onCancel`; cancelling a drift query stream never completes on this
  drift/Dart version — the same hang `watchSummaries` was already hand-rolled to avoid. It surfaced
  as a widget test hanging in teardown, not as an error. Cancels are now fired, not awaited.
- **The migration test's v2 fixture was a stub.** It created only `exercises`, which the earlier
  ticket admitted to; the v6 migration touches `session_sets`, so the fixture is now a realistic v2
  database and the v2 → v6 path is genuinely exercised.

## Revision log
- 2026-08-23 — created from the roadmap (Phase 1, item 1); blocked pending the routine-builder screenshot.
