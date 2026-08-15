# GymFlow MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an offline-first Android Flutter workout tracker where the user creates workout templates, starts sessions from them, logs weight/reps/RIR per set, and gets precise timestamp-based rest timers with auto-advance.

**Architecture:** Feature-first Flutter app with a strict layering of `UI -> Riverpod providers -> repositories -> Drift/SQLite`. All session behaviour that is worth testing (next-target computation, rest-timer math, reordering rules, summary stats) lives in pure Dart functions with `DateTime now` injected, so it is unit-testable without widgets. Drift-generated row classes are used directly as domain models; hand-written aggregates join them. Rest timing is anchored to a persisted `restEndsAt` timestamp rather than tick decrements, so it survives process death.

**Tech Stack:** Flutter 3.41.7 (stable) / Dart 3.11.5, `flutter_riverpod`, `go_router`, `drift` + `sqlite3_flutter_libs` + `drift_dev`/`build_runner`, `path_provider`, `uuid`, `image_picker`, `image`, `flutter_local_notifications`, `wakelock_plus`, `shared_preferences`, `intl`, `share_plus`, `file_picker`.

**Spec:** `PRD.md` (repo root)

## Global Constraints

- **Offline-only MVP.** Do not implement Postgres/Supabase sync (PRD §20 is a later phase). No network calls, no account, no login.
- **Nullable `deletedAt` on every table** and a maintained `updatedAt` on every mutation, so sync can be added later without a migration (PRD §20.2).
- **Client-generated UUID v4 string IDs** for every row (PRD §12). Never use autoincrement integers.
- **Dark theme is the default** and the only theme shipped in MVP (PRD §16.2). Material 3.
- **Minimum 48dp touch targets** for every primary action (PRD §16.3). Tabular figures for timers and numeric inputs.
- **Every mutation persists immediately** to SQLite. No "save" button on the active session screen (PRD §7 FR-118).
- **Never block set completion** on missing weight/reps/RIR (PRD §18.7, §24.5).
- **Session edits never write back to the template** (PRD §24.6).
- **Rest timer is timestamp-anchored.** Store `restEndsAt`; compute remaining from `DateTime.now()`. Never rely on `Timer.periodic` decrementing an integer (PRD §10.4).
- **Weight unit default: `kg`.** Stored per-session as a snapshot string.
- **RIR values:** `null, 0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5`, stored as nullable `double`.
- **Constraints:** target sets 1–20; rest seconds 0–3600; defaults are 3 sets / 90s rest.
- **Do not add packages beyond the Tech Stack list** without flagging it first (PRD §13).
- **Dev/verification target is the iOS simulator or macOS desktop** — no Android SDK is installed on this machine. Android/APK work is explicitly deferred to a later task and is not a blocker for Tasks 1–21.
- All `flutter test` runs must pass before any commit.

---

## File Structure

```text
lib/
  main.dart                                  App entry: init DB, notifications, ProviderScope
  app/
    app.dart                                 MaterialApp.router + theme wiring
    router.dart                              GoRouter route table
  core/
    theme/app_theme.dart                     Material 3 dark ColorScheme + text theme
    theme/semantic_colors.dart               ThemeExtension: success/rest/warning/danger/muted
    utils/ids.dart                           uuid() helper
    utils/formatting.dart                    mmss(), formatWeight(), formatRir(), formatDuration()
    widgets/empty_state.dart                 Reusable illustrated empty state + CTA
    widgets/confirm_dialog.dart              Destructive-action confirmation
    widgets/numeric_field.dart               Compact numeric input w/ correct keyboard
    services/haptics_service.dart            Wraps HapticFeedback, honours settings toggle
    services/notification_service.dart       flutter_local_notifications wrapper
    services/sound_service.dart              Rest-complete chime via SystemSound
    services/image_storage_service.dart      Copy+downscale picked image into app docs
    services/backup_service.dart             JSON export/import
    services/wakelock_service.dart           Keep-screen-on during session
  db/
    tables.dart                              All 6 Drift tables + enum converters
    app_database.dart                        AppDatabase, connection, migrations
    daos/exercise_dao.dart
    daos/template_dao.dart
    daos/session_dao.dart
    seed_exercises.dart                      Starter library data
  features/
    exercises/
      data/exercise_repository.dart
      providers/exercise_providers.dart
      ui/exercise_list_screen.dart
      ui/exercise_editor_screen.dart
      ui/exercise_info_sheet.dart
      ui/exercise_picker_sheet.dart
    templates/
      data/template_repository.dart
      data/template_models.dart              TemplateWithExercises aggregates
      providers/template_providers.dart
      ui/home_screen.dart                    Template list = Home
      ui/template_editor_screen.dart
      ui/template_exercise_settings_sheet.dart
    sessions/
      data/session_repository.dart
      data/session_models.dart               ActiveSession, SessionExerciseWithSets, SessionTarget
      domain/session_engine.dart             PURE: next target, completion, reorder, stats
      domain/rest_timer.dart                 PURE: RestTimerState + transitions
      providers/active_session_controller.dart
      providers/rest_timer_controller.dart
      ui/active_session_screen.dart
      ui/widgets/session_progress_header.dart
      ui/widgets/session_exercise_card.dart
      ui/widgets/strength_set_row.dart
      ui/widgets/duration_set_row.dart
      ui/widgets/rest_bar.dart
      ui/widgets/rest_sheet.dart
      ui/session_settings_sheet.dart
      ui/session_reorder_screen.dart
      ui/session_summary_screen.dart
    history/
      providers/history_providers.dart
      ui/history_screen.dart
      ui/session_detail_screen.dart
    settings/
      data/settings_repository.dart          shared_preferences wrapper
      providers/settings_providers.dart
      ui/settings_screen.dart
test/
  db/test_database.dart                      In-memory AppDatabase factory
  db/exercise_dao_test.dart
  db/template_dao_test.dart
  db/session_dao_test.dart
  sessions/session_engine_test.dart          Largest test file — pure logic
  sessions/rest_timer_test.dart
  sessions/session_snapshot_test.dart
  services/backup_service_test.dart
  widget/app_boot_test.dart
```

---

## Task 1: Project scaffold, theme, router, git

**Files:**
- Create: whole Flutter project at repo root (`lib/`, `test/`, `pubspec.yaml`, platform folders)
- Create: `lib/main.dart`, `lib/app/app.dart`, `lib/app/router.dart`
- Create: `lib/core/theme/app_theme.dart`, `lib/core/theme/semantic_colors.dart`
- Create: `lib/core/utils/ids.dart`, `lib/core/utils/formatting.dart`
- Test: `test/widget/app_boot_test.dart`
- Modify: `.gitignore`, `analysis_options.yaml`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `GymFlowApp` widget; `appRouter` (`GoRouter`); `AppTheme.dark()` returning `ThemeData`; `SemanticColors` `ThemeExtension` with fields `success`, `rest`, `warning`, `danger`, `muted` (all `Color`), accessible via `Theme.of(context).extension<SemanticColors>()!`; `newId()` returning a v4 UUID `String`; `mmss(Duration)` returning `"M:SS"` for <1h.

- [ ] **Step 1: Create the project in place**

`PRD.md` already lives in the repo root, so create the project into the current directory rather than a subfolder.

```bash
cd /Users/ishanshrestha/projects/flutter/gymflow
flutter create --org dev.ishan --project-name gymflow --platforms=android,ios,macos .
git init
```

- [ ] **Step 2: Add dependencies**

```bash
flutter pub add flutter_riverpod go_router drift sqlite3_flutter_libs path_provider uuid intl
flutter pub add image_picker image flutter_local_notifications wakelock_plus shared_preferences share_plus file_picker
flutter pub add --dev drift_dev build_runner
```

Do not pin versions by hand; let pub resolve the latest compatible set. Record the resolved versions in the commit message.

- [ ] **Step 3: Write the failing boot test**

```dart
// test/widget/app_boot_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/app/app.dart';
import 'package:gymflow/core/theme/semantic_colors.dart';

void main() {
  testWidgets('app boots into a dark theme and shows the Workouts title',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GymFlowApp()));
    await tester.pumpAndSettle();

    expect(find.text('Workouts'), findsOneWidget);

    final context = tester.element(find.text('Workouts'));
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.dark);
    expect(theme.extension<SemanticColors>(), isNotNull);
  });
}
```

- [ ] **Step 4: Run it and confirm it fails**

Run: `flutter test test/widget/app_boot_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:gymflow/app/app.dart'`.

- [ ] **Step 5: Implement semantic colors**

```dart
// lib/core/theme/semantic_colors.dart
import 'package:flutter/material.dart';

@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.success,
    required this.rest,
    required this.warning,
    required this.danger,
    required this.muted,
  });

  final Color success;
  final Color rest;
  final Color warning;
  final Color danger;
  final Color muted;

  static const dark = SemanticColors(
    success: Color(0xFF4ADE80),
    rest: Color(0xFF38BDF8),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    muted: Color(0xFF94A3B8),
  );

  @override
  SemanticColors copyWith({
    Color? success,
    Color? rest,
    Color? warning,
    Color? danger,
    Color? muted,
  }) =>
      SemanticColors(
        success: success ?? this.success,
        rest: rest ?? this.rest,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        muted: muted ?? this.muted,
      );

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      rest: Color.lerp(rest, other.rest, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}
```

- [ ] **Step 6: Implement the theme**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'semantic_colors.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      brightness: Brightness.dark,
    ).copyWith(surface: const Color(0xFF0F1115));

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F1115),
      extensions: const [SemanticColors.dark],
      // Gym use: every tappable primary action clears 48dp.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      textTheme: base.textTheme.apply(fontFamilyFallback: const ['SF Pro']),
    );
  }

  /// Tabular figures — use for every timer and numeric readout so digits
  /// do not jitter as they change (PRD §16.4).
  static const tabularFigures = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
```

- [ ] **Step 7: Implement utils**

```dart
// lib/core/utils/ids.dart
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();
```

```dart
// lib/core/utils/formatting.dart
/// "1:05", "0:09", "12:30" — always at least M:SS.
String mmss(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Trims trailing zeros: 80.0 -> "80", 77.5 -> "77.5".
String formatWeight(double? w) {
  if (w == null) return '';
  return w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString();
}

/// null -> "—", 2.0 -> "2", 1.5 -> "1.5".
String formatRir(double? rir) => rir == null ? '—' : formatWeight(rir);

/// 45 -> "45s", 90 -> "1:30".
String formatDurationSeconds(int? seconds) {
  if (seconds == null) return '';
  if (seconds < 60) return '${seconds}s';
  return mmss(Duration(seconds: seconds));
}
```

- [ ] **Step 8: Implement router and app shell**

Home is the template list; it is built for real in Task 7. For now it is a scaffold titled `Workouts`.

```dart
// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Workouts')),
        body: const SizedBox.shrink(),
      ),
    ),
  ],
);
```

```dart
// lib/app/app.dart
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class GymFlowApp extends StatelessWidget {
  const GymFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GymFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: GymFlowApp()));
}
```

- [ ] **Step 9: Run the test and confirm it passes**

Run: `flutter test test/widget/app_boot_test.dart`
Expected: PASS.

Also run `flutter analyze` and fix every warning before committing.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: scaffold GymFlow Flutter app with dark M3 theme and router"
```

---

## Task 2: Drift schema and database

**Files:**
- Create: `lib/db/tables.dart`, `lib/db/app_database.dart`
- Create: `test/db/test_database.dart`, `test/db/exercise_dao_test.dart`
- Modify: `lib/main.dart` (open the DB before `runApp`), `.gitignore` (do **not** ignore `*.g.dart` — generated Drift code is committed)

**Interfaces:**
- Consumes: `newId()` from Task 1.
- Produces:
  - Enums `LoggingType { strengthWeightRepsRir, durationOnly }`, `SessionStatus { active, paused, completed, cancelled }`, `RestTimerStatus { idle, running, paused, finished }` — all defined in `lib/db/tables.dart` and exported from `app_database.dart`.
  - Drift row classes `Exercise`, `WorkoutTemplate`, `TemplateExercise`, `WorkoutSession`, `SessionExercise`, `SessionSet` and their companions `ExercisesCompanion` etc.
  - `AppDatabase` with `AppDatabase(QueryExecutor e)` and `AppDatabase.open()` (file-backed via `path_provider`).
  - `databaseProvider` — `Provider<AppDatabase>` that throws unless overridden in `main()`/tests.
  - `testDatabase()` in `test/db/test_database.dart` returning an in-memory `AppDatabase`.

- [ ] **Step 1: Write the tables**

Every table carries `createdAt`, `updatedAt`, and a nullable `deletedAt` so sync can be bolted on later without a migration.

```dart
// lib/db/tables.dart
import 'package:drift/drift.dart';

enum LoggingType { strengthWeightRepsRir, durationOnly }

enum SessionStatus { active, paused, completed, cancelled }

enum RestTimerStatus { idle, running, paused, finished }

mixin SyncColumns on Table {
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Exercises extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get loggingType => textEnum<LoggingType>()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutTemplates extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get defaultRestSeconds => integer().withDefault(const Constant(90))();
  BoolColumn get autoFocusNextSet => boolean().withDefault(const Constant(true))();
  BoolColumn get autoFocusNextExercise =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class TemplateExercises extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get templateId =>
      text().references(WorkoutTemplates, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get sortOrder => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
  RealColumn get defaultRir => real().nullable()();
  IntColumn get defaultDurationSeconds => integer().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutSessions extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get templateId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get weightUnit => text().withDefault(const Constant('kg'))();
  TextColumn get status => textEnum<SessionStatus>()();
  BoolColumn get autoFocusNextSet => boolean().withDefault(const Constant(true))();
  BoolColumn get autoFocusNextExercise =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get pausedSeconds => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();

  // Rest-timer persistence. Anchored on restEndsAt so the countdown survives
  // process death (PRD §10.4, §18.3). restRemainingSeconds is authoritative
  // only while paused.
  TextColumn get restStatus =>
      textEnum<RestTimerStatus>().withDefault(const Constant('idle'))();
  DateTimeColumn get restEndsAt => dateTime().nullable()();
  IntColumn get restRemainingSeconds => integer().nullable()();
  IntColumn get restTotalSeconds => integer().nullable()();
  TextColumn get restAfterSetId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SessionExercises extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get loggingType => textEnum<LoggingType>()();
  IntColumn get sortOrder => integer()();
  IntColumn get restSeconds => integer()();
  IntColumn get targetSets => integer()();
  TextColumn get sessionNotes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SessionSets extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get sessionExerciseId =>
      text().references(SessionExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get setIndex => integer()();
  RealColumn get weight => real().nullable()();
  IntColumn get reps => integer().nullable()();
  RealColumn get rir => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: Write the database class**

```dart
// lib/db/app_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    WorkoutTemplates,
    TemplateExercises,
    WorkoutSessions,
    SessionExercises,
    SessionSets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          // Required for the onDelete: cascade references above to fire.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'gymflow.sqlite'));
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    return NativeDatabase.createInBackground(file);
  });
}

/// Overridden in main() and in tests. Reading it without an override is a bug.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);
```

- [ ] **Step 3: Generate code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `lib/db/app_database.g.dart` is created. Commit it — generated Drift code is checked in.

- [ ] **Step 4: Write the in-memory test database helper**

```dart
// test/db/test_database.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:gymflow/db/app_database.dart';

AppDatabase testDatabase() => AppDatabase(NativeDatabase.memory());
```

- [ ] **Step 5: Write the failing schema test**

```dart
// test/db/exercise_dao_test.dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  test('round-trips an exercise including its logging type enum', () async {
    final now = DateTime.utc(2026, 8, 15, 10);
    await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'ex-1',
          name: 'Bench Press',
          loggingType: LoggingType.strengthWeightRepsRir,
          createdAt: now,
          updatedAt: now,
          category: const Value('Chest'),
          description: const Value('Barbell press on a flat bench.'),
        ));

    final row = await db.select(db.exercises).getSingle();

    expect(row.name, 'Bench Press');
    expect(row.loggingType, LoggingType.strengthWeightRepsRir);
    expect(row.category, 'Chest');
    expect(row.isArchived, isFalse);
    expect(row.deletedAt, isNull);
  });

  test('deleting a session cascades to its exercises and sets', () async {
    final now = DateTime.utc(2026, 8, 15, 10);
    await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          id: 's-1',
          name: 'Push',
          status: SessionStatus.active,
          startedAt: now,
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.sessionExercises).insert(SessionExercisesCompanion.insert(
          id: 'se-1',
          sessionId: 's-1',
          name: 'Bench Press',
          loggingType: LoggingType.strengthWeightRepsRir,
          sortOrder: 0,
          restSeconds: 90,
          targetSets: 3,
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.sessionSets).insert(SessionSetsCompanion.insert(
          id: 'set-1',
          sessionExerciseId: 'se-1',
          setIndex: 0,
          createdAt: now,
          updatedAt: now,
        ));

    await (db.delete(db.workoutSessions)..where((t) => t.id.equals('s-1'))).go();

    expect(await db.select(db.sessionExercises).get(), isEmpty);
    expect(await db.select(db.sessionSets).get(), isEmpty);
  });
}
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/db/exercise_dao_test.dart`
Expected: PASS. If the cascade test fails, the `beforeOpen` `PRAGMA foreign_keys = ON` is not being applied — fix that rather than dropping the test.

- [ ] **Step 7: Wire the database into `main.dart`**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'db/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.open();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const GymFlowApp(),
    ),
  );
}
```

