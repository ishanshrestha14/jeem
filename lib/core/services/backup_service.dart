import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../db/app_database.dart';

/// Exports every DB row (all six tables) to a single JSON document and
/// imports it back, replacing whatever was already in the database.
///
/// `shared_preferences`-backed settings (old — sound/haptics/keep-screen-on
/// — and new — weight unit/default rest) are never part of this payload:
/// only DB rows travel through a backup. Image files are not included either
/// — `imagePath` values are exported as-is, and an import on a different
/// device simply shows the placeholder for any exercise whose image doesn't
/// exist at that path locally.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const backupVersion = 1;

  Future<String> exportJson() async {
    final exercises = await _db.select(_db.exercises).get();
    final templates = await _db.select(_db.workoutTemplates).get();
    final templateExercises = await _db.select(_db.templateExercises).get();
    final sessions = await _db.select(_db.workoutSessions).get();
    final sessionExercises = await _db.select(_db.sessionExercises).get();
    final sessionSets = await _db.select(_db.sessionSets).get();

    final payload = <String, dynamic>{
      'version': backupVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'exercises': exercises.map(_exerciseToJson).toList(),
      'workoutTemplates': templates.map(_templateToJson).toList(),
      'templateExercises':
          templateExercises.map(_templateExerciseToJson).toList(),
      'workoutSessions': sessions.map(_sessionToJson).toList(),
      'sessionExercises': sessionExercises.map(_sessionExerciseToJson).toList(),
      'sessionSets': sessionSets.map(_sessionSetToJson).toList(),
    };
    return jsonEncode(payload);
  }

  /// Writes [exportJson]'s output to a temp file so it can be handed to
  /// `Share.shareXFiles`.
  /// [directory] exists so tests can point this at a path that does not yet
  /// exist; production always uses the platform temp directory.
  Future<File> exportToFile({Directory? directory}) async {
    final json = await exportJson();
    final dir = directory ?? await getTemporaryDirectory();
    // `getTemporaryDirectory` returns a *path*, not a guaranteed directory:
    // on macOS it is `Library/Caches/<bundle-id>`, which the OS does not
    // create for a freshly installed sandboxed app. Writing straight into it
    // fails with PathNotFoundException (errno 2) until something creates it.
    // Harmless where the directory already exists, e.g. Android's cacheDir.
    await dir.create(recursive: true);
    final stamp =
        DateTime.now().toUtc().toIso8601String().replaceAll(RegExp('[:.]'), '-');
    final file = File(p.join(dir.path, 'gymflow-backup-$stamp.json'));
    await file.writeAsString(json);
    return file;
  }

  /// Validates `version` FIRST, before touching the database at all, so a
  /// malformed or wrong-version file can't destroy existing data. The
  /// replace itself runs inside one transaction: delete all six tables in
  /// FK-safe order, then batch-insert in the reverse order — either the
  /// whole import lands or none of it does.
  Future<void> importJson(String jsonStr) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Not a valid backup file: $e');
    }

    final version = data['version'];
    if (version != backupVersion) {
      throw FormatException(
        'Unsupported backup version: $version (expected $backupVersion)',
      );
    }

    final exercises = _list(data['exercises']).map(_exerciseFromJson).toList();
    final templates =
        _list(data['workoutTemplates']).map(_templateFromJson).toList();
    final templateExercises = _list(data['templateExercises'])
        .map(_templateExerciseFromJson)
        .toList();
    final sessions =
        _list(data['workoutSessions']).map(_sessionFromJson).toList();
    final sessionExercises = _list(data['sessionExercises'])
        .map(_sessionExerciseFromJson)
        .toList();
    final sessionSets =
        _list(data['sessionSets']).map(_sessionSetFromJson).toList();

    await _db.transaction(() async {
      await _db.delete(_db.sessionSets).go();
      await _db.delete(_db.sessionExercises).go();
      await _db.delete(_db.workoutSessions).go();
      await _db.delete(_db.templateExercises).go();
      await _db.delete(_db.workoutTemplates).go();
      await _db.delete(_db.exercises).go();

      if (exercises.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.exercises, exercises));
      }
      if (templates.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.workoutTemplates, templates));
      }
      if (templateExercises.isNotEmpty) {
        await _db.batch(
            (b) => b.insertAll(_db.templateExercises, templateExercises));
      }
      if (sessions.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.workoutSessions, sessions));
      }
      if (sessionExercises.isNotEmpty) {
        await _db.batch(
            (b) => b.insertAll(_db.sessionExercises, sessionExercises));
      }
      if (sessionSets.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.sessionSets, sessionSets));
      }
    });
  }

  static List<dynamic> _list(dynamic value) =>
      value == null ? const [] : value as List<dynamic>;

  static DateTime _parseDate(String s) => DateTime.parse(s);
  static String _toIso(DateTime d) => d.toUtc().toIso8601String();
  static String? _toIsoOrNull(DateTime? d) => d == null ? null : _toIso(d);
  static DateTime? _parseDateOrNull(dynamic s) =>
      s == null ? null : _parseDate(s as String);

  // ---------------------------------------------------------------------
  // exercises
  // ---------------------------------------------------------------------

  Map<String, dynamic> _exerciseToJson(Exercise e) => {
        'id': e.id,
        'name': e.name,
        'category': e.category,
        'loggingType': e.loggingType.name,
        'description': e.description,
        'notes': e.notes,
        'imagePath': e.imagePath,
        'isArchived': e.isArchived,
        'createdAt': _toIso(e.createdAt),
        'updatedAt': _toIso(e.updatedAt),
        'deletedAt': _toIsoOrNull(e.deletedAt),
      };

  Exercise _exerciseFromJson(dynamic json) {
    final j = json as Map<String, dynamic>;
    return Exercise(
      id: j['id'] as String,
      name: j['name'] as String,
      category: j['category'] as String?,
      loggingType: LoggingType.values.byName(j['loggingType'] as String),
      description: j['description'] as String?,
      notes: j['notes'] as String?,
      imagePath: j['imagePath'] as String?,
      isArchived: j['isArchived'] as bool,
      createdAt: _parseDate(j['createdAt'] as String),
      updatedAt: _parseDate(j['updatedAt'] as String),
      deletedAt: _parseDateOrNull(j['deletedAt']),
    );
  }

  // ---------------------------------------------------------------------
  // workoutTemplates
  // ---------------------------------------------------------------------

  Map<String, dynamic> _templateToJson(WorkoutTemplate t) => {
        'id': t.id,
        'name': t.name,
        'notes': t.notes,
        'defaultRestSeconds': t.defaultRestSeconds,
        'autoFocusNextSet': t.autoFocusNextSet,
        'autoFocusNextExercise': t.autoFocusNextExercise,
        'createdAt': _toIso(t.createdAt),
        'updatedAt': _toIso(t.updatedAt),
        'deletedAt': _toIsoOrNull(t.deletedAt),
      };

  WorkoutTemplate _templateFromJson(dynamic json) {
    final j = json as Map<String, dynamic>;
    return WorkoutTemplate(
      id: j['id'] as String,
      name: j['name'] as String,
      notes: j['notes'] as String?,
      defaultRestSeconds: j['defaultRestSeconds'] as int,
      autoFocusNextSet: j['autoFocusNextSet'] as bool,
      autoFocusNextExercise: j['autoFocusNextExercise'] as bool,
      createdAt: _parseDate(j['createdAt'] as String),
      updatedAt: _parseDate(j['updatedAt'] as String),
      deletedAt: _parseDateOrNull(j['deletedAt']),
    );
  }

  // ---------------------------------------------------------------------
  // templateExercises
  // ---------------------------------------------------------------------

  Map<String, dynamic> _templateExerciseToJson(TemplateExercise te) => {
        'id': te.id,
        'templateId': te.templateId,
        'exerciseId': te.exerciseId,
        'sortOrder': te.sortOrder,
        'targetSets': te.targetSets,
        'restSeconds': te.restSeconds,
        'defaultRir': te.defaultRir,
        'defaultDurationSeconds': te.defaultDurationSeconds,
        'notes': te.notes,
        'createdAt': _toIso(te.createdAt),
        'updatedAt': _toIso(te.updatedAt),
        'deletedAt': _toIsoOrNull(te.deletedAt),
      };

  TemplateExercise _templateExerciseFromJson(dynamic json) {
    final j = json as Map<String, dynamic>;
    return TemplateExercise(
      id: j['id'] as String,
      templateId: j['templateId'] as String,
      exerciseId: j['exerciseId'] as String,
      sortOrder: j['sortOrder'] as int,
      targetSets: j['targetSets'] as int,
      restSeconds: j['restSeconds'] as int,
      defaultRir: (j['defaultRir'] as num?)?.toDouble(),
      defaultDurationSeconds: j['defaultDurationSeconds'] as int?,
      notes: j['notes'] as String?,
      createdAt: _parseDate(j['createdAt'] as String),
      updatedAt: _parseDate(j['updatedAt'] as String),
      deletedAt: _parseDateOrNull(j['deletedAt']),
    );
  }

  // ---------------------------------------------------------------------
  // workoutSessions
  // ---------------------------------------------------------------------

  Map<String, dynamic> _sessionToJson(WorkoutSession s) => {
        'id': s.id,
        'templateId': s.templateId,
        'name': s.name,
        'weightUnit': s.weightUnit,
        'status': s.status.name,
        'autoFocusNextSet': s.autoFocusNextSet,
        'autoFocusNextExercise': s.autoFocusNextExercise,
        'startedAt': _toIso(s.startedAt),
        'endedAt': _toIsoOrNull(s.endedAt),
        'pausedSeconds': s.pausedSeconds,
        'pausedAt': _toIsoOrNull(s.pausedAt),
        'notes': s.notes,
        'restStatus': s.restStatus.name,
        'restEndsAt': _toIsoOrNull(s.restEndsAt),
        'restRemainingSeconds': s.restRemainingSeconds,
        'restTotalSeconds': s.restTotalSeconds,
        'restAfterSetId': s.restAfterSetId,
        'createdAt': _toIso(s.createdAt),
        'updatedAt': _toIso(s.updatedAt),
        'deletedAt': _toIsoOrNull(s.deletedAt),
      };

  WorkoutSession _sessionFromJson(dynamic json) {
    final j = json as Map<String, dynamic>;
    return WorkoutSession(
      id: j['id'] as String,
      templateId: j['templateId'] as String?,
      name: j['name'] as String,
      weightUnit: j['weightUnit'] as String,
      status: SessionStatus.values.byName(j['status'] as String),
      autoFocusNextSet: j['autoFocusNextSet'] as bool,
      autoFocusNextExercise: j['autoFocusNextExercise'] as bool,
      startedAt: _parseDate(j['startedAt'] as String),
      endedAt: _parseDateOrNull(j['endedAt']),
      pausedSeconds: j['pausedSeconds'] as int,
      pausedAt: _parseDateOrNull(j['pausedAt']),
      notes: j['notes'] as String?,
      restStatus: RestTimerStatus.values.byName(j['restStatus'] as String),
      restEndsAt: _parseDateOrNull(j['restEndsAt']),
      restRemainingSeconds: j['restRemainingSeconds'] as int?,
      restTotalSeconds: j['restTotalSeconds'] as int?,
      restAfterSetId: j['restAfterSetId'] as String?,
      createdAt: _parseDate(j['createdAt'] as String),
      updatedAt: _parseDate(j['updatedAt'] as String),
      deletedAt: _parseDateOrNull(j['deletedAt']),
    );
  }

  // ---------------------------------------------------------------------
  // sessionExercises
  // ---------------------------------------------------------------------

  Map<String, dynamic> _sessionExerciseToJson(SessionExercise se) => {
        'id': se.id,
        'sessionId': se.sessionId,
        'exerciseId': se.exerciseId,
        'name': se.name,
        'description': se.description,
        'notes': se.notes,
        'imagePath': se.imagePath,
        'loggingType': se.loggingType.name,
        'sortOrder': se.sortOrder,
        'restSeconds': se.restSeconds,
        'targetSets': se.targetSets,
        'sessionNotes': se.sessionNotes,
        'createdAt': _toIso(se.createdAt),
        'updatedAt': _toIso(se.updatedAt),
        'deletedAt': _toIsoOrNull(se.deletedAt),
      };

  SessionExercise _sessionExerciseFromJson(dynamic json) {
    final j = json as Map<String, dynamic>;
    return SessionExercise(
      id: j['id'] as String,
      sessionId: j['sessionId'] as String,
      exerciseId: j['exerciseId'] as String?,
      name: j['name'] as String,
      description: j['description'] as String?,
      notes: j['notes'] as String?,
      imagePath: j['imagePath'] as String?,
      loggingType: LoggingType.values.byName(j['loggingType'] as String),
      sortOrder: j['sortOrder'] as int,
      restSeconds: j['restSeconds'] as int,
      targetSets: j['targetSets'] as int,
      sessionNotes: j['sessionNotes'] as String?,
      createdAt: _parseDate(j['createdAt'] as String),
      updatedAt: _parseDate(j['updatedAt'] as String),
      deletedAt: _parseDateOrNull(j['deletedAt']),
    );
  }

  // ---------------------------------------------------------------------
  // sessionSets
  // ---------------------------------------------------------------------

  Map<String, dynamic> _sessionSetToJson(SessionSet s) => {
        'id': s.id,
        'sessionExerciseId': s.sessionExerciseId,
        'setIndex': s.setIndex,
        'weight': s.weight,
        'reps': s.reps,
        'rir': s.rir,
        'durationSeconds': s.durationSeconds,
        'completedAt': _toIsoOrNull(s.completedAt),
        'createdAt': _toIso(s.createdAt),
        'updatedAt': _toIso(s.updatedAt),
        'deletedAt': _toIsoOrNull(s.deletedAt),
      };

  SessionSet _sessionSetFromJson(dynamic json) {
    final j = json as Map<String, dynamic>;
    return SessionSet(
      id: j['id'] as String,
      sessionExerciseId: j['sessionExerciseId'] as String,
      setIndex: j['setIndex'] as int,
      weight: (j['weight'] as num?)?.toDouble(),
      reps: j['reps'] as int?,
      rir: (j['rir'] as num?)?.toDouble(),
      durationSeconds: j['durationSeconds'] as int?,
      completedAt: _parseDateOrNull(j['completedAt']),
      createdAt: _parseDate(j['createdAt'] as String),
      updatedAt: _parseDate(j['updatedAt'] as String),
      deletedAt: _parseDateOrNull(j['deletedAt']),
    );
  }
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);
