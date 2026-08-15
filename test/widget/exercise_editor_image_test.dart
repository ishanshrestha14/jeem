import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/services/image_storage_service.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/exercises/ui/exercise_editor_screen.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../db/test_database.dart';
import 'pump_helpers.dart';

/// Fake picker path: bypasses `ImagePicker`'s platform channel (unavailable
/// in widget tests) while still exercising the real downscale-and-write
/// logic in `ImageStorageService.stageBytes`, so assertions below are
/// against real files on real (temp) directories rather than mocked state.
/// Picks land in the STAGING directory, matching the real
/// `pickAndStore` -> `stageBytes` contract — the editor only promotes them
/// into the managed directory via `commitStaged` on a successful save.
class _FakeImageStorageService extends ImageStorageService {
  _FakeImageStorageService(Directory managedDir, Directory stagingDir)
      : super(imagesDirOverride: managedDir, stagingDirOverride: stagingDir);

  final Queue<Uint8List> queued = Queue();

  @override
  Future<String?> pickAndStore({ImageSource source = ImageSource.gallery}) async {
    if (queued.isEmpty) return null;
    return stageBytes(queued.removeFirst(), extension: 'jpg');
  }
}

Uint8List _fakeJpegBytes() {
  final image = img.Image(width: 10, height: 10);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return img.encodeJpg(image);
}