- [ ] **Step 8: Run the full suite and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add Drift schema for exercises, templates, sessions and sets"
```

---

## Task 3: Exercise repository and seeded starter library

**Files:**
- Create: `lib/db/daos/exercise_dao.dart`, `lib/db/seed_exercises.dart`
- Create: `lib/features/exercises/data/exercise_repository.dart`
- Create: `lib/features/exercises/providers/exercise_providers.dart`
- Test: `test/db/exercise_dao_test.dart` (extend)

**Interfaces:**
- Consumes: `AppDatabase`, `databaseProvider`, `newId()`.
- Produces:
  - `ExerciseDao` (Drift `@DriftAccessor`) with `Stream<List<Exercise>> watchAll({bool includeArchived})`, `Future<Exercise?> findById(String id)`, `Future<void> upsert(Exercise e)`, `Future<void> setArchived(String id, bool archived)`, `Future<int> count()`.
  - `ExerciseRepository` with `Stream<List<Exercise>> watchAll({bool includeArchived = false})`, `Stream<List<Exercise>> watchSearch(String query, {bool includeArchived = false})`, `Future<Exercise> create({required String name, required LoggingType loggingType, String? category, String? description, String? notes, String? imagePath})`, `Future<void> update(Exercise exercise)`, `Future<void> archive(String id)`, `Future<void> unarchive(String id)`, `Future<void> seedIfEmpty()`.
  - `exerciseRepositoryProvider` — `Provider<ExerciseRepository>`.
  - `exerciseListProvider` — `StreamProvider<List<Exercise>>` (non-archived, name-sorted).
  - `exerciseSearchQueryProvider` — `StateProvider<String>`.
  - `filteredExercisesProvider` — `StreamProvider<List<Exercise>>` honouring the search query.
  - `seedExercises` — `List<({String name, String category, LoggingType loggingType, String description})>` of ~30 entries.

- [ ] **Step 1: Write the seed data**

Cover the user's stated training: push/pull/legs, ab circuits, and stretching. Stretches and planks are `durationOnly`; everything else is `strengthWeightRepsRir`.

```dart
// lib/db/seed_exercises.dart
import 'tables.dart';

typedef SeedExercise = ({
  String name,
  String category,
  LoggingType loggingType,
  String description,
});

const _s = LoggingType.strengthWeightRepsRir;
const _d = LoggingType.durationOnly;

const seedExercises = <SeedExercise>[
  (name: 'Barbell Bench Press', category: 'Chest', loggingType: _s, description: 'Flat barbell press. Retract the scapulae and keep the bar path over the mid-chest.'),
  (name: 'Incline Dumbbell Press', category: 'Chest', loggingType: _s, description: 'Press on a 30-45 degree incline to bias the upper chest.'),
  (name: 'Cable Fly', category: 'Chest', loggingType: _s, description: 'Sweeping arc with a slight elbow bend, squeezing at the midline.'),
  (name: 'Overhead Press', category: 'Shoulders', loggingType: _s, description: 'Standing barbell press from the front rack to lockout overhead.'),
  (name: 'Lateral Raise', category: 'Shoulders', loggingType: _s, description: 'Raise dumbbells to shoulder height, leading with the elbows.'),
  (name: 'Rear Delt Fly', category: 'Shoulders', loggingType: _s, description: 'Bent-over or cable reverse fly for the posterior deltoid.'),
  (name: 'Triceps Pushdown', category: 'Arms', loggingType: _s, description: 'Cable pushdown keeping the elbows pinned to the ribs.'),
  (name: 'Overhead Triceps Extension', category: 'Arms', loggingType: _s, description: 'Stretch the long head of the triceps overhead before extending.'),
  (name: 'Lat Pulldown', category: 'Back', loggingType: _s, description: 'Pull the bar to the upper chest, driving the elbows down and back.'),
  (name: 'Seated Cable Row', category: 'Back', loggingType: _s, description: 'Row to the navel with a neutral spine and controlled eccentric.'),
  (name: 'Barbell Row', category: 'Back', loggingType: _s, description: 'Hinged bent-over row to the lower ribs.'),
  (name: 'Pull-Up', category: 'Back', loggingType: _s, description: 'Bodyweight or weighted pull-up to chin over the bar.'),
  (name: 'Face Pull', category: 'Back', loggingType: _s, description: 'High cable pull to the forehead with external rotation.'),
  (name: 'Barbell Curl', category: 'Arms', loggingType: _s, description: 'Supinated curl with the elbows fixed at the sides.'),
  (name: 'Hammer Curl', category: 'Arms', loggingType: _s, description: 'Neutral-grip curl biasing the brachialis and brachioradialis.'),
  (name: 'Back Squat', category: 'Legs', loggingType: _s, description: 'Barbell squat to at least parallel with a braced torso.'),
  (name: 'Front Squat', category: 'Legs', loggingType: _s, description: 'Front-racked squat emphasising the quads and upper back.'),
  (name: 'Romanian Deadlift', category: 'Legs', loggingType: _s, description: 'Hip hinge with soft knees, lowering until the hamstrings stretch.'),
  (name: 'Leg Press', category: 'Legs', loggingType: _s, description: 'Machine press with feet shoulder-width, avoiding lumbar rounding.'),
  (name: 'Leg Curl', category: 'Legs', loggingType: _s, description: 'Seated or lying hamstring curl through a full range.'),
  (name: 'Leg Extension', category: 'Legs', loggingType: _s, description: 'Knee extension with a pause at the top.'),
  (name: 'Walking Lunge', category: 'Legs', loggingType: _s, description: 'Alternating forward lunges with an upright torso.'),
  (name: 'Standing Calf Raise', category: 'Legs', loggingType: _s, description: 'Full stretch at the bottom, full contraction at the top.'),
  (name: 'Plank', category: 'Core', loggingType: _d, description: 'Forearm plank with a neutral spine and braced glutes.'),
  (name: 'Side Plank', category: 'Core', loggingType: _d, description: 'Lateral plank stacking shoulder, hip and ankle.'),
  (name: 'Hanging Leg Raise', category: 'Core', loggingType: _s, description: 'Raise the legs to hip height or above without swinging.'),
  (name: 'Cable Crunch', category: 'Core', loggingType: _s, description: 'Kneeling crunch flexing the spine against cable resistance.'),
  (name: 'Dead Bug', category: 'Core', loggingType: _s, description: 'Alternating limb lowering with the lower back pinned down.'),
  (name: 'Hamstring Stretch', category: 'Stretching', loggingType: _d, description: 'Seated or standing hamstring stretch, held without bouncing.'),
  (name: 'Hip Flexor Stretch', category: 'Stretching', loggingType: _d, description: 'Half-kneeling lunge stretch with a posterior pelvic tilt.'),
  (name: 'Pigeon Stretch', category: 'Stretching', loggingType: _d, description: 'Glute and external rotator stretch in a pigeon position.'),
  (name: 'Chest Doorway Stretch', category: 'Stretching', loggingType: _d, description: 'Pec stretch with the forearm braced against a doorframe.'),
  (name: 'Thoracic Extension', category: 'Stretching', loggingType: _d, description: 'Foam-roller extension over the mid-back.'),
  (name: 'Couch Stretch', category: 'Stretching', loggingType: _d, description: 'Rear-foot-elevated quad and hip flexor stretch.'),
];
```

- [ ] **Step 2: Write the failing repository test**

```dart
// append to test/db/exercise_dao_test.dart
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/db/seed_exercises.dart';

// ... inside main(), add:

  group('ExerciseRepository', () {
    late ExerciseRepository repo;

    setUp(() => repo = ExerciseRepository(db));

    test('seedIfEmpty populates the starter library exactly once', () async {
      await repo.seedIfEmpty();
      final first = await repo.watchAll().first;
      expect(first, hasLength(seedExercises.length));

      await repo.seedIfEmpty();
      final second = await repo.watchAll().first;
      expect(second, hasLength(seedExercises.length));
    });

    test('watchAll hides archived exercises unless asked', () async {
      final ex = await repo.create(
        name: 'Bench Press',
        loggingType: LoggingType.strengthWeightRepsRir,
      );
      await repo.archive(ex.id);

      expect(await repo.watchAll().first, isEmpty);
      expect(await repo.watchAll(includeArchived: true).first, hasLength(1));
    });

    test('watchSearch matches name case-insensitively', () async {
      await repo.create(name: 'Lat Pulldown', loggingType: LoggingType.strengthWeightRepsRir);
      await repo.create(name: 'Leg Press', loggingType: LoggingType.strengthWeightRepsRir);

      final hits = await repo.watchSearch('pull').first;
      expect(hits.map((e) => e.name), ['Lat Pulldown']);
    });

    test('update bumps updatedAt', () async {
      final ex = await repo.create(name: 'Plank', loggingType: LoggingType.durationOnly);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.update(ex.copyWith(name: 'Side Plank'));

      final saved = await repo.watchAll().first;
      expect(saved.single.name, 'Side Plank');
      expect(saved.single.updatedAt.isAfter(ex.updatedAt), isTrue);
    });
  });
```

- [ ] **Step 3: Run and confirm failure**

Run: `flutter test test/db/exercise_dao_test.dart`
Expected: FAIL — `ExerciseRepository` is not defined.

- [ ] **Step 4: Implement the repository**

```dart
// lib/features/exercises/data/exercise_repository.dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ids.dart';
import '../../../db/app_database.dart';
import '../../../db/seed_exercises.dart';

class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  Stream<List<Exercise>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.exercises)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    return q.watch();
  }

  Stream<List<Exercise>> watchSearch(String query,
      {bool includeArchived = false}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return watchAll(includeArchived: includeArchived);
    return watchAll(includeArchived: includeArchived).map(
      (rows) => rows
          .where((e) => e.name.toLowerCase().contains(trimmed.toLowerCase()))
          .toList(),
    );
  }

  Future<Exercise?> findById(String id) =>
      (_db.select(_db.exercises)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<Exercise> create({
    required String name,
    required LoggingType loggingType,
    String? category,
    String? description,
    String? notes,
    String? imagePath,
  }) async {
    final now = DateTime.now();
    final row = Exercise(
      id: newId(),
      name: name.trim(),
      category: category,
      loggingType: loggingType,
      description: description,
      notes: notes,
      imagePath: imagePath,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _db.into(_db.exercises).insert(row);
    return row;
  }

  Future<void> update(Exercise exercise) async {
    await _db.update(_db.exercises).replace(
          exercise.copyWith(updatedAt: DateTime.now()),
        );
  }

  Future<void> archive(String id) => _setArchived(id, true);

  Future<void> unarchive(String id) => _setArchived(id, false);

  Future<void> _setArchived(String id, bool archived) async {
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Populates the starter library on first launch. No-op if any exercise
  /// already exists, so it is safe to call on every app start.
  Future<void> seedIfEmpty() async {
    final existing = await _db.select(_db.exercises).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    await _db.batch((b) {
      b.insertAll(
        _db.exercises,
        [
          for (final s in seedExercises)
            ExercisesCompanion.insert(
              id: newId(),
              name: s.name,
              loggingType: s.loggingType,
              createdAt: now,
              updatedAt: now,
              category: Value(s.category),
              description: Value(s.description),
            ),
        ],
      );
    });
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);
```

- [ ] **Step 5: Implement the providers**

```dart
// lib/features/exercises/providers/exercise_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../data/exercise_repository.dart';

final exerciseListProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchAll(),
);

final exerciseSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredExercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final query = ref.watch(exerciseSearchQueryProvider);
  return ref.watch(exerciseRepositoryProvider).watchSearch(query);
});

final exerciseByIdProvider =
    FutureProvider.family<Exercise?, String>((ref, id) async {
  return ref.watch(exerciseRepositoryProvider).findById(id);
});
```

- [ ] **Step 6: Call the seed on startup**

In `lib/main.dart`, after opening the DB and before `runApp`:

```dart
  await ExerciseRepository(db).seedIfEmpty();
```

- [ ] **Step 7: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add exercise repository with seeded starter library"
```

---

## Task 4: Exercise library UI — list, editor, info sheet

**Files:**
- Create: `lib/features/exercises/ui/exercise_list_screen.dart`
- Create: `lib/features/exercises/ui/exercise_editor_screen.dart`
- Create: `lib/features/exercises/ui/exercise_info_sheet.dart`
- Create: `lib/core/widgets/empty_state.dart`, `lib/core/widgets/confirm_dialog.dart`
- Modify: `lib/app/router.dart`
- Test: `test/widget/exercise_library_test.dart`

**Interfaces:**
- Consumes: `filteredExercisesProvider`, `exerciseSearchQueryProvider`, `exerciseRepositoryProvider`, `SemanticColors`.
- Produces:
  - `ExerciseListScreen`, `ExerciseEditorScreen({String? exerciseId})`.
  - `Future<void> showExerciseInfoSheet(BuildContext context, {required String name, String? description, String? notes, String? imagePath, String? category, required LoggingType loggingType, bool isArchived = false})` — the single info-sheet entry point reused by the template editor and the active session (PRD FR-114).
  - `EmptyState({required IconData icon, required String title, required String message, String? actionLabel, VoidCallback? onAction})`.
  - `Future<bool> confirmDestructive(BuildContext context, {required String title, required String message, required String confirmLabel})`.
  - Routes: `/exercises`, `/exercises/new`, `/exercises/:id`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widget/exercise_library_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/exercises/ui/exercise_list_screen.dart';
