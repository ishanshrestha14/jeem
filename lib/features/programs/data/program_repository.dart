import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ids.dart';
import '../../../db/app_database.dart';

/// A program plus the routines it holds, in order.
class ProgramWithRoutines {
  const ProgramWithRoutines({required this.program, required this.routines});

  final WorkoutProgram program;

  /// Membership rows paired with the template each points at. A template can
  /// appear twice (an A/B/A week), so this is a list, not a map.
  final List<({ProgramRoutine membership, WorkoutTemplate template})> routines;
}

class ProgramSummary {
  const ProgramSummary({required this.program, required this.routineCount});

  final WorkoutProgram program;
  final int routineCount;
}

class ProgramRepository {
  ProgramRepository(this._db);

  final AppDatabase _db;

  /// Programs with their routine counts. Counts exclude soft-deleted
  /// templates: a routine you deleted must not keep inflating the count of a
  /// program that can no longer show it.
  Stream<List<ProgramSummary>> watchSummaries() {
    final programs = (_db.select(_db.workoutPrograms)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .watch();

    return programs.asyncMap((rows) async {
      final out = <ProgramSummary>[];
      for (final program in rows) {
        final count = await _liveRoutineCount(program.id);
        out.add(ProgramSummary(program: program, routineCount: count));
      }
      return out;
    });
  }

  Future<int> _liveRoutineCount(String programId) async {
    final query = _db.select(_db.programRoutines).join([
      innerJoin(
        _db.workoutTemplates,
        _db.workoutTemplates.id.equalsExp(_db.programRoutines.templateId),
      ),
    ])
      ..where(_db.programRoutines.programId.equals(programId) &
          _db.programRoutines.deletedAt.isNull() &
          _db.workoutTemplates.deletedAt.isNull());
    return (await query.get()).length;
  }

  Stream<ProgramWithRoutines?> watchProgram(String id) {
    final program = (_db.select(_db.workoutPrograms)
          ..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
    return program.asyncMap((row) async {
      if (row == null) return null;
      return ProgramWithRoutines(program: row, routines: await _routines(id));
    });
  }

  Future<List<({ProgramRoutine membership, WorkoutTemplate template})>>
      _routines(String programId) async {
    final query = _db.select(_db.programRoutines).join([
      innerJoin(
        _db.workoutTemplates,
        _db.workoutTemplates.id.equalsExp(_db.programRoutines.templateId),
      ),
    ])
      ..where(_db.programRoutines.programId.equals(programId) &
          _db.programRoutines.deletedAt.isNull() &
          _db.workoutTemplates.deletedAt.isNull())
      ..orderBy([OrderingTerm(expression: _db.programRoutines.sortOrder)]);

    final rows = await query.get();
    return [
      for (final row in rows)
        (
          membership: row.readTable(_db.programRoutines),
          template: row.readTable(_db.workoutTemplates),
        ),
    ];
  }

  Future<WorkoutProgram> create({required String name, String? notes}) async {
    final now = DateTime.now();
    final row = WorkoutProgram(
      id: newId(),
      name: name.trim(),
      notes: notes,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _db.into(_db.workoutPrograms).insert(row);
    return row;
  }

  Future<void> rename(String id, String name, {String? notes}) async {
    await (_db.update(_db.workoutPrograms)..where((t) => t.id.equals(id)))
        .write(WorkoutProgramsCompanion(
      name: Value(name.trim()),
      notes: Value(notes),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Soft delete, matching how templates are removed — history and backups
  /// keep referring to ids long after the user is done with them.
  Future<void> delete(String id) async {
    await (_db.update(_db.workoutPrograms)..where((t) => t.id.equals(id)))
        .write(WorkoutProgramsCompanion(
      deletedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> addRoutine({
    required String programId,
    required String templateId,
  }) async {
    final existing = await _routines(programId);
    final now = DateTime.now();
    await _db.into(_db.programRoutines).insert(ProgramRoutine(
          id: newId(),
          programId: programId,
          templateId: templateId,
          sortOrder: existing.length,
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
        ));
    await _touch(programId);
  }

  Future<void> removeRoutine(String membershipId) async {
    final row = await (_db.select(_db.programRoutines)
          ..where((t) => t.id.equals(membershipId)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.programRoutines)
          ..where((t) => t.id.equals(membershipId)))
        .go();
    await _resequence(row.programId);
    await _touch(row.programId);
  }

  Future<void> reorder(String programId, int oldIndex, int newIndex) async {
    final rows = await _routines(programId);
    if (oldIndex < 0 || oldIndex >= rows.length) return;
    final ids = [for (final r in rows) r.membership.id];
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(0, ids.length), moved);
    await _writeOrder(ids);
    await _touch(programId);
  }

  /// Rewrites sortOrder to 0..n-1 so removals never leave gaps that a later
  /// insert would collide with.
  Future<void> _resequence(String programId) async {
    final rows = await _routines(programId);
    await _writeOrder([for (final r in rows) r.membership.id]);
  }

  Future<void> _writeOrder(List<String> membershipIds) async {
    final now = DateTime.now();
    await _db.batch((b) {
      for (var i = 0; i < membershipIds.length; i++) {
        b.update(
          _db.programRoutines,
          ProgramRoutinesCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          where: (t) => t.id.equals(membershipIds[i]),
        );
      }
    });
  }

  /// Bumps the program's updatedAt so the library's "Recent" ordering
  /// reflects edits to its contents, not just to its name.
  Future<void> _touch(String programId) async {
    await (_db.update(_db.workoutPrograms)..where((t) => t.id.equals(programId)))
        .write(WorkoutProgramsCompanion(updatedAt: Value(DateTime.now())));
  }
}

final programRepositoryProvider = Provider<ProgramRepository>(
  (ref) => ProgramRepository(ref.watch(databaseProvider)),
);