void main() {
  late AppDatabase db;
  late Directory imagesDir;
  late Directory stagingDir;
  late _FakeImageStorageService service;

  setUp(() async {
    db = testDatabase();
    imagesDir = await Directory.systemTemp.createTemp('gymflow_editor_img');
    stagingDir = await Directory.systemTemp.createTemp('gymflow_editor_staging');
    service = _FakeImageStorageService(imagesDir, stagingDir);
  });

  tearDown(() async {
    await db.close();
    if (imagesDir.existsSync()) await imagesDir.delete(recursive: true);
    if (stagingDir.existsSync()) await stagingDir.delete(recursive: true);
  });

  // The form is taller than the default 800x600 test surface, so the
  // Photo/Save/Cancel controls sit below the fold and hit-test as offscreen.
  // Enlarge the surface instead of scrolling before every tap.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // `ImageStorageService.stageBytes`/`storeBytes`/`commitStaged`/
  // `deleteIfManaged` perform real dart:io file operations, and saving
  // round-trips through the (in-memory) sqlite3 isolate. Under
  // AutomatedTestWidgetsFlutterBinding's FakeAsync zone, that real work
  // completes at the OS/isolate level (visible to synchronous dart:io calls
  // like `listSync()`), but the Dart-level `await` continuation inside the
  // widget's callback (or in test setup code) never resumes — and the test
  // hangs forever during teardown waiting on it — unless the interaction
  // runs through `tester.runAsync`, which temporarily hands control to the
  // real event loop for long enough that the whole chain actually finishes.
  // Every tap that triggers real I/O (pick, save) must go through this
  // helper rather than a bare `tester.tap` + `pumpAndSettle`. Cancel/back
  // navigation triggers no I/O under the staging design, so those use plain
  // taps.
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  // Same real-dart:io-under-FakeAsync issue as `tapAndSettle`: any direct
  // `service.storeBytes` call in test setup (to seed a pre-existing managed
  // image) must also run through `runAsync`, or its continuation never
  // resumes.
  Future<String> storeSeedImage(WidgetTester tester) {
    late String path;
    return tester
        .runAsync(() async {
          path = await service.storeBytes(_fakeJpegBytes(), extension: 'jpg');
        })
        .then((_) => path);
  }

  // The editor is always pushed on top of another screen in the real app.
  // Give it a real destination to pop back to (mirroring the archive test).
  Widget harness({String? exerciseId}) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStorageServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Destination')),
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExerciseEditorScreen(exerciseId: exerciseId),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'pick then cancel: nothing lands in the managed directory, staged file untouched',
      (tester) async {
    useTallSurface(tester);
    service.queued.add(_fakeJpegBytes());

    await tester.pumpWidget(harness());
    await pumpUntilData(tester);
    await openEditor(tester);
    await pumpUntilData(tester);

    await tester.enterText(find.byType(TextField).first, 'Push-up');
    await tapAndSettle(tester, find.text('Choose photo'));

    // The pick landed in staging, never in the managed directory.
    expect(imagesDir.listSync(), isEmpty);
    expect(stagingDir.listSync(), hasLength(1));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Nothing was ever committed, so the managed directory stays untouched.
    // (The staged file is left for the OS to reclaim — see the report.)
    expect(imagesDir.listSync(), isEmpty);

    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'pick then back navigation (pageBack): nothing lands in the managed directory',
      (tester) async {
    useTallSurface(tester);
    service.queued.add(_fakeJpegBytes());

    await tester.pumpWidget(harness());
    await pumpUntilData(tester);
    await openEditor(tester);
    await pumpUntilData(tester);

    await tester.enterText(find.byType(TextField).first, 'Push-up');
    await tapAndSettle(tester, find.text('Choose photo'));

    expect(imagesDir.listSync(), isEmpty);

    // The AppBar back button / system back gesture, not the Cancel button —
    // this is the path that was never covered before.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Destination'), findsOneWidget);
    expect(imagesDir.listSync(), isEmpty);

    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'pick then save: imagePath points at a file inside the managed directory',
      (tester) async {
    useTallSurface(tester);
    service.queued.add(_fakeJpegBytes());

    await tester.pumpWidget(harness());
    await pumpUntilData(tester);
    await openEditor(tester);
    await pumpUntilData(tester);

    await tester.enterText(find.byType(TextField).first, 'Push-up');
    await tapAndSettle(tester, find.text('Choose photo'));
    await tapAndSettle(tester, find.text('Save'));

    // A plain one-shot select, not `repo.watchAll()`: a live Drift stream
    // query registers cleanup Timers whose zone gets confused by the
    // `tapAndSettle` -> `tester.runAsync` excursion above, which hangs the
    // test forever waiting on a Timer that never fires. See `tapAndSettle`
    // and this suite's report entry for the full story.
    final saved = (await db.select(db.exercises).get()).single;
    expect(saved.imagePath, isNotNull);
    expect(p.isWithin(imagesDir.path, saved.imagePath!), isTrue);
    expect(File(saved.imagePath!).existsSync(), isTrue);
    expect(imagesDir.listSync(), hasLength(1));

    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'replace then cancel: the original file survives and the db row is unchanged',
      (tester) async {
    useTallSurface(tester);
    final originalPath = await storeSeedImage(tester);
    final repo = ExerciseRepository(db);
    final exercise = await repo.create(
      name: 'Squat',
      loggingType: LoggingType.strengthWeightRepsRir,
      imagePath: originalPath,
    );

    service.queued.add(_fakeJpegBytes());

    await tester.pumpWidget(harness(exerciseId: exercise.id));
    await pumpUntilData(tester);
    await openEditor(tester);
    await pumpUntilData(tester);

    await tapAndSettle(tester, find.text('Choose photo'));

    // The replacement was staged, not committed — the managed directory
    // still holds only the original.
    expect(imagesDir.listSync(), hasLength(1));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(File(originalPath).existsSync(), isTrue);
    expect(imagesDir.listSync(), hasLength(1));
    final unchanged = await repo.findById(exercise.id);
    expect(unchanged!.imagePath, originalPath);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('replace then save: the original is deleted and the new one remains',
      (tester) async {
    useTallSurface(tester);
    final originalPath = await storeSeedImage(tester);
    final repo = ExerciseRepository(db);
    final exercise = await repo.create(
      name: 'Squat',
      loggingType: LoggingType.strengthWeightRepsRir,
      imagePath: originalPath,
    );

    service.queued.add(_fakeJpegBytes());

    await tester.pumpWidget(harness(exerciseId: exercise.id));
    await pumpUntilData(tester);
    await openEditor(tester);
    await pumpUntilData(tester);

    await tapAndSettle(tester, find.text('Choose photo'));
    await tapAndSettle(tester, find.text('Save'));

    expect(File(originalPath).existsSync(), isFalse);
    final updated = await repo.findById(exercise.id);
    expect(updated!.imagePath, isNotNull);
    expect(updated.imagePath, isNot(originalPath));
    expect(p.isWithin(imagesDir.path, updated.imagePath!), isTrue);
    expect(File(updated.imagePath!).existsSync(), isTrue);
    expect(imagesDir.listSync(), hasLength(1));

    await disposeAndDrainTimers(tester);
  });

  testWidgets('remove then save: the file is deleted and imagePath is null',
      (tester) async {
    useTallSurface(tester);
    final originalPath = await storeSeedImage(tester);
    final repo = ExerciseRepository(db);
    final exercise = await repo.create(
      name: 'Squat',
      loggingType: LoggingType.strengthWeightRepsRir,
      imagePath: originalPath,
    );

    await tester.pumpWidget(harness(exerciseId: exercise.id));
    await pumpUntilData(tester);
    await openEditor(tester);
    await pumpUntilData(tester);

    await tapAndSettle(tester, find.text('Remove photo'));
    await tapAndSettle(tester, find.text('Save'));

    expect(File(originalPath).existsSync(), isFalse);
    final updated = await repo.findById(exercise.id);
    expect(updated!.imagePath, isNull);
    expect(imagesDir.listSync(), isEmpty);

    await disposeAndDrainTimers(tester);
  });
}