import '../db/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ExerciseListScreen()),
      );

  testWidgets('shows an empty state with a call to action', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('Create an exercise'), findsOneWidget);
  });

  testWidgets('lists exercises and filters them by search', (tester) async {
    final repo = ExerciseRepository(db);
    await repo.create(name: 'Lat Pulldown', loggingType: LoggingType.strengthWeightRepsRir);
    await repo.create(name: 'Leg Press', loggingType: LoggingType.strengthWeightRepsRir);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('Lat Pulldown'), findsOneWidget);
    expect(find.text('Leg Press'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'pull');
    await tester.pumpAndSettle();
    expect(find.text('Lat Pulldown'), findsOneWidget);
    expect(find.text('Leg Press'), findsNothing);
  });

  testWidgets('tapping the info icon opens the info sheet', (tester) async {
    await ExerciseRepository(db).create(
      name: 'Plank',
      loggingType: LoggingType.durationOnly,
      description: 'Forearm plank with a neutral spine.',
    );

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Forearm plank with a neutral spine.'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/widget/exercise_library_test.dart`
Expected: FAIL — `ExerciseListScreen` is not defined.

- [ ] **Step 3: Implement the shared core widgets**

```dart
// lib/core/widgets/empty_state.dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/core/widgets/confirm_dialog.dart
import 'package:flutter/material.dart';
import '../theme/semantic_colors.dart';

Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final danger = Theme.of(context).extension<SemanticColors>()!.danger;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

- [ ] **Step 4: Implement the info sheet**

This is the one info sheet reused everywhere (PRD FR-114). It takes plain values rather than an `Exercise` row so the active session can pass its own snapshot fields.

```dart
// lib/features/exercises/ui/exercise_info_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../db/app_database.dart';

Future<void> showExerciseInfoSheet(
  BuildContext context, {
  required String name,
  required LoggingType loggingType,
  String? description,
  String? notes,
  String? imagePath,
  String? category,
  bool isArchived = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final hasImage = imagePath != null && File(imagePath).existsSync();
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (category != null) Chip(label: Text(category)),
                  Chip(
                    label: Text(
                      loggingType == LoggingType.durationOnly
                          ? 'Duration'
                          : 'Strength',
                    ),
                  ),
                  if (isArchived)
                    Chip(
                      label: const Text('Archived'),
                      backgroundColor: theme.colorScheme.errorContainer,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasImage
                    ? Image.file(File(imagePath), height: 200,
                        width: double.infinity, fit: BoxFit.cover)
                    : Container(
                        height: 140,
                        width: double.infinity,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.fitness_center,
                            size: 48, color: theme.colorScheme.outline),
                      ),
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Description', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodyLarge),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Notes', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(notes, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      );
    },
  );
}
```

- [ ] **Step 5: Implement the list screen**

Requirements: search field pinned at the top, one row per exercise with an `info_outline` trailing icon, tap-to-edit, swipe or overflow to archive with an undo snackbar, `EmptyState` when the list is empty, FAB to create.

```dart
// lib/features/exercises/ui/exercise_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../db/app_database.dart';
import '../data/exercise_repository.dart';
import '../providers/exercise_providers.dart';
import 'exercise_info_sheet.dart';

class ExerciseListScreen extends ConsumerWidget {
  const ExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(filteredExercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/exercises/new'),
        icon: const Icon(Icons.add),
        label: const Text('New exercise'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) =>
                  ref.read(exerciseSearchQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: exercises.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return EmptyState(
                    icon: Icons.fitness_center,
                    title: 'No exercises yet',
                    message:
                        'Add the movements you train so you can drop them into workouts.',
                    actionLabel: 'Create an exercise',
                    onAction: () => context.push('/exercises/new'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _ExerciseTile(exercise: rows[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends ConsumerWidget {
  const _ExerciseTile({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(exercise.name),
      subtitle: Text([
        if (exercise.category != null) exercise.category!,
        exercise.loggingType == LoggingType.durationOnly
            ? 'Duration'
            : 'Strength',
      ].join(' · ')),
      onTap: () => context.push('/exercises/${exercise.id}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Exercise info',
            onPressed: () => showExerciseInfoSheet(
              context,
              name: exercise.name,
              loggingType: exercise.loggingType,
              description: exercise.description,
              notes: exercise.notes,
              imagePath: exercise.imagePath,
              category: exercise.category,
              isArchived: exercise.isArchived,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archive',
            onPressed: () async {
              final repo = ref.read(exerciseRepositoryProvider);
              await repo.archive(exercise.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${exercise.name} archived'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => repo.unarchive(exercise.id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Implement the editor screen**

Fields per PRD §9.3: name (required), category dropdown (Chest, Back, Legs, Shoulders, Arms, Core, Stretching, Cardio, Other), logging-type segmented control, description, notes, image (wired in Task 5 — leave a placeholder `_ImageField` that renders the picker button but does nothing yet), save/cancel, and archive for existing exercises. Validate that the trimmed name is non-empty and show an inline error otherwise.

- [ ] **Step 7: Add routes**

```dart
    GoRoute(path: '/exercises', builder: (_, __) => const ExerciseListScreen()),
    GoRoute(path: '/exercises/new', builder: (_, __) => const ExerciseEditorScreen()),
    GoRoute(
      path: '/exercises/:id',
      builder: (_, s) => ExerciseEditorScreen(exerciseId: s.pathParameters['id']),
    ),
```

- [ ] **Step 8: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add exercise library list, editor and shared info sheet"
```

---

## Task 5: Exercise images

**Files:**
- Create: `lib/core/services/image_storage_service.dart`
- Modify: `lib/features/exercises/ui/exercise_editor_screen.dart`
- Modify: `ios/Runner/Info.plist`, `macos/Runner/*.entitlements` (photo library usage strings)
- Test: `test/services/image_storage_service_test.dart`

**Interfaces:**
- Consumes: `path_provider`, `image_picker`, `image`.
- Produces: `ImageStorageService` with `Future<String?> pickAndStore({ImageSource source = ImageSource.gallery})` returning the stored absolute path, `Future<String> storeBytes(Uint8List bytes, {required String extension})`, and `Future<void> deleteIfManaged(String path)`. `imageStorageServiceProvider` — `Provider<ImageStorageService>`.

- [ ] **Step 1: Write the failing test for the pure part**

Only the resize + write step is unit-testable (the picker needs a platform channel), so factor it into `storeBytes` and test that.

```dart
// test/services/image_storage_service_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/services/image_storage_service.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('downscales a wide image to at most 1080px and writes it to disk',
      () async {
    final dir = await Directory.systemTemp.createTemp('gymflow_img');
    final service = ImageStorageService(imagesDirOverride: dir);

    final source = img.Image(width: 3000, height: 1500);
    img.fill(source, color: img.ColorRgb8(120, 120, 120));
    final bytes = img.encodeJpg(source);

    final path = await service.storeBytes(bytes, extension: 'jpg');

    final written = img.decodeImage(File(path).readAsBytesSync())!;
    expect(written.width, 1080);
    expect(written.height, 540);
    expect(File(path).existsSync(), isTrue);
  });

  test('leaves images narrower than the cap untouched', () async {
    final dir = await Directory.systemTemp.createTemp('gymflow_img');
    final service = ImageStorageService(imagesDirOverride: dir);

    final source = img.Image(width: 400, height: 400);
    final path = await service.storeBytes(img.encodeJpg(source), extension: 'jpg');

    final written = img.decodeImage(File(path).readAsBytesSync())!;
    expect(written.width, 400);
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `flutter test test/services/image_storage_service_test.dart`
Expected: FAIL — `ImageStorageService` is not defined.

- [ ] **Step 3: Implement the service**

```dart
// lib/core/services/image_storage_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/ids.dart';

class ImageStorageService {
  ImageStorageService({Directory? imagesDirOverride, ImagePicker? picker})
      : _override = imagesDirOverride,
        _picker = picker ?? ImagePicker();

  static const maxWidth = 1080;

  final Directory? _override;
  final ImagePicker _picker;

  Future<Directory> _imagesDir() async {
    if (_override != null) return _override;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'exercise_images'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Returns the stored absolute path, or null if the user cancelled.
  Future<String?> pickAndStore({ImageSource source = ImageSource.gallery}) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return storeBytes(bytes, extension: p.extension(picked.path).replaceFirst('.', ''));
  }

  /// Downscales to [maxWidth] (preserving aspect ratio) and writes a JPEG into
  /// the app documents directory. Returns the absolute path.
  Future<String> storeBytes(Uint8List bytes, {required String extension}) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('Unsupported image format');

    final resized = decoded.width > maxWidth
        ? img.copyResize(decoded, width: maxWidth)
        : decoded;

    final dir = await _imagesDir();
    final file = File(p.join(dir.path, '${newId()}.jpg'));
    await file.writeAsBytes(img.encodeJpg(resized, quality: 85));
    return file.path;
  }

  /// Only deletes files we own, so a user-supplied path outside our directory
  /// is never touched.
  Future<void> deleteIfManaged(String path) async {
    final dir = await _imagesDir();
    if (!p.isWithin(dir.path, path)) return;
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }
}

final imageStorageServiceProvider =
    Provider<ImageStorageService>((ref) => ImageStorageService());
```

`storeBytes` takes `Uint8List`; `img.encodeJpg` returns `Uint8List` in current `image` versions, so pass it directly in the test.

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/services/image_storage_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the picker into the exercise editor**

Replace the `_ImageField` placeholder with: a 16:9 preview (`Image.file`) when `imagePath` is set, otherwise a dashed placeholder with a `fitness_center` icon; buttons "Choose photo" (gallery) and "Take photo" (camera); and a "Remove" button that clears the path and calls `deleteIfManaged` on save. Adding a new image when one already exists replaces the file and deletes the old one.

- [ ] **Step 6: Add platform permission strings**

`ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Pick a reference photo for an exercise.</string>
<key>NSCameraUsageDescription</key>
<string>Take a reference photo for an exercise.</string>
```

Android's `image_picker` needs no manifest entry for gallery access on modern API levels; the camera path is handled by the plugin.

- [ ] **Step 7: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: store downscaled exercise images in app documents"
```

---

## Task 6: Template repository

**Files:**
- Create: `lib/features/templates/data/template_models.dart`
- Create: `lib/features/templates/data/template_repository.dart`
- Create: `lib/features/templates/providers/template_providers.dart`
- Test: `test/db/template_dao_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `newId()`, `Exercise`, `WorkoutTemplate`, `TemplateExercise`.
- Produces:
  - `TemplateExerciseWithExercise` — `final TemplateExercise config; final Exercise exercise;` plus `String get name => exercise.name;` and `bool get isArchived => exercise.isArchived;`.
  - `TemplateWithExercises` — `final WorkoutTemplate template; final List<TemplateExerciseWithExercise> exercises;` plus `int get totalSets` (sum of `config.targetSets`) and `bool get canStart => exercises.isNotEmpty`.
  - `TemplateSummary` — `final WorkoutTemplate template; final int exerciseCount; final int totalSets; final DateTime? lastPerformedAt;`.
  - `TemplateRepository`:
    - `Stream<List<TemplateSummary>> watchSummaries()`
    - `Stream<TemplateWithExercises?> watchTemplate(String id)`
    - `Future<WorkoutTemplate> createTemplate({required String name, String? notes, int defaultRestSeconds = 90})`
    - `Future<void> updateTemplate(WorkoutTemplate template)`
    - `Future<void> deleteTemplate(String id)`
    - `Future<WorkoutTemplate> duplicateTemplate(String id)`
    - `Future<TemplateExercise> addExercise({required String templateId, required String exerciseId, int? targetSets, int? restSeconds, double? defaultRir, int? defaultDurationSeconds})`
    - `Future<void> updateTemplateExercise(TemplateExercise te)`
    - `Future<void> removeTemplateExercise(String id)`
    - `Future<void> reorderExercises(String templateId, int oldIndex, int newIndex)`
  - `templateRepositoryProvider`, `templateSummariesProvider` (`StreamProvider<List<TemplateSummary>>`), `templateProvider` (`StreamProvider.family<TemplateWithExercises?, String>`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/db/template_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'test_database.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository exercises;
  late TemplateRepository templates;

  setUp(() {
    db = testDatabase();
    exercises = ExerciseRepository(db);
    templates = TemplateRepository(db);
  });
  tearDown(() => db.close());

  Future<String> makeExercise(String name) async {
    final e = await exercises.create(
        name: name, loggingType: LoggingType.strengthWeightRepsRir);
    return e.id;
  }

  test('adds exercises with default sets and rest, in insertion order',
      () async {
    final t = await templates.createTemplate(name: 'Push');
    await templates.addExercise(
        templateId: t.id, exerciseId: await makeExercise('Bench Press'));
    await templates.addExercise(
        templateId: t.id, exerciseId: await makeExercise('Overhead Press'));

    final loaded = (await templates.watchTemplate(t.id).first)!;

    expect(loaded.exercises.map((e) => e.name),
        ['Bench Press', 'Overhead Press']);
    expect(loaded.exercises.first.config.targetSets, 3);
    expect(loaded.exercises.first.config.restSeconds, 90);
    expect(loaded.totalSets, 6);
  });

  test('reorderExercises moves an exercise and renumbers sortOrder densely',
      () async {
    final t = await templates.createTemplate(name: 'Pull');
    for (final n in ['A', 'B', 'C']) {
      await templates.addExercise(
          templateId: t.id, exerciseId: await makeExercise(n));
    }

    await templates.reorderExercises(t.id, 2, 0);

    final loaded = (await templates.watchTemplate(t.id).first)!;
    expect(loaded.exercises.map((e) => e.name), ['C', 'A', 'B']);
    expect(loaded.exercises.map((e) => e.config.sortOrder), [0, 1, 2]);
  });

  test('duplicateTemplate copies exercises but produces new ids', () async {
    final t = await templates.createTemplate(name: 'Legs A');
    await templates.addExercise(
      templateId: t.id,
      exerciseId: await makeExercise('Back Squat'),
      targetSets: 5,
      restSeconds: 180,
    );

    final copy = await templates.duplicateTemplate(t.id);

    expect(copy.id, isNot(t.id));
    expect(copy.name, 'Legs A (copy)');

    final loaded = (await templates.watchTemplate(copy.id).first)!;
    expect(loaded.exercises.single.config.targetSets, 5);
    expect(loaded.exercises.single.config.restSeconds, 180);
    expect(loaded.exercises.single.config.id,
        isNot((await templates.watchTemplate(t.id).first)!.exercises.single.config.id));
  });

  test('removing an exercise renumbers the remaining sortOrder', () async {
    final t = await templates.createTemplate(name: 'Ab Circuit');
    final ids = <String>[];
    for (final n in ['A', 'B', 'C']) {
      final te = await templates.addExercise(
          templateId: t.id, exerciseId: await makeExercise(n));
      ids.add(te.id);
    }

    await templates.removeTemplateExercise(ids[1]);

    final loaded = (await templates.watchTemplate(t.id).first)!;
    expect(loaded.exercises.map((e) => e.name), ['A', 'C']);
    expect(loaded.exercises.map((e) => e.config.sortOrder), [0, 1]);
  });

  test('deleting a template cascades to its template exercises', () async {
    final t = await templates.createTemplate(name: 'Temp');
    await templates.addExercise(
        templateId: t.id, exerciseId: await makeExercise('X'));

    await templates.deleteTemplate(t.id);

    expect(await db.select(db.templateExercises).get(), isEmpty);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/db/template_dao_test.dart`
Expected: FAIL — `TemplateRepository` is not defined.

- [ ] **Step 3: Implement the aggregates**

```dart
// lib/features/templates/data/template_models.dart
import '../../../db/app_database.dart';

class TemplateExerciseWithExercise {
  const TemplateExerciseWithExercise({
    required this.config,
    required this.exercise,
  });

  final TemplateExercise config;
  final Exercise exercise;

  String get name => exercise.name;
  bool get isArchived => exercise.isArchived;
  LoggingType get loggingType => exercise.loggingType;
}

class TemplateWithExercises {
  const TemplateWithExercises({
    required this.template,
    required this.exercises,
  });

  final WorkoutTemplate template;
  final List<TemplateExerciseWithExercise> exercises;

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.config.targetSets);

  bool get canStart => exercises.isNotEmpty;
}

class TemplateSummary {
  const TemplateSummary({
    required this.template,
    required this.exerciseCount,
    required this.totalSets,
    this.lastPerformedAt,
  });

  final WorkoutTemplate template;
  final int exerciseCount;
  final int totalSets;
  final DateTime? lastPerformedAt;
}
```

- [ ] **Step 4: Implement the repository**

Key implementation notes:
- `watchTemplate` joins `templateExercises` to `exercises`, orders by `sortOrder`, and emits `null` when the template row is gone.
- `addExercise` computes `sortOrder` as `max(existing) + 1` (or 0 when empty).
- `reorderExercises` reads the ordered list, does a `removeAt`/`insert` in Dart, then writes back dense `sortOrder` values `0..n-1` inside one `transaction`.
- `removeTemplateExercise` deletes and then renumbers the remaining rows the same way.
- `duplicateTemplate` copies the template with name `'<name> (copy)'` and inserts fresh `TemplateExercise` rows with new ids inside a `transaction`.
- `watchSummaries` derives `lastPerformedAt` from the most recent `WorkoutSession` with `status = completed` and a matching `templateId`; templates that have never been run yield `null`.
- Every write sets `updatedAt: DateTime.now()`.

- [ ] **Step 5: Run tests and confirm they pass**

Run: `flutter test test/db/template_dao_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Implement the providers**

```dart
// lib/features/templates/providers/template_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/template_models.dart';
import '../data/template_repository.dart';

final templateSummariesProvider = StreamProvider<List<TemplateSummary>>(
  (ref) => ref.watch(templateRepositoryProvider).watchSummaries(),
);

final templateProvider =
    StreamProvider.family<TemplateWithExercises?, String>(
  (ref, id) => ref.watch(templateRepositoryProvider).watchTemplate(id),
);
```

- [ ] **Step 7: Commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add workout template repository with reorder and duplicate"
```

---

## Task 7: Home screen — workout template list

**Files:**
- Create: `lib/features/templates/ui/home_screen.dart`
- Modify: `lib/app/router.dart` (replace the Task 1 placeholder at `/`)
- Test: `test/widget/home_screen_test.dart`

**Interfaces:**
- Consumes: `templateSummariesProvider`, `templateRepositoryProvider`, `EmptyState`, `confirmDestructive`.
- Produces: `HomeScreen`. Route `/` renders it. It navigates to `/templates/new`, `/templates/:id`, and `/session/:id` (the last is only wired in Task 11 — until then the Start button calls a callback that Task 9 fills in).

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widget/home_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:gymflow/features/templates/ui/home_screen.dart';
import '../db/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HomeScreen()),
      );

  testWidgets('empty state invites creating the first workout', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('Create your first workout'), findsOneWidget);
  });

  testWidgets('a workout card shows its exercise and set counts',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    for (final n in ['Bench Press', 'Overhead Press']) {
      final e = await exercises.create(
          name: n, loggingType: LoggingType.strengthWeightRepsRir);
      await templates.addExercise(templateId: t.id, exerciseId: e.id);
    }

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Push'), findsOneWidget);
    expect(find.textContaining('2 exercises'), findsOneWidget);
    expect(find.textContaining('6 sets'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
  });

  testWidgets('Start is disabled for a template with no exercises',
      (tester) async {
    await TemplateRepository(db).createTemplate(name: 'Empty');

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start'),
    );
    expect(button.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/widget/home_screen_test.dart`
Expected: FAIL — `HomeScreen` is not defined.

- [ ] **Step 3: Implement `HomeScreen`**

Structure:
- `AppBar` titled `Workouts`, with actions: an `Icons.fitness_center` button to `/exercises`, an `Icons.history` button to `/history`, an `Icons.settings` button to `/settings`.
- `FloatingActionButton.extended` "New workout" → `/templates/new`.
- Body: `templateSummariesProvider.when(...)`, `EmptyState` when the list is empty with `actionLabel: 'Create your first workout'`.
- Each card (`Card` > `Padding` > `Column`):
  - Row 1: template name in `titleLarge`, then a `PopupMenuButton` with Edit / Duplicate / Delete. Delete calls `confirmDestructive` first.
  - Row 2: metadata line — `'$exerciseCount exercises · $totalSets sets'`, plus `' · Last: ${DateFormat.MMMd().format(lastPerformedAt!)}'` when present.
  - Row 3: a full-width `FilledButton` labelled `Start`, `onPressed: null` when `exerciseCount == 0`, and a helper line "Add an exercise before you can start" underneath in the muted semantic colour when disabled (PRD §18.1).
- The card body (outside the Start button) is tappable and opens the editor.

Pluralise correctly: `1 exercise` / `2 exercises`, `1 set` / `6 sets`.

- [ ] **Step 4: Point the root route at it**

```dart
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
```

Delete the placeholder scaffold from Task 1. The Task 1 boot test still passes because `HomeScreen`'s app bar title is also `Workouts`.

- [ ] **Step 5: Run the full suite and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add home screen listing workout templates"
```

---

## Task 8: Template editor

**Files:**
- Create: `lib/features/templates/ui/template_editor_screen.dart`
- Create: `lib/features/templates/ui/template_exercise_settings_sheet.dart`
- Create: `lib/features/exercises/ui/exercise_picker_sheet.dart`
- Create: `lib/core/widgets/numeric_field.dart`
- Modify: `lib/app/router.dart`
- Test: `test/widget/template_editor_test.dart`

**Interfaces:**
- Consumes: `templateProvider`, `templateRepositoryProvider`, `filteredExercisesProvider`, `showExerciseInfoSheet`, `confirmDestructive`.
- Produces:
  - `TemplateEditorScreen({String? templateId})` — creates a draft template immediately when `templateId` is null so every edit can persist straight away.
  - `Future<String?> showExercisePickerSheet(BuildContext context)` — returns the chosen `exerciseId`, or null on cancel. Includes a "Create new exercise" row that pushes the exercise editor and returns the new id.
  - `Future<void> showTemplateExerciseSettings(BuildContext context, {required TemplateExercise config, required LoggingType loggingType, required ValueChanged<TemplateExercise> onChanged})`.
  - `NumericField({required String label, required num? value, required ValueChanged<num?> onChanged, bool allowDecimal = false, num? min, num? max, String? suffix})`.
- Routes: `/templates/new`, `/templates/:id`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widget/template_editor_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:gymflow/features/templates/ui/template_editor_screen.dart';
import '../db/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  testWidgets('renders the template name and its exercises with sets and rest',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 5, restSeconds: 180);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: TemplateEditorScreen(templateId: t.id)),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Legs A'), findsOneWidget);
    expect(find.text('Back Squat'), findsOneWidget);
    expect(find.textContaining('5 sets'), findsOneWidget);
    expect(find.textContaining('3:00 rest'), findsOneWidget);
    expect(find.byType(ReorderableListView), findsOneWidget);
  });

  testWidgets('an archived exercise in a template is flagged', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    final e = await exercises.create(
        name: 'Old Machine', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(templateId: t.id, exerciseId: e.id);
    await exercises.archive(e.id);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: TemplateEditorScreen(templateId: t.id)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Archived'), findsOneWidget);
  });
}
```

Note: `watchTemplate` must therefore join archived exercises too — only the *library list* hides them (PRD §18.2).

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/widget/template_editor_test.dart`
Expected: FAIL — `TemplateEditorScreen` is not defined.

- [ ] **Step 3: Implement `NumericField`**

```dart
// lib/core/widgets/numeric_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NumericField extends StatefulWidget {
  const NumericField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowDecimal = false,
    this.min,
    this.max,
    this.suffix,
    this.autofocus = false,
  });

  final String label;
  final num? value;
  final ValueChanged<num?> onChanged;
  final bool allowDecimal;
  final num? min;
  final num? max;
  final String? suffix;
  final bool autofocus;

  @override
  State<NumericField> createState() => _NumericFieldState();
}

class _NumericFieldState extends State<NumericField> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));

  static String _format(num? v) {
    if (v == null) return '';
    if (v is int) return v.toString();
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

  @override
  void didUpdateWidget(covariant NumericField old) {
    super.didUpdateWidget(old);
    // Only push external changes down when the field is not being edited,
    // so typing is never fought by a rebuild.
    final incoming = _format(widget.value);
    if (widget.value != old.value && _controller.text != incoming) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit(String raw) {
    if (raw.trim().isEmpty) {
      widget.onChanged(null);
      return;
    }
    num? parsed = widget.allowDecimal ? double.tryParse(raw) : int.tryParse(raw);
    if (parsed == null) return;
    if (widget.min != null && parsed < widget.min!) parsed = widget.min;
    if (widget.max != null && parsed > widget.max!) parsed = widget.max;
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: widget.allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          widget.allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
      ),
      onChanged: _emit,
    );
  }
}
```

- [ ] **Step 4: Implement the exercise picker sheet**

A full-height `DraggableScrollableSheet` with a search field bound to `filteredExercisesProvider`, a pinned "Create new exercise" `ListTile` at the top, and one tile per exercise with a trailing info icon calling `showExerciseInfoSheet`. Tapping a tile pops with that exercise's id.

- [ ] **Step 5: Implement the per-exercise settings sheet**

Fields, all persisting on change:
- Target sets — `NumericField(min: 1, max: 20)`
- Rest seconds — `NumericField(min: 0, max: 3600, suffix: 's')` plus a `Wrap` of preset `ActionChip`s: 30s, 60s, 90s, 120s, 180s, 240s (PRD FR-113)
- Default RIR — dropdown over `[null, 0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5]`, shown only when `loggingType == strengthWeightRepsRir`
- Default duration seconds — `NumericField`, shown only when `loggingType == durationOnly`
- Per-template note — multiline `TextField`

- [ ] **Step 6: Implement `TemplateEditorScreen`**

- When `templateId` is null, create a draft on `initState` via `createTemplate(name: '')` and keep its id in state; the screen then behaves identically to editing. A back-out with an empty name and no exercises deletes the draft so blank templates never litter Home.
- Metadata section: name `TextField` (persist on change, debounce 300ms), notes `TextField`, default rest `NumericField`, and two `SwitchListTile`s for `autoFocusNextSet` / `autoFocusNextExercise`.
- Exercise section: `ReorderableListView.builder` with `buildDefaultDragHandles: false` and an explicit `ReorderableDragStartListener` wrapping a `Icons.drag_handle` icon. `onReorder` calls `reorderExercises`.
- Each row shows: name (with an `Archived` `Chip` when `isArchived`), a subtitle `'${targetSets} sets · ${formatDurationSeconds(restSeconds)} rest'`, and trailing icons: info, settings (opens the settings sheet), remove (with an undo snackbar), drag handle.
- Bottom: an `Icons.add` `OutlinedButton` "Add exercise" that opens the picker and calls `addExercise` with the template's `defaultRestSeconds`.
- App bar action: `Start workout` — enabled only when there is at least one exercise; wired in Task 9.

`3:00 rest` in the test comes from `formatDurationSeconds(180)`.

- [ ] **Step 7: Add routes**

```dart
    GoRoute(path: '/templates/new', builder: (_, __) => const TemplateEditorScreen()),
    GoRoute(
      path: '/templates/:id',
      builder: (_, s) => TemplateEditorScreen(templateId: s.pathParameters['id']),
    ),
```

- [ ] **Step 8: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add template editor with reorder, picker and per-exercise settings"
```

---

## Task 9: Session snapshot creation

**Files:**
- Create: `lib/features/sessions/data/session_models.dart`
- Create: `lib/features/sessions/data/session_repository.dart`
- Test: `test/sessions/session_snapshot_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `TemplateRepository`, `newId()`.
- Produces:
  - `SessionSetWithMeta` is **not** needed — `SessionSet` rows are used directly.
  - `SessionExerciseWithSets` — `final SessionExercise exercise; final List<SessionSet> sets;` with `bool get isComplete`, `int get completedSetCount`, `SessionSet? get firstPendingSet`.
  - `ActiveSession` — `final WorkoutSession session; final List<SessionExerciseWithSets> exercises;` with `int get totalSets`, `int get completedSets`, `int get totalExercises`, `int get completedExercises`, `SessionExerciseWithSets? exerciseOf(String setId)`, `SessionSet? setById(String id)`, `double get completedVolume`.
  - `SessionRepository`:
    - `Future<WorkoutSession> startFromTemplate(String templateId, {required String weightUnit})`
    - `Stream<ActiveSession?> watchActiveSession()` — the single session with status `active` or `paused`
    - `Stream<ActiveSession?> watchSession(String id)`
    - `Future<void> updateSet(SessionSet set)`
    - `Future<SessionSet> addSet(String sessionExerciseId)`
    - `Future<void> removeSet(String setId)`
    - `Future<void> updateSessionExercise(SessionExercise se)`
    - `Future<void> updateSession(WorkoutSession session)`
    - `Future<void> reorderSessionExercises(String sessionId, List<String> orderedIds)`
    - `Future<void> finishSession(String id, {String? notes})`
    - `Future<void> cancelSession(String id)`
    - `Stream<List<ActiveSession>> watchCompletedSessions()`
  - `sessionRepositoryProvider`, `activeSessionProvider` (`StreamProvider<ActiveSession?>`).

- [ ] **Step 1: Write the failing snapshot tests**

```dart
// test/sessions/session_snapshot_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';

void main() {
  late AppDatabase db;
  late ExerciseRepository exercises;
  late TemplateRepository templates;
  late SessionRepository sessions;

  setUp(() {
    db = testDatabase();
    exercises = ExerciseRepository(db);
    templates = TemplateRepository(db);
    sessions = SessionRepository(db);
  });
  tearDown(() => db.close());

  Future<String> pushTemplate() async {
    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
      name: 'Bench Press',
      loggingType: LoggingType.strengthWeightRepsRir,
      description: 'Flat barbell press.',
      notes: 'Pause on the chest.',
    );
    final plank = await exercises.create(
        name: 'Plank', loggingType: LoggingType.durationOnly);
    await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 3, restSeconds: 120,
        defaultRir: 2);
    await templates.addExercise(
        templateId: t.id, exerciseId: plank.id, targetSets: 2, restSeconds: 45,
        defaultDurationSeconds: 45);
    return t.id;
  }

  test('generates one set row per target set, in order', () async {
    final id = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    final session = (await sessions.watchSession(id.id).first)!;

    expect(session.exercises.map((e) => e.exercise.name),
        ['Bench Press', 'Plank']);
    expect(session.exercises[0].sets, hasLength(3));
    expect(session.exercises[1].sets, hasLength(2));
    expect(session.exercises[0].sets.map((s) => s.setIndex), [0, 1, 2]);
    expect(session.totalSets, 5);
    expect(session.completedSets, 0);
  });

  test('snapshots exercise description, notes and logging type', () async {
    final id = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    final session = (await sessions.watchSession(id.id).first)!;
    final bench = session.exercises.first.exercise;

    expect(bench.description, 'Flat barbell press.');
    expect(bench.notes, 'Pause on the chest.');
    expect(bench.loggingType, LoggingType.strengthWeightRepsRir);
    expect(bench.restSeconds, 120);
    expect(bench.targetSets, 3);
  });

  test('seeds default RIR and default duration into the generated sets',
      () async {
    final id = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    final session = (await sessions.watchSession(id.id).first)!;

    expect(session.exercises[0].sets.every((s) => s.rir == 2), isTrue);
    expect(session.exercises[0].sets.every((s) => s.weight == null), isTrue);
    expect(
        session.exercises[1].sets.every((s) => s.durationSeconds == 45), isTrue);
  });

  test('editing the session never touches the template', () async {
    final templateId = await pushTemplate();
    final started = await sessions.startFromTemplate(templateId, weightUnit: 'kg');
    var session = (await sessions.watchSession(started.id).first)!;

    await sessions.updateSessionExercise(
      session.exercises.first.exercise.copyWith(restSeconds: 300),
    );
    await sessions.reorderSessionExercises(started.id, [
      session.exercises[1].exercise.id,
      session.exercises[0].exercise.id,
    ]);

    final template = (await templates.watchTemplate(templateId).first)!;
    expect(template.exercises.map((e) => e.name), ['Bench Press', 'Plank']);
    expect(template.exercises.first.config.restSeconds, 120);

    session = (await sessions.watchSession(started.id).first)!;
    expect(session.exercises.map((e) => e.exercise.name), ['Plank', 'Bench Press']);
  });

  test('watchActiveSession finds the active session and drops finished ones',
      () async {
    final started = await sessions.startFromTemplate(await pushTemplate(),
        weightUnit: 'kg');
    expect((await sessions.watchActiveSession().first)?.session.id, started.id);

    await sessions.finishSession(started.id, notes: 'Felt strong');

    expect(await sessions.watchActiveSession().first, isNull);
    final finished = (await sessions.watchSession(started.id).first)!;
    expect(finished.session.status, SessionStatus.completed);
    expect(finished.session.notes, 'Felt strong');
    expect(finished.session.endedAt, isNotNull);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/sessions/session_snapshot_test.dart`
Expected: FAIL — `SessionRepository` is not defined.

- [ ] **Step 3: Implement the aggregates**

```dart
// lib/features/sessions/data/session_models.dart
import '../../../db/app_database.dart';

class SessionExerciseWithSets {
  const SessionExerciseWithSets({required this.exercise, required this.sets});

  final SessionExercise exercise;
  final List<SessionSet> sets;

  bool get isComplete =>
      sets.isNotEmpty && sets.every((s) => s.completedAt != null);

  int get completedSetCount => sets.where((s) => s.completedAt != null).length;

  SessionSet? get firstPendingSet {
    for (final s in sets) {
      if (s.completedAt == null) return s;
    }
    return null;
  }
}

class ActiveSession {
  const ActiveSession({required this.session, required this.exercises});

  final WorkoutSession session;
  final List<SessionExerciseWithSets> exercises;

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.sets.length);

  int get completedSets =>
      exercises.fold(0, (sum, e) => sum + e.completedSetCount);

  int get totalExercises => exercises.length;

  int get completedExercises => exercises.where((e) => e.isComplete).length;

  /// Sum of weight x reps over completed strength sets that have both values.
  double get completedVolume {
    var total = 0.0;
    for (final e in exercises) {
      if (e.exercise.loggingType != LoggingType.strengthWeightRepsRir) continue;
      for (final s in e.sets) {
        if (s.completedAt == null) continue;
        final w = s.weight;
        final r = s.reps;
        if (w != null && r != null) total += w * r;
      }
    }
    return total;
  }

  SessionExerciseWithSets? exerciseOf(String setId) {
    for (final e in exercises) {
      if (e.sets.any((s) => s.id == setId)) return e;
    }
    return null;
  }

  SessionExerciseWithSets? exerciseById(String id) {
    for (final e in exercises) {
      if (e.exercise.id == id) return e;
    }
    return null;
  }

  SessionSet? setById(String id) {
    for (final e in exercises) {
      for (final s in e.sets) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  Duration elapsed(DateTime now) =>
      (session.endedAt ?? now).difference(session.startedAt) -
      Duration(seconds: session.pausedSeconds);
}
```

- [ ] **Step 4: Implement `SessionRepository`**

Implementation notes:
- `startFromTemplate` runs in one `transaction`: read the template with its exercises, insert the `WorkoutSession` (status `active`, `startedAt: now`, `restStatus: idle`, auto-focus flags copied from the template), then for each template exercise insert a `SessionExercise` snapshotting `name`, `description`, `notes`, `imagePath`, `loggingType` from the **library exercise** and `sortOrder`, `restSeconds`, `targetSets` from the **template exercise config**, then insert `targetSets` `SessionSet` rows with `setIndex` `0..n-1`, `rir: config.defaultRir`, `durationSeconds: config.defaultDurationSeconds`, everything else null.
- `watchSession` builds the aggregate from two watched queries combined with `Rx`-free `StreamZip`-style composition — simplest correct approach is a single `db.select(sessionExercises).join(...)` watch plus a separate sets watch, merged via `.asyncMap`. Prefer: watch `sessionExercises` ordered by `sortOrder`, then inside `asyncMap` fetch sets ordered by `setIndex`. Correctness over cleverness here.
- `addSet` appends with `setIndex = max(existing) + 1`; `removeSet` deletes and renumbers `setIndex` densely.
- `reorderSessionExercises(sessionId, orderedIds)` writes `sortOrder = index` for each id in one transaction.
- `finishSession` sets `status: completed`, `endedAt: now`, `notes`, and clears every rest column back to idle.
- `cancelSession` sets `status: cancelled` and `endedAt: now`.
- `watchActiveSession` filters `status IN (active, paused)` and takes the most recently started.
- Every write sets `updatedAt`.

- [ ] **Step 5: Run tests and confirm they pass**

Run: `flutter test test/sessions/session_snapshot_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Add the provider and commit**

```dart
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);

final activeSessionProvider = StreamProvider<ActiveSession?>(
  (ref) => ref.watch(sessionRepositoryProvider).watchActiveSession(),
);
```

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: create immutable session snapshots from templates"
```

---

## Task 10: Session engine — pure next-target, completion and reorder logic

This is the heart of the app. Everything here is a pure function so it can be exhaustively tested without widgets or a database.

**Files:**
- Create: `lib/features/sessions/domain/session_engine.dart`
- Test: `test/sessions/session_engine_test.dart`

**Interfaces:**
- Consumes: `ActiveSession`, `SessionExerciseWithSets`, `SessionSet`, `SessionExercise`, `LoggingType`.
- Produces:
  - `enum TargetKind { sameExercise, nextExercise }`
  - `SessionTarget` — `final String sessionExerciseId; final String setId; final int setIndex; final String exerciseName; final TargetKind kind;` with `String get label` returning `'$exerciseName — Set ${setIndex + 1}'`.
  - `SessionTarget? firstPendingTarget(ActiveSession s)`
  - `SessionTarget? nextTargetAfter(ActiveSession s, String completedSetId)`
  - `bool isLastSetOfSession(ActiveSession s, String setId)`
  - `List<String> moveToEnd(ActiveSession s, String sessionExerciseId)` — returns the full ordered id list
  - `List<String> reorderPending(ActiveSession s, int oldPendingIndex, int newPendingIndex)` — indices are into the *pending* sublist; completed exercises keep their positions at the front
  - `List<SessionExerciseWithSets> pendingExercises(ActiveSession s)`
  - `int restSecondsAfter(ActiveSession s, String completedSetId)` — the rest owed after completing that set, 0 when it is the session's last set

- [ ] **Step 1: Write the failing engine tests**

```dart
// test/sessions/session_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/data/session_models.dart';
import 'package:gymflow/features/sessions/domain/session_engine.dart';

final _t = DateTime.utc(2026, 8, 15, 10);

SessionSet _set(String id, int index, {bool done = false}) => SessionSet(
      id: id,
      sessionExerciseId: '',
      setIndex: index,
      weight: null,
      reps: null,
      rir: null,
      durationSeconds: null,
      completedAt: done ? _t : null,
      createdAt: _t,
      updatedAt: _t,
      deletedAt: null,
    );

SessionExerciseWithSets _ex(
  String id,
  String name, {
  required int sortOrder,
  required List<SessionSet> sets,
  int restSeconds = 90,
}) {
  return SessionExerciseWithSets(
    exercise: SessionExercise(
      id: id,
      sessionId: 's',
      exerciseId: null,
      name: name,
      description: null,
      notes: null,
      imagePath: null,
      loggingType: LoggingType.strengthWeightRepsRir,
      sortOrder: sortOrder,
      restSeconds: restSeconds,
      targetSets: sets.length,
      sessionNotes: null,
      createdAt: _t,
      updatedAt: _t,
      deletedAt: null,
    ),
    sets: [for (final s in sets) s.copyWith(sessionExerciseId: id)],
  );
}

ActiveSession _session(List<SessionExerciseWithSets> exercises) => ActiveSession(
      session: WorkoutSession(
        id: 's',
        templateId: null,
        name: 'Push',
        weightUnit: 'kg',
        status: SessionStatus.active,
        autoFocusNextSet: true,
        autoFocusNextExercise: true,
        startedAt: _t,
        endedAt: null,
        pausedSeconds: 0,
        notes: null,
        restStatus: RestTimerStatus.idle,
        restEndsAt: null,
        restRemainingSeconds: null,
        restTotalSeconds: null,
        restAfterSetId: null,
        createdAt: _t,
        updatedAt: _t,
        deletedAt: null,
      ),
      exercises: exercises,
    );

void main() {
  group('firstPendingTarget', () {
    test('is the first incomplete set of the first incomplete exercise', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [
          _set('a', 0, done: true),
          _set('b', 1),
          _set('c', 2),
        ]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('d', 0)]),
      ]);

      final target = firstPendingTarget(s)!;
      expect(target.setId, 'b');
      expect(target.exerciseName, 'Bench Press');
      expect(target.label, 'Bench Press — Set 2');
    });

    test('skips fully completed exercises', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0, done: true)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('b', 0)]),
      ]);
      expect(firstPendingTarget(s)!.setId, 'b');
    });

    test('is null when everything is done', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0, done: true)]),
      ]);
      expect(firstPendingTarget(s), isNull);
    });
  });

  group('nextTargetAfter', () {
    test('prefers the next pending set inside the same exercise', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [
          _set('a', 0, done: true),
          _set('b', 1),
        ]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('c', 0)]),
      ]);

      final target = nextTargetAfter(s, 'a')!;
      expect(target.setId, 'b');
      expect(target.kind, TargetKind.sameExercise);
    });

    test('moves to the next exercise after the final set', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0, done: true)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('b', 0)]),
      ]);

      final target = nextTargetAfter(s, 'a')!;
      expect(target.setId, 'b');
      expect(target.kind, TargetKind.nextExercise);
      expect(target.label, 'Lat Pulldown — Set 1');
    });

    test('respects the current session order, not the original order', () {
      // e2 has been dragged in front of e1.
      final s = _session([
        _ex('e2', 'Lat Pulldown', sortOrder: 0, sets: [_set('b', 0)]),
        _ex('e1', 'Bench Press', sortOrder: 1, sets: [_set('a', 0, done: true)]),
      ]);

      expect(nextTargetAfter(s, 'a'), isNull);
      expect(firstPendingTarget(s)!.setId, 'b');
    });

    test('skips already-completed sets in a later exercise', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0, done: true)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [
          _set('b', 0, done: true),
          _set('c', 1),
        ]),
      ]);
      expect(nextTargetAfter(s, 'a')!.setId, 'c');
    });

    test('is null when the completed set was the last pending one', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0, done: true)]),
      ]);
      expect(nextTargetAfter(s, 'a'), isNull);
    });
  });

  group('restSecondsAfter', () {
    test('uses the rest of the exercise the completed set belongs to', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, restSeconds: 120, sets: [
          _set('a', 0, done: true),
          _set('b', 1),
        ]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, restSeconds: 60, sets: [_set('c', 0)]),
      ]);
      expect(restSecondsAfter(s, 'a'), 120);
    });

    test('still uses the current exercise rest when crossing into the next',
        () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, restSeconds: 120,
            sets: [_set('a', 0, done: true)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, restSeconds: 60,
            sets: [_set('c', 0)]),
      ]);
      expect(restSecondsAfter(s, 'a'), 120);
    });

    test('is zero after the final set of the whole session', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, restSeconds: 120,
            sets: [_set('a', 0, done: true)]),
      ]);
      expect(restSecondsAfter(s, 'a'), 0);
      expect(isLastSetOfSession(s, 'a'), isTrue);
    });
  });

  group('reordering', () {
    test('moveToEnd sends the exercise behind every other pending one', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [_set('a', 0)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('b', 0)]),
        _ex('e3', 'Row', sortOrder: 2, sets: [_set('c', 0)]),
      ]);
      expect(moveToEnd(s, 'e1'), ['e2', 'e3', 'e1']);
    });

    test('moveToEnd keeps completed exercises anchored at the front', () {
      final s = _session([
        _ex('e0', 'Warmup', sortOrder: 0, sets: [_set('z', 0, done: true)]),
        _ex('e1', 'Bench Press', sortOrder: 1, sets: [_set('a', 0)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 2, sets: [_set('b', 0)]),
      ]);
      expect(moveToEnd(s, 'e1'), ['e0', 'e2', 'e1']);
    });

    test('reorderPending indexes into the pending sublist only', () {
      final s = _session([
        _ex('e0', 'Warmup', sortOrder: 0, sets: [_set('z', 0, done: true)]),
        _ex('e1', 'Bench Press', sortOrder: 1, sets: [_set('a', 0)]),
        _ex('e2', 'Lat Pulldown', sortOrder: 2, sets: [_set('b', 0)]),
        _ex('e3', 'Row', sortOrder: 3, sets: [_set('c', 0)]),
      ]);
      // Drag "Row" (pending index 2) to the front of the pending list.
      expect(reorderPending(s, 2, 0), ['e0', 'e3', 'e1', 'e2']);
    });

    test('a partially completed exercise still counts as pending', () {
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [
          _set('a', 0, done: true),
          _set('b', 1),
        ]),
        _ex('e2', 'Lat Pulldown', sortOrder: 1, sets: [_set('c', 0)]),
      ]);
      expect(pendingExercises(s).map((e) => e.exercise.id), ['e1', 'e2']);
      expect(moveToEnd(s, 'e1'), ['e2', 'e1']);
    });
  });

  group('volume', () {
    test('sums weight x reps over completed strength sets only', () {
      final done = _set('a', 0, done: true)
          .copyWith(weight: const Value(80), reps: const Value(8));
      final pending = _set('b', 1)
          .copyWith(weight: const Value(80), reps: const Value(8));
      final s = _session([
        _ex('e1', 'Bench Press', sortOrder: 0, sets: [done, pending]),
      ]);
      expect(s.completedVolume, 640);
    });
  });
}
```

Note the `Value(...)` wrapper on `copyWith` for nullable Drift columns — that is how generated `copyWith` accepts an explicit value for a nullable field. Import `package:drift/drift.dart` in the test for `Value`.

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/sessions/session_engine_test.dart`
Expected: FAIL — `session_engine.dart` does not exist.

- [ ] **Step 3: Implement the engine**

```dart
// lib/features/sessions/domain/session_engine.dart
import '../data/session_models.dart';

enum TargetKind { sameExercise, nextExercise }

class SessionTarget {
  const SessionTarget({
    required this.sessionExerciseId,
    required this.setId,
    required this.setIndex,
    required this.exerciseName,
    required this.kind,
  });

  final String sessionExerciseId;
  final String setId;
  final int setIndex;
  final String exerciseName;
  final TargetKind kind;

  String get label => '$exerciseName — Set ${setIndex + 1}';

  @override
  bool operator ==(Object other) =>
      other is SessionTarget &&
      other.setId == setId &&
      other.sessionExerciseId == sessionExerciseId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(setId, sessionExerciseId, kind);
}

SessionTarget _target(
  SessionExerciseWithSets exercise,
  SessionSet set,
  TargetKind kind,
) {
  return SessionTarget(
    sessionExerciseId: exercise.exercise.id,
    setId: set.id,
    setIndex: set.setIndex,
    exerciseName: exercise.exercise.name,
    kind: kind,
  );
}

/// The first incomplete set in current session order. This is the session's
/// "current set" unless the user has manually focused something else.
SessionTarget? firstPendingTarget(ActiveSession s) {
  for (final e in s.exercises) {
    final pending = e.firstPendingSet;
    if (pending != null) return _target(e, pending, TargetKind.sameExercise);
  }
  return null;
}

/// What comes after completing [completedSetId]: the next pending set in the
/// same exercise, else the first pending set of a later exercise in the
/// session's *current* order (PRD §10.1, §18.8).
SessionTarget? nextTargetAfter(ActiveSession s, String completedSetId) {
  final owner = s.exerciseOf(completedSetId);
  if (owner == null) return null;

  final ownerIndex =
      s.exercises.indexWhere((e) => e.exercise.id == owner.exercise.id);
  final completed = owner.sets.firstWhere((x) => x.id == completedSetId);

  for (final set in owner.sets) {
    if (set.setIndex > completed.setIndex && set.completedAt == null) {
      return _target(owner, set, TargetKind.sameExercise);
    }
  }

  for (var i = ownerIndex + 1; i < s.exercises.length; i++) {
    final pending = s.exercises[i].firstPendingSet;
    if (pending != null) {
      return _target(s.exercises[i], pending, TargetKind.nextExercise);
    }
  }
  return null;
}

bool isLastSetOfSession(ActiveSession s, String setId) =>
    nextTargetAfter(s, setId) == null;

/// Rest owed after completing [completedSetId] — always the rest configured on
/// the exercise that set belongs to, and zero when nothing follows (PRD §10.2).
int restSecondsAfter(ActiveSession s, String completedSetId) {
  if (isLastSetOfSession(s, completedSetId)) return 0;
  return s.exerciseOf(completedSetId)?.exercise.restSeconds ?? 0;
}

/// Exercises that still have at least one incomplete set, in session order.
List<SessionExerciseWithSets> pendingExercises(ActiveSession s) =>
    s.exercises.where((e) => !e.isComplete).toList();

List<String> _completedIds(ActiveSession s) =>
    s.exercises.where((e) => e.isComplete).map((e) => e.exercise.id).toList();

/// "Do later": send [sessionExerciseId] behind every other pending exercise.
/// Completed exercises stay locked at the front (PRD §11.3).
List<String> moveToEnd(ActiveSession s, String sessionExerciseId) {
  final pending =
      pendingExercises(s).map((e) => e.exercise.id).toList();
  if (!pending.remove(sessionExerciseId)) {
    return s.exercises.map((e) => e.exercise.id).toList();
  }
  return [..._completedIds(s), ...pending, sessionExerciseId];
}

/// Drag-reorder within the pending sublist. Indices are pending-relative, which
/// is what the UI's ReorderableListView reports since it only renders pending
/// exercises.
List<String> reorderPending(ActiveSession s, int oldIndex, int newIndex) {
  final pending = pendingExercises(s).map((e) => e.exercise.id).toList();
  if (oldIndex < 0 || oldIndex >= pending.length) {
    return s.exercises.map((e) => e.exercise.id).toList();
  }
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  final moved = pending.removeAt(oldIndex);
  pending.insert(target.clamp(0, pending.length), moved);
  return [..._completedIds(s), ...pending];
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test test/sessions/session_engine_test.dart`
Expected: PASS (16 tests).

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add -A
git commit -m "feat: add pure session engine for next-target, rest and reorder rules"
```

---

## Task 11: Rest timer domain

**Files:**
- Create: `lib/features/sessions/domain/rest_timer.dart`
- Test: `test/sessions/rest_timer_test.dart`

**Interfaces:**
- Consumes: `RestTimerStatus` (from `tables.dart`), `SessionTarget`.
- Produces:
  - `RestTimerState` — `final RestTimerStatus status; final DateTime? endsAt; final int? remainingSeconds; final int totalSeconds; final String? afterSetId; final SessionTarget? nextTarget;` with `Duration remainingAt(DateTime now)`, `double progressAt(DateTime now)` (0.0 at start → 1.0 at finish), `bool get isActive` (`running` or `paused`).
  - `const RestTimerState.idle()`
  - Static transitions, all pure and taking `now`: `RestTimer.start`, `RestTimer.pause`, `RestTimer.resume`, `RestTimer.adjust`, `RestTimer.settle`, `RestTimer.skip`, `RestTimer.cancel`.

- [ ] **Step 1: Write the failing timer tests**

```dart
// test/sessions/rest_timer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/domain/rest_timer.dart';

final t0 = DateTime.utc(2026, 8, 15, 10, 0, 0);

void main() {
  test('start anchors an end timestamp rather than a countdown', () {
    final s = RestTimer.start(seconds: 90, now: t0, afterSetId: 'a');

    expect(s.status, RestTimerStatus.running);
    expect(s.endsAt, t0.add(const Duration(seconds: 90)));
    expect(s.totalSeconds, 90);
    expect(s.afterSetId, 'a');
    expect(s.remainingAt(t0), const Duration(seconds: 90));
    expect(s.remainingAt(t0.add(const Duration(seconds: 30))),
        const Duration(seconds: 60));
  });

  test('remaining never goes negative and progress caps at 1', () {
    final s = RestTimer.start(seconds: 60, now: t0, afterSetId: 'a');
    final late = t0.add(const Duration(minutes: 5));

    expect(s.remainingAt(late), Duration.zero);
    expect(s.progressAt(late), 1.0);
    expect(s.progressAt(t0.add(const Duration(seconds: 30))), closeTo(0.5, 0.01));
  });

  test('pause freezes the remaining time', () {
    final running = RestTimer.start(seconds: 90, now: t0, afterSetId: 'a');
    final paused = RestTimer.pause(running, t0.add(const Duration(seconds: 20)));

    expect(paused.status, RestTimerStatus.paused);
    expect(paused.remainingSeconds, 70);
    // Time passing while paused changes nothing.
    expect(paused.remainingAt(t0.add(const Duration(minutes: 10))),
        const Duration(seconds: 70));
  });

  test('resume re-anchors endsAt from the frozen remainder', () {
    final running = RestTimer.start(seconds: 90, now: t0, afterSetId: 'a');
    final paused = RestTimer.pause(running, t0.add(const Duration(seconds: 20)));
    final resumeAt = t0.add(const Duration(minutes: 5));
    final resumed = RestTimer.resume(paused, resumeAt);

    expect(resumed.status, RestTimerStatus.running);
    expect(resumed.endsAt, resumeAt.add(const Duration(seconds: 70)));
    expect(resumed.remainingAt(resumeAt), const Duration(seconds: 70));
  });

  test('+15s and -15s shift the end timestamp and the total', () {
    final s = RestTimer.start(seconds: 90, now: t0, afterSetId: 'a');

    final plus = RestTimer.adjust(s, const Duration(seconds: 15), t0);
    expect(plus.remainingAt(t0), const Duration(seconds: 105));
    expect(plus.totalSeconds, 105);

    final minus = RestTimer.adjust(s, const Duration(seconds: -15), t0);
    expect(minus.remainingAt(t0), const Duration(seconds: 75));
  });

  test('-15s cannot push remaining below zero; it finishes instead', () {
    final s = RestTimer.start(seconds: 10, now: t0, afterSetId: 'a');
    final minus = RestTimer.adjust(s, const Duration(seconds: -15), t0);

    expect(minus.remainingAt(t0), Duration.zero);
    expect(minus.status, RestTimerStatus.finished);
  });

  test('adjust while paused shifts the frozen remainder', () {
    final paused = RestTimer.pause(
      RestTimer.start(seconds: 90, now: t0, afterSetId: 'a'),
      t0.add(const Duration(seconds: 20)),
    );
    final plus = RestTimer.adjust(paused, const Duration(seconds: 15), t0);

    expect(plus.status, RestTimerStatus.paused);
    expect(plus.remainingSeconds, 85);
  });

  test('settle flips a running timer to finished once the deadline passes', () {
    final s = RestTimer.start(seconds: 60, now: t0, afterSetId: 'a');

    expect(RestTimer.settle(s, t0.add(const Duration(seconds: 59))).status,
        RestTimerStatus.running);
    expect(RestTimer.settle(s, t0.add(const Duration(seconds: 60))).status,
        RestTimerStatus.finished);
    // Survives a long backgrounding: still finished, not restarted (PRD §18.3).
    expect(RestTimer.settle(s, t0.add(const Duration(hours: 2))).status,
        RestTimerStatus.finished);
  });

  test('settle leaves a paused timer alone', () {
    final paused = RestTimer.pause(
      RestTimer.start(seconds: 60, now: t0, afterSetId: 'a'),
      t0.add(const Duration(seconds: 10)),
    );
    expect(RestTimer.settle(paused, t0.add(const Duration(hours: 1))).status,
        RestTimerStatus.paused);
  });

  test('skip finishes immediately, cancel returns to idle', () {
    final s = RestTimer.start(seconds: 60, now: t0, afterSetId: 'a');

    final skipped = RestTimer.skip(s);
    expect(skipped.status, RestTimerStatus.finished);
    expect(skipped.remainingAt(t0), Duration.zero);
    expect(skipped.afterSetId, 'a');

    final cancelled = RestTimer.cancel();
    expect(cancelled.status, RestTimerStatus.idle);
    expect(cancelled.isActive, isFalse);
    expect(cancelled.afterSetId, isNull);
  });

  test('starting with zero seconds yields a finished timer, never a running one',
      () {
    final s = RestTimer.start(seconds: 0, now: t0, afterSetId: 'a');
    expect(s.status, RestTimerStatus.finished);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/sessions/rest_timer_test.dart`
Expected: FAIL — `rest_timer.dart` does not exist.

- [ ] **Step 3: Implement the domain**

```dart
// lib/features/sessions/domain/rest_timer.dart
import '../../../db/app_database.dart';
import 'session_engine.dart';

class RestTimerState {
  const RestTimerState({
    required this.status,
    required this.totalSeconds,
    this.endsAt,
    this.remainingSeconds,
    this.afterSetId,
    this.nextTarget,
  });

  const RestTimerState.idle()
      : status = RestTimerStatus.idle,
        totalSeconds = 0,
        endsAt = null,
        remainingSeconds = null,
        afterSetId = null,
        nextTarget = null;

  final RestTimerStatus status;
  final int totalSeconds;

  /// Wall-clock deadline. Authoritative while running — this is what makes the
  /// countdown survive process death.
  final DateTime? endsAt;

  /// Authoritative only while paused or finished.
  final int? remainingSeconds;

  final String? afterSetId;
  final SessionTarget? nextTarget;

  bool get isActive =>
      status == RestTimerStatus.running || status == RestTimerStatus.paused;

  Duration remainingAt(DateTime now) {
    switch (status) {
      case RestTimerStatus.running:
        final end = endsAt;
        if (end == null) return Duration.zero;
        final left = end.difference(now);
        return left.isNegative ? Duration.zero : left;
      case RestTimerStatus.paused:
        return Duration(seconds: remainingSeconds ?? 0);
      case RestTimerStatus.finished:
      case RestTimerStatus.idle:
        return Duration.zero;
    }
  }

  double progressAt(DateTime now) {
    if (totalSeconds <= 0) return 1;
    final elapsed = totalSeconds - remainingAt(now).inSeconds;
    return (elapsed / totalSeconds).clamp(0.0, 1.0);
  }

  RestTimerState copyWith({
    RestTimerStatus? status,
    int? totalSeconds,
    DateTime? endsAt,
    bool clearEndsAt = false,
    int? remainingSeconds,
    bool clearRemaining = false,
    String? afterSetId,
    SessionTarget? nextTarget,
  }) {
    return RestTimerState(
      status: status ?? this.status,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      remainingSeconds:
          clearRemaining ? null : (remainingSeconds ?? this.remainingSeconds),
      afterSetId: afterSetId ?? this.afterSetId,
      nextTarget: nextTarget ?? this.nextTarget,
    );
  }
}

abstract final class RestTimer {
  static RestTimerState start({
    required int seconds,
    required DateTime now,
    required String afterSetId,
    SessionTarget? nextTarget,
  }) {
    if (seconds <= 0) {
      return RestTimerState(
        status: RestTimerStatus.finished,
        totalSeconds: 0,
        remainingSeconds: 0,
        afterSetId: afterSetId,
        nextTarget: nextTarget,
      );
    }
    return RestTimerState(
      status: RestTimerStatus.running,
      totalSeconds: seconds,
      endsAt: now.add(Duration(seconds: seconds)),
      afterSetId: afterSetId,
      nextTarget: nextTarget,
    );
  }

  static RestTimerState pause(RestTimerState s, DateTime now) {
    if (s.status != RestTimerStatus.running) return s;
    return s.copyWith(
      status: RestTimerStatus.paused,
      remainingSeconds: s.remainingAt(now).inSeconds,
      clearEndsAt: true,
    );
  }

  static RestTimerState resume(RestTimerState s, DateTime now) {
    if (s.status != RestTimerStatus.paused) return s;
    final left = s.remainingSeconds ?? 0;
    if (left <= 0) return s.copyWith(status: RestTimerStatus.finished);
    return s.copyWith(
      status: RestTimerStatus.running,
      endsAt: now.add(Duration(seconds: left)),
      clearRemaining: true,
    );
  }

  static RestTimerState adjust(RestTimerState s, Duration delta, DateTime now) {
    final newTotal = (s.totalSeconds + delta.inSeconds).clamp(0, 3600);

    if (s.status == RestTimerStatus.paused) {
      final left = (s.remainingSeconds ?? 0) + delta.inSeconds;
      if (left <= 0) {
        return s.copyWith(
          status: RestTimerStatus.finished,
          remainingSeconds: 0,
          totalSeconds: newTotal,
        );
      }
      return s.copyWith(remainingSeconds: left, totalSeconds: newTotal);
    }

    if (s.status != RestTimerStatus.running) return s;

    final left = s.remainingAt(now) + delta;
    if (left <= Duration.zero) {
      return s.copyWith(
        status: RestTimerStatus.finished,
        remainingSeconds: 0,
        totalSeconds: newTotal,
        clearEndsAt: true,
      );
    }
    return s.copyWith(endsAt: now.add(left), totalSeconds: newTotal);
  }

  /// Recomputes status from the wall clock. Called on every tick and on every
  /// app resume — it is what turns "the deadline passed while backgrounded"
  /// into a finished state rather than a stuck countdown.
  static RestTimerState settle(RestTimerState s, DateTime now) {
    if (s.status != RestTimerStatus.running) return s;
    if (s.remainingAt(now) > Duration.zero) return s;
    return s.copyWith(
      status: RestTimerStatus.finished,
      remainingSeconds: 0,
      clearEndsAt: true,
    );
  }

  static RestTimerState skip(RestTimerState s) => s.copyWith(
        status: RestTimerStatus.finished,
        remainingSeconds: 0,
        clearEndsAt: true,
      );

  static RestTimerState cancel() => const RestTimerState.idle();
}
```

- [ ] **Step 4: Run and confirm they pass**

Run: `flutter test test/sessions/rest_timer_test.dart`
Expected: PASS (11 tests).

- [ ] **Step 5: Commit**

```bash
flutter analyze
git add -A
git commit -m "feat: add timestamp-anchored rest timer domain logic"
```

---

## Task 12: Active session controller

Wires the pure engine and timer to the database. Every user action goes through this one controller.

**Files:**
- Create: `lib/features/sessions/providers/active_session_controller.dart`
- Modify: `lib/features/sessions/data/session_repository.dart` (add `saveRestState`)
- Test: `test/sessions/active_session_controller_test.dart`

**Interfaces:**
- Consumes: `SessionRepository`, `session_engine.dart`, `rest_timer.dart`, `ActiveSession`.
- Produces:
  - `ActiveSessionState` — `final ActiveSession session; final RestTimerState rest; final String? focusedSetId; final bool restJustFinished;` with `SessionTarget? get currentTarget` (the focused set if set and still pending, else `firstPendingTarget`).
  - `ActiveSessionController extends AutoDisposeAsyncNotifier<ActiveSessionState?>` exposed as `activeSessionControllerProvider`. Methods:
    - `Future<void> completeSet(String setId)`
    - `Future<void> uncompleteSet(String setId)`
    - `Future<void> updateSetValues(String setId, {double? weight, bool clearWeight, int? reps, bool clearReps, double? rir, bool clearRir, int? durationSeconds, bool clearDuration})`
    - `Future<void> addSet(String sessionExerciseId)` / `Future<void> removeSet(String setId)`
    - `void focusSet(String setId)` / `void clearRestFinished()`
    - `Future<void> setExerciseRest(String sessionExerciseId, int seconds, {bool applyToActiveRest = true})`
    - `Future<void> pauseRest()` / `resumeRest()` / `skipRest()` / `cancelRest()` / `adjustRest(Duration delta)`
    - `Future<void> doLater(String sessionExerciseId)` / `Future<void> reorder(int oldIndex, int newIndex)`
    - `Future<void> pauseSession()` / `resumeSession()` / `Future<void> finish({String? notes})` / `Future<void> cancelSession()`
    - `Future<void> settle()` — re-runs `RestTimer.settle` and fires the rest-complete side effects; called from a 1s ticker and on app resume
  - `restTickerProvider` — `StreamProvider<DateTime>` emitting `DateTime.now()` every 500ms, but **only** while a rest is active. The UI watches this for repaint; the state itself is not recomputed from ticks.
  - `SessionRepository.saveRestState(String sessionId, RestTimerState state)` persisting `restStatus`, `restEndsAt`, `restRemainingSeconds`, `restTotalSeconds`, `restAfterSetId`.

- [ ] **Step 1: Write the failing controller tests**

```dart
// test/sessions/active_session_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> seedAndStart({int restSeconds = 90, int sets = 2}) async {
    final exercises = ExerciseRepository(db);
    final templates = TemplateRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    for (final n in ['Bench Press', 'Lat Pulldown']) {
      final e = await exercises.create(
          name: n, loggingType: LoggingType.strengthWeightRepsRir);
      await templates.addExercise(
          templateId: t.id, exerciseId: e.id,
          targetSets: sets, restSeconds: restSeconds);
    }
    await container.read(sessionRepositoryProvider)
        .startFromTemplate(t.id, weightUnit: 'kg');
  }

  setUp(() {
    db = testDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  Future<ActiveSessionState> state() async =>
      (await container.read(activeSessionControllerProvider.future))!;

  test('completing a set stamps it and starts rest for that exercise', () async {
    await seedAndStart(restSeconds: 120);
    final controller = container.read(activeSessionControllerProvider.notifier);

    final firstSetId = (await state()).session.exercises.first.sets.first.id;
    await controller.completeSet(firstSetId);

    final s = await state();
    expect(s.session.setById(firstSetId)!.completedAt, isNotNull);
    expect(s.rest.status, RestTimerStatus.running);
    expect(s.rest.totalSeconds, 120);
    expect(s.rest.nextTarget!.setIndex, 1);
  });

  test('rest of zero seconds never starts a timer', () async {
    await seedAndStart(restSeconds: 0);
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.completeSet((await state()).session.exercises.first.sets.first.id);

    final s = await state();
    expect(s.rest.isActive, isFalse);
    expect(s.currentTarget!.setIndex, 1);
  });

  test('the final set of the session starts no rest', () async {
    await seedAndStart(sets: 1);
    final controller = container.read(activeSessionControllerProvider.notifier);

    for (final ex in (await state()).session.exercises) {
      await controller.completeSet(ex.sets.single.id);
    }

    final s = await state();
    expect(s.rest.isActive, isFalse);
    expect(s.currentTarget, isNull);
    expect(s.session.completedSets, 2);
  });

  test('completing another set while resting restarts rest from the new set',
      () async {
    await seedAndStart(restSeconds: 90);
    final controller = container.read(activeSessionControllerProvider.notifier);

    final sets = (await state()).session.exercises.first.sets;
    await controller.completeSet(sets[0].id);
    final firstRestEnd = (await state()).rest.endsAt;

    await controller.completeSet(sets[1].id);
    final s = await state();

    expect(s.rest.status, RestTimerStatus.running);
    expect(s.rest.afterSetId, sets[1].id);
    expect(s.rest.endsAt, isNot(firstRestEnd));
  });

  test('uncompleting the set that owns the active rest cancels it', () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);
    final setId = (await state()).session.exercises.first.sets.first.id;

    await controller.completeSet(setId);
    expect((await state()).rest.isActive, isTrue);

    await controller.uncompleteSet(setId);
    final s = await state();
    expect(s.rest.status, RestTimerStatus.idle);
    expect(s.session.setById(setId)!.completedAt, isNull);
  });

  test('uncompleting an older set leaves the active rest alone', () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);
    final sets = (await state()).session.exercises.first.sets;

    await controller.completeSet(sets[0].id);
    await controller.completeSet(sets[1].id);
    await controller.uncompleteSet(sets[0].id);

    expect((await state()).rest.status, RestTimerStatus.running);
  });

  test('rest state is persisted so it survives a controller rebuild', () async {
    await seedAndStart(restSeconds: 90);
    final controller = container.read(activeSessionControllerProvider.notifier);
    await controller.completeSet((await state()).session.exercises.first.sets.first.id);
    final endsAt = (await state()).rest.endsAt;

    container.invalidate(activeSessionControllerProvider);
    final restored = await state();

    expect(restored.rest.status, RestTimerStatus.running);
    expect(restored.rest.endsAt, endsAt);
  });

  test('doLater sends the current exercise to the back', () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);
    final firstId = (await state()).session.exercises.first.exercise.id;

    await controller.doLater(firstId);

    final s = await state();
    expect(s.session.exercises.last.exercise.id, firstId);
    expect(s.currentTarget!.exerciseName, 'Lat Pulldown');
  });

  test('editing rest mid-rest extends the running timer', () async {
    await seedAndStart(restSeconds: 60);
    final controller = container.read(activeSessionControllerProvider.notifier);
    final exId = (await state()).session.exercises.first.exercise.id;
    await controller.completeSet((await state()).session.exercises.first.sets.first.id);

    await controller.setExerciseRest(exId, 180);

    final s = await state();
    expect(s.rest.totalSeconds, 180);
    expect(s.session.exercises.first.exercise.restSeconds, 180);
  });

  test('finishing a session clears it from the active provider', () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.finish(notes: 'Done');

    expect(await container.read(activeSessionControllerProvider.future), isNull);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/sessions/active_session_controller_test.dart`
Expected: FAIL — `activeSessionControllerProvider` is not defined.

- [ ] **Step 3: Add `saveRestState` to the repository**

```dart
  Future<void> saveRestState(String sessionId, RestTimerState rest) async {
    await (_db.update(_db.workoutSessions)..where((t) => t.id.equals(sessionId)))
        .write(WorkoutSessionsCompanion(
      restStatus: Value(rest.status),
      restEndsAt: Value(rest.endsAt),
      restRemainingSeconds: Value(rest.remainingSeconds),
      restTotalSeconds: Value(rest.totalSeconds),
      restAfterSetId: Value(rest.afterSetId),
      updatedAt: Value(DateTime.now()),
    ));
  }
```

And a matching reader used by the controller's `build`:

```dart
  RestTimerState restStateFrom(ActiveSession s) {
    final row = s.session;
    if (row.restStatus == RestTimerStatus.idle) return const RestTimerState.idle();
    return RestTimerState(
      status: row.restStatus,
      totalSeconds: row.restTotalSeconds ?? 0,
      endsAt: row.restEndsAt,
      remainingSeconds: row.restRemainingSeconds,
      afterSetId: row.restAfterSetId,
      nextTarget: row.restAfterSetId == null
          ? null
          : nextTargetAfter(s, row.restAfterSetId!),
    );
  }
```

- [ ] **Step 4: Implement the controller**

Behaviour contract, in the order the tests exercise it:

1. `build()` — watches `sessionRepository.watchActiveSession()`. When there is no active session, returns `null`. Otherwise rebuilds `ActiveSessionState` with the rest state rehydrated from the row and passed through `RestTimer.settle(now)`; if `settle` changed the status, persist the change.
2. `completeSet(setId)` — write `completedAt: now` via `updateSet`, fire `HapticsService.setCompleted()`, then compute `restSecondsAfter` and `nextTargetAfter` on the **post-write** session and either `RestTimer.start(...)` (rest > 0) or leave rest idle and set `focusedSetId` to the next target. Persist the rest state. Because completing while resting recomputes from scratch, PRD §18.4 falls out for free.
3. `uncompleteSet(setId)` — clear `completedAt`. If `rest.afterSetId == setId`, `cancelRest()`. Otherwise leave rest untouched (PRD FR-106).
4. `updateSetValues` — the `clearX` booleans exist because Drift's nullable `Value` needs an explicit "set to null" signal; a plain null argument means "leave unchanged".
5. `setExerciseRest(id, seconds, applyToActiveRest)` — writes `restSeconds` on the session exercise, and when the active rest belongs to that exercise and `applyToActiveRest` is true, rebuilds the running timer with the new total anchored on the elapsed portion (PRD FR-113).
6. `doLater` / `reorder` — call `moveToEnd` / `reorderPending` and hand the resulting id list to `reorderSessionExercises`. Never touch the rest timer (PRD §18.8).
7. `settle()` — `RestTimer.settle`; if the status flipped to `finished`, set `restJustFinished = true`, persist, and call the side effects added in Task 18 (haptic, sound, notification). Auto-focus is handled in Task 15.
8. `pauseSession()` — sets session status `paused` and pauses any running rest. `resumeSession()` adds the paused wall-time to `pausedSeconds` and resumes rest.
9. Every mutation persists before the state is emitted.

- [ ] **Step 5: Implement the ticker**

```dart
final restTickerProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  while (true) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    yield DateTime.now();
  }
});
```

The UI only watches this while `rest.isActive`, so `autoDispose` stops it when rest ends.

- [ ] **Step 6: Run tests and commit**

Run: `flutter test test/sessions/active_session_controller_test.dart`
Expected: PASS (10 tests).

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add active session controller wiring engine, timer and DB"
```

---

## Task 13: Active session screen and set rows

**Files:**
- Create: `lib/features/sessions/ui/active_session_screen.dart`
- Create: `lib/features/sessions/ui/widgets/session_progress_header.dart`
- Create: `lib/features/sessions/ui/widgets/session_exercise_card.dart`
- Create: `lib/features/sessions/ui/widgets/strength_set_row.dart`
- Create: `lib/features/sessions/ui/widgets/duration_set_row.dart`
- Modify: `lib/app/router.dart`, `lib/features/templates/ui/home_screen.dart` (wire Start), `lib/features/templates/ui/template_editor_screen.dart` (wire Start)
- Test: `test/widget/active_session_test.dart`

**Interfaces:**
- Consumes: `activeSessionControllerProvider`, `showExerciseInfoSheet`, `NumericField`, `SemanticColors`, `formatting.dart`.
- Produces: `ActiveSessionScreen`; `StrengthSetRow({required SessionSet set, required bool isCurrent, required String weightUnit, ...callbacks})`; `DurationSetRow(...)`; `SessionExerciseCard({required SessionExerciseWithSets exercise, required bool expanded, ...})`; `SessionProgressHeader`. Route `/session`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widget/active_session_test.dart — key expectations
testWidgets('an exercise with 3 target sets renders 3 rows', (tester) async {
  // seed a template with targetSets: 3, start a session, pump ActiveSessionScreen
  expect(find.byType(StrengthSetRow), findsNWidgets(3));
  expect(find.text('Set 1'), findsOneWidget);
  expect(find.text('Set 3'), findsOneWidget);
});

testWidgets('a duration exercise renders duration rows, not weight/reps',
    (tester) async {
  expect(find.byType(DurationSetRow), findsNWidgets(2));
  expect(find.byType(StrengthSetRow), findsNothing);
});

testWidgets('the progress header counts sets and exercises', (tester) async {
  expect(find.text('0 / 6 sets'), findsOneWidget);
  expect(find.text('0 / 2 exercises'), findsOneWidget);
});

testWidgets('tapping the complete button marks the set done', (tester) async {
  await tester.tap(find.byIcon(Icons.check_circle_outline).first);
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.check_circle), findsOneWidget);
});

testWidgets('typing a weight persists it to the database', (tester) async {
  await tester.enterText(find.byType(TextField).first, '80');
  await tester.pumpAndSettle();
  // read back from the repository and assert weight == 80
});
```

Write these out fully following the seeding pattern from `test/widget/template_editor_test.dart`.

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/widget/active_session_test.dart`
Expected: FAIL — `ActiveSessionScreen` is not defined.

- [ ] **Step 3: Implement `StrengthSetRow`**

Layout, sized for one-thumb use in a gym (PRD §17):

```text
[ 1 ]  [  80.0  ]  [  8  ]  [ RIR 2 ▾ ]  [ ✓ ]
  32dp    flex 3     flex 2    flex 3     56dp
```

- Set number: a 32dp circular badge, filled with the `success` colour when complete, outlined with `primary` when it is the current set.
- Weight: `NumericField(allowDecimal: true, suffix: weightUnit)`.
- Reps: `NumericField(allowDecimal: false)`.
- RIR: a `DropdownButtonFormField<double?>` over `[null, 0, 0.5, ..., 5]` rendering `'—'` for null and `formatRir` otherwise.
- Complete: a 56x56 `IconButton` — `Icons.check_circle_outline` when pending, `Icons.check_circle` in `success` when complete. Tap toggles.
- Current row: `AnimatedContainer` with a 2dp `primary` border and a slightly raised surface colour.
- Completed row: `Opacity(0.6)`, but **all fields stay editable** (PRD §17).
- Long-press on the row opens a menu with "Remove set" (pending sets only, with an undo snackbar).

Each field's `onChanged` calls `controller.updateSetValues(...)` directly — no save button.

- [ ] **Step 4: Implement `DurationSetRow`**

`[ 1 ] [ Duration (s) ] [ 15s 30s 45s 60s chips ] [ ✓ ]`. Same badge, completion and highlight rules.

- [ ] **Step 5: Implement `SessionExerciseCard`**

- Header row: name (`titleMedium`, `maxLines: 2`, ellipsis), an `i` `IconButton` calling `showExerciseInfoSheet` with the session's **snapshot** fields, a rest chip showing `formatDurationSeconds(restSeconds)` that opens the rest-editing sheet on tap, and an expand/collapse chevron.
- Expanded body: the set rows, an "Add set" `TextButton.icon`, and a "Do later" `TextButton.icon` (only when the exercise is pending and is not the last pending one).
- Collapsed body: a one-line summary `'${completedSetCount}/${sets.length} sets · ${formatDurationSeconds(restSeconds)} rest'`.
- Completed exercises render with a `success`-tinted left edge.

- [ ] **Step 6: Implement `SessionProgressHeader`**

A pinned row under the app bar: `'$completedSets / $totalSets sets'`, `'$completedExercises / $totalExercises exercises'`, and a `LinearProgressIndicator` on the set ratio. Elapsed time lives in the app bar title area and rebuilds on a 1s ticker.

- [ ] **Step 7: Implement `ActiveSessionScreen`**

- `AppBar`: workout name + elapsed `mmss` in tabular figures; overflow menu with Session settings, Reorder exercises, Pause/Resume, Finish, Cancel.
- Body: `CustomScrollView` with the progress header, then a section of completed exercises (collapsed, in a `ExpansionTile` labelled "Completed"), then the current exercise expanded, then upcoming exercises collapsed.
- Auto-scroll: keep a `GlobalKey` per exercise card so Task 15 can `Scrollable.ensureVisible` the focused target.
- Bottom: `bottomNavigationBar` slot reserved for the rest bar (Task 14). Until then, `null`.
- `WillPopScope`/`PopScope`: leaving the screen does not end the session; back returns Home and Home shows a "Resume workout" banner when `activeSessionProvider` is non-null.

- [ ] **Step 8: Wire Start**

`HomeScreen`'s Start button and the template editor's "Start workout" action both call:

```dart
await ref.read(sessionRepositoryProvider)
    .startFromTemplate(templateId, weightUnit: unitFromSettings);
if (context.mounted) context.push('/session');
```

If an active session already exists, show a dialog offering "Resume the running session" or "Discard it and start this one" rather than silently creating a second.

Add the route:

```dart
    GoRoute(path: '/session', builder: (_, __) => const ActiveSessionScreen()),
```

- [ ] **Step 9: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add active session screen with strength and duration set rows"
```

---

## Task 14: Rest timer UI

**Files:**
- Create: `lib/features/sessions/ui/widgets/rest_bar.dart`, `lib/features/sessions/ui/widgets/rest_sheet.dart`
- Modify: `lib/features/sessions/ui/active_session_screen.dart`
- Test: `test/widget/rest_ui_test.dart`

**Interfaces:**
- Consumes: `activeSessionControllerProvider`, `restTickerProvider`, `RestTimerState`, `SemanticColors`, `mmss`.
- Produces: `RestBar` (a compact persistent bar for `bottomNavigationBar`) and `showRestSheet(BuildContext, WidgetRef)` (the expanded controls).

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widget/rest_ui_test.dart — key expectations
testWidgets('completing a set reveals the rest bar with the next target',
    (tester) async {
  // complete set 1 of an exercise with 90s rest
  expect(find.byType(RestBar), findsOneWidget);
  expect(find.textContaining('Next: Bench Press — Set 2'), findsOneWidget);
  expect(find.text('1:30'), findsOneWidget);
});

testWidgets('+15s extends the countdown', (tester) async {
  await tester.tap(find.text('+15s'));
  await tester.pumpAndSettle();
  expect(find.text('1:45'), findsOneWidget);
});

testWidgets('skip ends rest and hides the bar', (tester) async {
  await tester.tap(find.byIcon(Icons.skip_next));
  await tester.pumpAndSettle();
  expect(find.byType(RestBar), findsNothing);
});

testWidgets('pausing shows the paused colour and freezes the countdown',
    (tester) async {
  await tester.tap(find.byIcon(Icons.pause));
  await tester.pump(const Duration(seconds: 3));
  expect(find.text('1:30'), findsOneWidget);
});
```

- [ ] **Step 2: Run and confirm failure**

Expected: FAIL — `RestBar` is not defined.

- [ ] **Step 3: Implement `RestBar`**

A 72dp-tall `Material` bar. It is visible whenever `rest.isActive || restJustFinished`, and **never covers the upcoming-exercise list entirely** (PRD §9.4) — it sits in `bottomNavigationBar`, so the scroll view shrinks rather than being overlaid.

Contents when running/paused:
- Left: countdown `mmss(rest.remainingAt(now))` at `headlineMedium` with tabular figures, tinted with the `rest` semantic colour (running) or `warning` (paused).
- Middle: `'Next: ${rest.nextTarget?.label ?? "Finish workout"}'`, one line, ellipsised; below it a `LinearProgressIndicator(value: rest.progressAt(now))`.
- Right: a `-15s` `TextButton`, a `+15s` `TextButton`, a pause/resume `IconButton`, a `skip_next` `IconButton`.
- The whole bar is tappable and opens `showRestSheet`.

Contents when finished (`restJustFinished`):
- The `success` colour, the text "Rest complete", and a single prominent `FilledButton` labelled "Next set" or "Next exercise" depending on `rest.nextTarget!.kind` (PRD FR-108/109). Tapping it focuses the target and clears the finished flag. When auto-focus is on, Task 15 does this automatically and the bar just dismisses itself.

Rebuild on `ref.watch(restTickerProvider)` only while `rest.isActive`, so nothing ticks when idle.

- [ ] **Step 4: Implement `showRestSheet`**

A `showModalBottomSheet` with the same state but expanded:
- A 220dp `CircularProgressIndicator` with the countdown centred inside it at `displayMedium`.
- The next-target label underneath.
- A 2-row button grid, every button at least 56dp tall: `-15s`, `+15s`, `Pause`/`Resume`, `Skip`, `Cancel rest`, and `Undo last set` (which calls `uncompleteSet(rest.afterSetId!)` and dismisses).
- Colours: `rest` when running, `warning` when paused, `success` when finished.
- The sheet auto-dismisses when rest reaches idle.

Do not stack this sheet over other modals — close any open sheet before showing it (PRD §24.8).

- [ ] **Step 5: Mount the bar**

In `ActiveSessionScreen`, set `bottomNavigationBar: state.rest.isActive || state.restJustFinished ? const RestBar() : null`.

- [ ] **Step 6: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add compact rest bar and expanded rest controls sheet"
```

---

## Task 15: Auto-focus behaviour and session settings sheet

**Files:**
- Create: `lib/features/sessions/ui/session_settings_sheet.dart`
- Modify: `lib/features/sessions/providers/active_session_controller.dart`, `lib/features/sessions/ui/active_session_screen.dart`
- Test: extend `test/sessions/active_session_controller_test.dart`

**Interfaces:**
- Produces: `showSessionSettingsSheet(BuildContext, WidgetRef)`; controller gains `Future<void> setAutoFocusNextSet(bool)`, `Future<void> setAutoFocusNextExercise(bool)`, `Future<void> setSessionNotes(String)`, and `void goToNextTarget()`.

- [ ] **Step 1: Write the failing tests**

```dart
  test('auto-focus next set moves focus when rest finishes mid-exercise',
      () async {
    await seedAndStart(restSeconds: 1, sets: 3);
    final controller = container.read(activeSessionControllerProvider.notifier);
    final sets = (await state()).session.exercises.first.sets;

    await controller.completeSet(sets[0].id);
    await controller.skipRest();      // finishes rest immediately
    await controller.settle();

    final s = await state();
    expect(s.currentTarget!.setId, sets[1].id);
    expect(s.restJustFinished, isFalse); // consumed by the auto-focus
  });

  test('with auto-focus off, rest completion parks in a finished state',
      () async {
    await seedAndStart(restSeconds: 1, sets: 3);
    final controller = container.read(activeSessionControllerProvider.notifier);
    await controller.setAutoFocusNextSet(false);
    final sets = (await state()).session.exercises.first.sets;

    await controller.completeSet(sets[0].id);
    await controller.skipRest();
    await controller.settle();

    final s = await state();
    expect(s.restJustFinished, isTrue);
    expect(s.rest.status, RestTimerStatus.finished);

    controller.goToNextTarget();
    final after = await state();
    expect(after.currentTarget!.setId, sets[1].id);
    expect(after.restJustFinished, isFalse);
  });

  test('auto-focus next exercise applies only across an exercise boundary',
      () async {
    await seedAndStart(restSeconds: 1, sets: 1);
    final controller = container.read(activeSessionControllerProvider.notifier);
    await controller.setAutoFocusNextSet(false);
    await controller.setAutoFocusNextExercise(true);

    await controller.completeSet(
        (await state()).session.exercises.first.sets.single.id);
    await controller.skipRest();
    await controller.settle();

    final s = await state();
    expect(s.currentTarget!.exerciseName, 'Lat Pulldown');
  });

  test('neither toggle auto-completes anything', () async {
    await seedAndStart(restSeconds: 1, sets: 3);
    final controller = container.read(activeSessionControllerProvider.notifier);
    final sets = (await state()).session.exercises.first.sets;

    await controller.completeSet(sets[0].id);
    await controller.skipRest();
    await controller.settle();

    expect((await state()).session.setById(sets[1].id)!.completedAt, isNull);
  });

  test('reordering during active rest does not cancel it, and the next target '
      'is recomputed from the new order', () async {
    await seedAndStart(restSeconds: 300, sets: 1);
    final controller = container.read(activeSessionControllerProvider.notifier);
    final exercises = (await state()).session.exercises;

    await controller.completeSet(exercises[0].sets.single.id);
    expect((await state()).rest.nextTarget!.exerciseName, 'Lat Pulldown');

    await controller.reorder(0, 0); // no-op reorder of the single pending item
    expect((await state()).rest.status, RestTimerStatus.running);
  });
```

- [ ] **Step 2: Run and confirm failure**

Expected: FAIL — `setAutoFocusNextSet` is not defined.

- [ ] **Step 3: Implement the auto-focus rule in `settle()`**

```dart
  /// Called on the 1s ticker and on app resume.
  Future<void> settle() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final settled = RestTimer.settle(current.rest, DateTime.now());
    if (settled.status != RestTimerStatus.finished ||
        current.rest.status == RestTimerStatus.finished) {
      return;
    }

    await _repo.saveRestState(current.session.session.id, settled);
    await _onRestFinished();   // haptic + sound + notification (Task 18)

    // Recompute against the session's *current* order, not the order captured
    // when rest started (PRD §18.8).
    final target = settled.afterSetId == null
        ? firstPendingTarget(current.session)
        : nextTargetAfter(current.session, settled.afterSetId!);

    final autoFocus = switch (target?.kind) {
      TargetKind.sameExercise => current.session.session.autoFocusNextSet,
      TargetKind.nextExercise => current.session.session.autoFocusNextExercise,
      null => false,
    };

    state = AsyncData(current.copyWith(
      rest: settled,
      focusedSetId: autoFocus ? target?.setId : current.focusedSetId,
      restJustFinished: !autoFocus && target != null,
    ));
  }
```

`goToNextTarget()` performs the same focus move on demand and clears `restJustFinished`; it also calls `cancelRest()` so the bar disappears.

- [ ] **Step 4: Drive the UI focus**

In `ActiveSessionScreen`, `ref.listen` on `activeSessionControllerProvider` for changes to `currentTarget?.sessionExerciseId`. On change: expand that exercise's card, collapse the previously current one, and `Scrollable.ensureVisible` its `GlobalKey` with a 250ms `curve: Curves.easeOut` (PRD FR-108/109). Never move focus while the user is actively typing in a field — check `FocusManager.instance.primaryFocus` and defer if a text field on a different set holds focus.

- [ ] **Step 5: Implement the session settings sheet**

`SwitchListTile`s bound to the session row: auto-focus next set, auto-focus next exercise, keep screen on (Task 17), sound on rest complete, vibration/haptics. Plus a multiline notes `TextField` writing to `session.notes` and a read-only "Weight unit: kg" `ListTile` (PRD §9.6). Every switch persists immediately.

- [ ] **Step 6: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: auto-focus next set/exercise after rest with session settings"
```

---

## Task 16: Session reordering UI

**Files:**
- Create: `lib/features/sessions/ui/session_reorder_screen.dart`
- Modify: `lib/features/sessions/ui/active_session_screen.dart`, `lib/features/sessions/ui/widgets/session_exercise_card.dart`
- Test: `test/widget/session_reorder_test.dart`

**Interfaces:**
- Consumes: `activeSessionControllerProvider`, `pendingExercises`, `moveToEnd`, `reorderPending`.
- Produces: `SessionReorderScreen`; route `/session/reorder`.

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('dragging an upcoming exercise updates the session order',
    (tester) async {
  // three pending exercises; drag the third to the top
  await tester.drag(find.byIcon(Icons.drag_handle).last, const Offset(0, -160));
  await tester.pumpAndSettle();
  // assert the repository order is C, A, B
});

testWidgets('completed exercises are shown locked and have no drag handle',
    (tester) async {
  expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
});

testWidgets('Do later moves the current exercise to the end', (tester) async {
  await tester.tap(find.text('Do later'));
  await tester.pumpAndSettle();
  // assert the first pending exercise is now the second one
});
```

- [ ] **Step 2: Run and confirm failure**

Expected: FAIL — `SessionReorderScreen` is not defined.

- [ ] **Step 3: Implement the reorder screen**

- A full screen (not a sheet — dragging inside a sheet fights the sheet's own drag gesture).
- Completed exercises render first in a non-reorderable list with a `lock_outline` trailing icon and dimmed text, above a divider labelled "Completed".
- Pending exercises render in a `ReorderableListView.builder` with `buildDefaultDragHandles: false` and an explicit `ReorderableDragStartListener` on a 48dp `Icons.drag_handle`. Rows show name, `'${sets.length - completedSetCount} sets left · ${formatDurationSeconds(restSeconds)} rest'`, and an info icon.
- `onReorder: (o, n) => controller.reorder(o, n)` — indices are already pending-relative, which is exactly what `reorderPending` expects.
- An active rest keeps ticking; the rest bar stays mounted on this screen too.

- [ ] **Step 4: Add the inline affordances**

- "Do later" `TextButton.icon(Icons.schedule)` on the current exercise card, calling `controller.doLater(id)` and showing an undo snackbar.
- "Do next" `TextButton` on each upcoming card, which reorders that exercise to pending index 0.
- Overflow menu item "Reorder exercises" pushing `/session/reorder`.

- [ ] **Step 5: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: reorder upcoming session exercises with a Do later shortcut"
```

---

## Task 17: Lifecycle, restore and keep-screen-on

**Files:**
- Create: `lib/core/services/wakelock_service.dart`
- Modify: `lib/features/sessions/ui/active_session_screen.dart`, `lib/app/app.dart`, `lib/features/templates/ui/home_screen.dart`
- Test: `test/sessions/session_restore_test.dart`

**Interfaces:**
- Produces: `WakelockService` with `Future<void> enable()` / `Future<void> disable()`, `wakelockServiceProvider`. `ActiveSessionScreen` becomes a `WidgetsBindingObserver`.

- [ ] **Step 1: Write the failing restore test**

```dart
// test/sessions/session_restore_test.dart
test('a rest that expired while the app was closed comes back finished',
    () async {
  // start a session with 90s rest, complete a set, then rewind restEndsAt to
  // the past by writing directly to the DB, then rebuild the container.
  await db.customStatement(
    "UPDATE workout_sessions SET rest_ends_at = ? WHERE id = ?",
    [DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000, sessionId],
  );

  final fresh = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  final restored = (await fresh.read(activeSessionControllerProvider.future))!;

  expect(restored.rest.status, RestTimerStatus.finished);
  expect(restored.rest.remainingAt(DateTime.now()), Duration.zero);
});

test('a rest still in flight comes back running with the right remainder',
    () async {
  // set rest_ends_at 30s into the future
  expect(restored.rest.status, RestTimerStatus.running);
  expect(restored.rest.remainingAt(DateTime.now()).inSeconds, closeTo(30, 2));
});

test('logged set values survive a full reopen', () async {
  await controller.updateSetValues(setId, weight: 82.5, reps: 8, rir: 2);
  // rebuild the container from the same DB file
  expect(restoredSet.weight, 82.5);
  expect(restoredSet.reps, 8);
  expect(restoredSet.rir, 2);
});
```

Note Drift stores `DateTime` as Unix **seconds** by default — match that in the raw SQL, or use the Drift API instead of `customStatement` to avoid the mismatch entirely.

- [ ] **Step 2: Run and confirm failure**

Expected: FAIL — restore returns a still-running timer.

- [ ] **Step 3: Implement the observer**

```dart
class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(activeSessionControllerProvider.notifier).settle();
    });
    ref.read(wakelockServiceProvider).enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recompute rest from the wall clock rather than trusting ticks that
      // did not fire while backgrounded (PRD §10.4, §18.3).
      ref.read(activeSessionControllerProvider.notifier).settle();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ref.read(wakelockServiceProvider).disable();
    super.dispose();
  }
  // ...
}
```

The wakelock call is gated on the "keep screen on" setting; when it is off, `enable()` is a no-op.

- [ ] **Step 4: Add the resume entry point**

On `HomeScreen`, when `activeSessionProvider` yields a non-null session, pin a `MaterialBanner` above the list: `'${session.name} in progress'` with a `Resume` `FilledButton` pushing `/session` and a `Discard` `TextButton` (behind `confirmDestructive`). This is what makes "app killed mid-workout" recoverable in one tap.

- [ ] **Step 5: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: restore active sessions and rest timers across app restarts"
```

---

## Task 18: Notifications, haptics and sound

**Files:**
- Create: `lib/core/services/notification_service.dart`, `lib/core/services/haptics_service.dart`, `lib/core/services/sound_service.dart`
- Modify: `lib/main.dart`, `lib/features/sessions/providers/active_session_controller.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`, `ios/Runner/AppDelegate.swift`

**Interfaces:**
- Produces:
  - `NotificationService` with `Future<void> init()`, `Future<bool> requestPermission()`, `Future<void> scheduleRestComplete({required DateTime at, required String nextLabel})`, `Future<void> cancelRestComplete()`, `Future<bool> hasPermission()`. Provider: `notificationServiceProvider`.
  - `HapticsService` with `Future<void> setCompleted()` (medium impact), `Future<void> restFinished()` (heavy impact), honouring the settings toggle.
  - `SoundService` with `Future<void> restComplete()` using `SystemSound.play(SystemSoundType.alert)` — no audio asset, no extra package.

- [ ] **Step 1: Implement `NotificationService`**

Schedule the notification **when rest starts**, for the moment rest is due, rather than firing it from a timer — a scheduled notification survives the process being killed, which a Dart timer does not. Cancel it on skip, cancel, pause, or a new set completion.

```dart
  Future<void> scheduleRestComplete({
    required DateTime at,
    required String nextLabel,
  }) async {
    await cancelRestComplete();
    await _plugin.zonedSchedule(
      _restNotificationId,
      'Rest complete',
      'Next: $nextLabel',
      tz.TZDateTime.from(at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_timer',
          'Rest timer',
          channelDescription: 'Fires when a rest period ends',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
```

`flutter_local_notifications` needs `timezone` initialisation — call `tz.initializeTimeZones()` in `init()`. `timezone` arrives as a transitive dependency of `flutter_local_notifications`, so this does not add a package.

- [ ] **Step 2: Request permission at the right moment**

Do not ask on first launch. Ask the first time a session starts, with a one-line rationale sheet ("So GymFlow can tell you when your rest is up while you're on another app") and a "Not now" option (PRD FR-119). Store the "asked once" flag in `shared_preferences` so it is never asked twice.

- [ ] **Step 3: Add the Android manifest entries**

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

No foreground service and no exact-alarm permission — MVP deliberately stays out of that (PRD §10.5).

- [ ] **Step 4: Wire the side effects**

In the controller: `completeSet` fires `haptics.setCompleted()` and schedules the notification when rest starts. `_onRestFinished()` fires `haptics.restFinished()` and `sound.restComplete()`, then cancels any pending notification (it already fired, or the user was in-app the whole time — `cancelRestComplete` is harmless either way).

- [ ] **Step 5: Verify manually on the simulator, then commit**

Automated coverage for platform channels is not worth the mocking cost here — verify by hand that completing a set buzzes, that backgrounding during rest produces a banner, and that skipping rest cancels the pending notification.

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: notify, vibrate and chime when a rest period ends"
```

---

## Task 19: Finish flow and session summary

**Files:**
- Create: `lib/features/sessions/ui/session_summary_screen.dart`
- Modify: `lib/features/sessions/ui/active_session_screen.dart`, `lib/app/router.dart`
- Test: `test/widget/session_summary_test.dart`, extend `test/sessions/active_session_controller_test.dart`

**Interfaces:**
- Produces: `SessionSummaryScreen({required String sessionId, bool readOnly = false})` — reused verbatim as the history detail screen in Task 20. Route `/session/summary/:id`.

- [ ] **Step 1: Write the failing tests**

```dart
  test('finishing with incomplete sets is allowed but reported', () async {
    await seedAndStart(sets: 3);
    final controller = container.read(activeSessionControllerProvider.notifier);
    await controller.completeSet((await state()).session.exercises.first.sets.first.id);

    final before = await state();
    expect(before.session.completedSets, 1);
    expect(before.session.totalSets, 6);

    await controller.finish(notes: 'Cut it short');

    final saved = (await container.read(sessionRepositoryProvider)
        .watchSession(before.session.session.id).first)!;
    expect(saved.session.status, SessionStatus.completed);
    expect(saved.session.notes, 'Cut it short');
    expect(saved.completedSets, 1);
    expect(saved.session.endedAt, isNotNull);
  });

  test('cancelling marks the session cancelled and keeps it out of history',
      () async {
    await seedAndStart();
    final id = (await state()).session.session.id;
    await container.read(activeSessionControllerProvider.notifier).cancelSession();

    final row = (await container.read(sessionRepositoryProvider)
        .watchSession(id).first)!;
    expect(row.session.status, SessionStatus.cancelled);
    expect(await container.read(sessionRepositoryProvider)
        .watchCompletedSessions().first, isEmpty);
  });
```

```dart
// test/widget/session_summary_test.dart
testWidgets('summary reports duration, sets, exercises and volume',
    (tester) async {
  // session with two completed sets at 80kg x 8 and 80kg x 6
  expect(find.text('2 / 6 sets'), findsOneWidget);
  expect(find.textContaining('1120 kg'), findsOneWidget); // 80*8 + 80*6
});
```

- [ ] **Step 2: Run and confirm failure**

Expected: FAIL — `SessionSummaryScreen` is not defined.

- [ ] **Step 3: Implement the finish flow**

From the app bar overflow, "Finish":
- If `completedSets == totalSets`, push the summary directly.
- Otherwise show a dialog: `'${totalSets - completedSets} sets are still incomplete.'` with three actions — **Finish anyway** (push the summary), **Continue workout** (dismiss), **Discard session** (behind `confirmDestructive`, calls `cancelSession()` and pops Home) (PRD FR-116).

The summary screen is where the session actually gets committed: it shows the numbers, takes notes, and has **Save** (calls `finish(notes:)`, pops to Home with a confirmation snackbar) and **Discard** (`cancelSession()`, behind confirmation). Until Save is tapped the session stays `active`, so backing out of the summary returns to a live workout rather than losing it.

- [ ] **Step 4: Implement the summary screen**

- Header: workout name, `DateFormat.yMMMEd().add_jm()` of `startedAt`.
- A 2x2 stat grid: total duration (`elapsed`), `'$completedSets / $totalSets sets'`, `'$completedExercises / $totalExercises exercises'`, and volume `'${completedVolume.round()} $weightUnit'` (hidden when volume is 0, e.g. a stretch-only session).
- A per-exercise breakdown: exercise name, then one line per completed set — `'Set 1 · 80 kg × 8 · RIR 2'` for strength, `'Set 1 · 45s'` for duration. Incomplete sets show a muted `'—'`.
- Notes `TextField` (disabled when `readOnly`).
- Bottom: `Save` / `Discard` when live; nothing when `readOnly`.

- [ ] **Step 5: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add finish flow and session summary screen"
```

---

## Task 20: History

**Files:**
- Create: `lib/features/history/providers/history_providers.dart`, `lib/features/history/ui/history_screen.dart`
- Modify: `lib/app/router.dart`
- Test: `test/widget/history_test.dart`

**Interfaces:**
- Consumes: `SessionRepository.watchCompletedSessions()`, `SessionSummaryScreen(readOnly: true)`.
- Produces: `historyProvider` (`StreamProvider<List<ActiveSession>>`, newest first), `HistoryScreen`. Route `/history`. There is no separate detail screen — history detail is `SessionSummaryScreen(sessionId: ..., readOnly: true)` at `/session/summary/:id`.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('history lists completed sessions newest first and skips cancelled',
    (tester) async {
  // one completed session (Push, yesterday), one completed (Pull, today),
  // one cancelled
  expect(find.text('Pull'), findsOneWidget);
  expect(find.text('Push'), findsOneWidget);
  expect(find.text('Discarded'), findsNothing);

  final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
  expect((tiles.first.title! as Text).data, 'Pull');
});

testWidgets('empty history shows its call to action', (tester) async {
  expect(find.text('No completed sessions yet'), findsOneWidget);
});
```

- [ ] **Step 2: Run and confirm failure**

Expected: FAIL — `HistoryScreen` is not defined.

- [ ] **Step 3: Implement**

- `watchCompletedSessions()` filters `status = completed`, orders by `startedAt DESC`, and builds full `ActiveSession` aggregates so the list can show real counts.
- Each `ListTile`: title = workout name; subtitle = `'${DateFormat.yMMMd().format(startedAt)} · ${mmss(duration)} · $completedSets/$totalSets sets'`, plus `' · ${volume.round()} kg'` when volume > 0.
- Tap → `/session/summary/${id}` in read-only mode.
- Overflow per row: "Duplicate this workout as a template" (only when `templateId` is non-null and that template still exists) → calls `duplicateTemplate` and navigates to the editor.
- `EmptyState` with the message "No completed sessions yet" and an action returning to Home.

- [ ] **Step 4: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add session history with read-only detail"
```

---

## Task 21: Settings, JSON export and import

**Files:**
- Create: `lib/features/settings/data/settings_repository.dart`, `lib/features/settings/providers/settings_providers.dart`, `lib/features/settings/ui/settings_screen.dart`
- Create: `lib/core/services/backup_service.dart`
- Modify: `lib/app/router.dart`, `lib/main.dart`
- Test: `test/services/backup_service_test.dart`

**Interfaces:**
- Produces:
  - `AppSettings` — `final String weightUnit; final int defaultRestSeconds; final bool soundEnabled; final bool hapticsEnabled; final bool keepScreenOn;` with `const AppSettings.defaults()` = `('kg', 90, true, true, true)`.
  - `SettingsRepository` over `shared_preferences` with `Future<AppSettings> load()` and `Future<void> save(AppSettings)`.
  - `settingsProvider` — `NotifierProvider<SettingsNotifier, AppSettings>` (hydrated in `main()` before `runApp`, so it is synchronous everywhere else).
  - `BackupService` with `Future<String> exportJson()` (returns the JSON string), `Future<File> exportToFile()`, `Future<void> importJson(String json)` (replace-all), and `static const backupVersion = 1`.
- Route `/settings`.

- [ ] **Step 1: Write the failing round-trip test**

```dart
// test/services/backup_service_test.dart
test('export then import into a fresh database reproduces everything',
    () async {
  // Seed db A: 2 exercises, 1 template with 2 template exercises, 1 completed
  // session with 3 sets carrying weight/reps/rir values.
  final json = await BackupService(dbA).exportJson();

  final dbB = testDatabase();
  await BackupService(dbB).importJson(json);

  expect(await dbB.select(dbB.exercises).get(), hasLength(2));
  expect(await dbB.select(dbB.templateExercises).get(), hasLength(2));

  final sets = await dbB.select(dbB.sessionSets).get();
  expect(sets, hasLength(3));
  expect(sets.firstWhere((s) => s.setIndex == 0).weight, 80.0);
  expect(sets.firstWhere((s) => s.setIndex == 0).rir, 2.0);
  expect(sets.firstWhere((s) => s.setIndex == 0).completedAt, isNotNull);
});

test('import replaces existing data rather than merging', () async {
  await ExerciseRepository(dbB).create(
      name: 'Stale', loggingType: LoggingType.strengthWeightRepsRir);
  await BackupService(dbB).importJson(json);

  final names = (await dbB.select(dbB.exercises).get()).map((e) => e.name);
  expect(names, isNot(contains('Stale')));
});

test('a payload with the wrong version is rejected before anything is deleted',
    () async {
  await ExerciseRepository(dbB).create(
      name: 'Keep me', loggingType: LoggingType.durationOnly);

  expect(
    () => BackupService(dbB).importJson('{"version": 99, "exercises": []}'),
    throwsA(isA<FormatException>()),
  );
  expect(await dbB.select(dbB.exercises).get(), hasLength(1));
});

test('ids and timestamps round-trip exactly', () async {
  // assert a known exercise id and createdAt survive the round trip
});
```

- [ ] **Step 2: Run and confirm failure**

Expected: FAIL — `BackupService` is not defined.

- [ ] **Step 3: Implement `BackupService`**

Payload shape:

```json
{
  "version": 1,
  "exportedAt": "2026-08-15T10:00:00.000Z",
  "exercises": [],
  "workoutTemplates": [],
  "templateExercises": [],
  "workoutSessions": [],
  "sessionExercises": [],
  "sessionSets": []
}
```

Rules:
- Timestamps serialise as ISO-8601 UTC strings; enums as their `name`.
- `importJson` validates `version == backupVersion` **first** and throws `FormatException` before touching the database, so a bad file cannot destroy data.
- The import runs inside one `transaction`: delete all six tables in FK-safe order (sets → session exercises → sessions → template exercises → templates → exercises), then batch-insert in the reverse order. Either the whole import lands or none of it does.
- Image files are **not** included in the payload; `imagePath` values are exported as-is and an import on a different device simply shows the placeholder. Note this in the export confirmation copy.

- [ ] **Step 4: Implement the settings screen**

Per PRD §9.9, in this order:
- Default weight unit — `SegmentedButton` kg / lb. Changing it affects only sessions started afterwards; existing sessions keep their snapshot. Say so in the subtitle.
- Default rest seconds for new template exercises — `NumericField(min: 0, max: 3600)`.
- Sound on rest complete — switch.
- Haptics — switch.
- Keep screen on during a session — switch.
- Notification permission — a `ListTile` showing Granted / Not granted with a button that requests it or opens app settings.
- Export data — writes the file to a temp path and hands it to `Share.shareXFiles`.
- Import data — `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'])`, then a `confirmDestructive` dialog spelling out **"This replaces all workouts, exercises and history on this device."**, then import, then a success snackbar and a full provider invalidation.
- About — app name, version from `PackageInfo`-free hardcoded constant, and a line that all data is stored on-device.

- [ ] **Step 5: Wire settings into the app**

`AppSettings.weightUnit` feeds `startFromTemplate`; `defaultRestSeconds` feeds `addExercise` in the template editor; `soundEnabled` / `hapticsEnabled` gate their services; `keepScreenOn` gates `WakelockService`.

- [ ] **Step 6: Run tests and commit**

```bash
flutter test && flutter analyze
git add -A
git commit -m "feat: add settings screen with JSON export and import"
```

---

## Task 22: Polish pass and Android release readiness

**Files:**
- Modify: theme, empty states, and any screen flagged during the review below
- Modify: `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
- Create: `docs/MANUAL_TEST_PLAN.md`

**Interfaces:** No new public API. This task closes out PRD §16, §22 and §11 (Phase 11).

- [ ] **Step 1: Walk the UX rules and fix what fails**

Go through PRD §24 one rule at a time on the simulator, and fix anything that violates it:
1. Rest is adjustable without leaving the session screen.
2. Completing a set is one tap from the current row.
3. The next exercise is visible while resting.
4. No input is smaller than 48dp in its tappable dimension.
5. Set completion is never blocked on missing values.
6. Session reordering leaves the template untouched.
7. Killing the app mid-session loses nothing.
8. No modal is ever stacked on top of the rest sheet.
9. Every destructive action has undo or confirmation.
10. All primary session controls sit in the bottom half of the screen.

- [ ] **Step 2: Sweep the empty states**

Confirm each has an icon, a title, a sentence of explanation and a CTA: no workouts, no exercises, no search results, no history, a template with no exercises, an exercise with no image.

- [ ] **Step 3: Handle the long/odd content cases**

- A 60-character exercise name must ellipsise without pushing the info icon off-screen (PRD §18.10). Add a widget test at 320dp width.
- Duplicate exercise names are allowed; the picker shows the category as a subtitle to disambiguate (PRD §18.9).
- A template referencing an archived exercise shows the `Archived` chip and an "Replace exercise" action in its settings sheet (PRD §18.2).

- [ ] **Step 4: Verify the whole suite and the acceptance criteria**

```bash
flutter test
flutter analyze
```

Then walk PRD §19 end to end on the simulator and tick each Given/When/Then. Record the results in `docs/MANUAL_TEST_PLAN.md` — that file is the artefact of this step, with a line per criterion and its pass/fail.

- [ ] **Step 5: Set up the Android build**

This is the step blocked on tooling. First:

```bash
# Requires Android Studio (or the command-line tools) to be installed.
flutter config --android-sdk /path/to/Android/sdk
flutter doctor --android-licenses
flutter doctor
```

Only once `flutter doctor` reports the Android toolchain green:

- Set `minSdk = 24`, `targetSdk = 35` in `android/app/build.gradle.kts`.
- Set `android:label="GymFlow"` in the manifest.
- Confirm the manifest has `POST_NOTIFICATIONS` and `VIBRATE` and nothing else — no internet permission, since the app is offline by design. Add `<uses-permission android:name="android.permission.INTERNET" tools:node="remove"/>` to strip the one Flutter injects for debug.

```bash
flutter build apk --release
flutter build apk --split-per-abi   # smaller sideload
```

- [ ] **Step 6: Manual device testing**

On a real Android phone, per PRD Phase 11:
- Install the APK and run a full workout.
- Force-stop the app mid-rest; reopen and confirm the countdown is correct.
- Background the app during rest and confirm the notification fires.
- Run a 45-minute session and confirm the elapsed timer and wakelock behave.
- Reorder mid-session and confirm auto-advance follows the new order.
- Export, wipe app data, reinstall, import, and confirm everything returns.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: polish pass, manual test plan and Android release config"
```

---

## Self-Review

**Spec coverage.** Every numbered PRD requirement maps to a task:

| PRD | Task |
|---|---|
| FR-100 Template management | 6, 7, 8 |
| FR-101 Template exercise config | 6, 8 |
| FR-102 Exercise library | 3, 4 |
| FR-103 Exercise image | 5 |
| FR-104 Starting a session | 9, 13 |
| FR-105 Session exercise display | 13 |
| FR-106 Set completion | 12, 13 |
| FR-107 Rest timer behaviour | 11, 12, 14 |
| FR-108/109 Auto-focus | 15 |
| FR-110 Manual focus | 12, 15 |
| FR-111 Session reordering | 10, 16 |
| FR-112 Add/remove sets | 12, 13 |
| FR-113 Rest editing mid-session | 12, 13 |
| FR-114 Info sheet | 4 (built), 8/13 (reused) |
| FR-115 Pause/resume | 12, 15 |
| FR-116 Finish | 19 |
| FR-117 History | 20 |
| FR-118 Offline persistence | 2, 9, 17 |
| FR-119 Notifications | 18 |
| FR-120 Export/import | 21 |
| §9 Screens | 4, 7, 8, 13, 14, 15, 19, 20, 21 |
| §10 Timer spec | 11, 12, 15, 17 |
| §11 Reordering spec | 10, 16 |
| §16 UI/UX principles | 1, 22 |
| §18 Edge cases | 10, 11, 12, 17, 22 |
| §19 Acceptance criteria | 22 Step 4 |
| §20 Sync | Out of MVP scope by constraint; schema is sync-ready (Task 2) |

**Deliberate deviations from the PRD, flagged for approval:**
1. **`deletedAt` columns ship in v1** even though nothing soft-deletes yet. One column per table now avoids a migration when sync arrives (PRD §20.2).
2. **Rest-timer state lives on the `workout_session` row** rather than in a separate table. There is only ever one active rest, so a table would be overhead.
3. **Drift row classes are the domain models.** No `freezed`, no hand-written mirrors. Keeps the package count down per PRD §13.
4. **History detail reuses `SessionSummaryScreen(readOnly: true)`** instead of a separate screen — PRD §9.7 explicitly allows this.
5. **`file_picker` was added** to the stack; the PRD lists `share_plus`/`file_saver` for export but names nothing for *reading* an import file. Export uses `share_plus`; import needs a picker.

**Type consistency:** `SessionTarget`, `RestTimerState`, `ActiveSession`, `SessionExerciseWithSets` and every controller method name are declared once in a task's Interfaces block and referenced identically thereafter. `restSecondsAfter`, `nextTargetAfter`, `firstPendingTarget`, `moveToEnd`, `reorderPending` and `pendingExercises` are the complete engine surface; nothing outside `session_engine.dart` reimplements them.
