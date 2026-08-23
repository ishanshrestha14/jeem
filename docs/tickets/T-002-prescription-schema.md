# T-002 — Set prescription on templates (schema v3)

- **Status:** Blocked — awaiting `ref-S004-library-routine-edit.png`
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

## Revision log
- 2026-08-23 — created from the roadmap (Phase 1, item 1); blocked pending the routine-builder screenshot.
