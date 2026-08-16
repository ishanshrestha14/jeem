import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/ids.dart';

class ImageStorageService {
  ImageStorageService({
    Directory? imagesDirOverride,
    Directory? stagingDirOverride,
    ImagePicker? picker,
  })  : _override = imagesDirOverride,
        _stagingOverride = stagingDirOverride,
        _picker = picker ?? ImagePicker();

  static const maxWidth = 1080;

  final Directory? _override;
  final Directory? _stagingOverride;
  final ImagePicker _picker;

  Future<Directory> _imagesDir() async {
    if (_override != null) return _override;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'exercise_images'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  // A picked-but-not-yet-committed image is written here, never into the
  // managed directory. This is what makes an abandoned pick (Cancel, back
  // gesture, app kill mid-edit) a non-issue instead of a leak to chase down:
  // nothing durable ever referenced the file, and it lives in OS temp space
  // the platform reclaims on its own schedule.
  Future<Directory> _stagingDir() async {
    if (_stagingOverride != null) return _stagingOverride;
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'exercise_images_staging'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Returns the staged absolute path, or null if the user cancelled. The
  /// returned path is **not** inside the managed images directory — pass it
  /// to [commitStaged] once (and only once) the edit that references it is
  /// actually persisted.
  Future<String?> pickAndStore({ImageSource source = ImageSource.gallery}) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return stageBytes(bytes, extension: p.extension(picked.path).replaceFirst('.', ''));
  }

  /// Downscales to [maxWidth] (preserving aspect ratio) and writes a JPEG into
  /// the app documents directory. Returns the absolute path.
  Future<String> storeBytes(Uint8List bytes, {required String extension}) =>
      _writeResized(bytes, _imagesDir());

  /// Downscales to [maxWidth] (preserving aspect ratio) and writes a JPEG into
  /// a temp staging directory, outside anything the database ever points at.
  /// Returns the absolute path.
  Future<String> stageBytes(Uint8List bytes, {required String extension}) =>
      _writeResized(bytes, _stagingDir());

  Future<String> _writeResized(Uint8List bytes, Future<Directory> dirFuture) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('Unsupported image format');

    final resized = decoded.width > maxWidth
        ? img.copyResize(decoded, width: maxWidth)
        : decoded;

    final dir = await dirFuture;
    final file = File(p.join(dir.path, '${newId()}.jpg'));
    await file.writeAsBytes(img.encodeJpg(resized, quality: 85));
    return file.path;
  }

  /// Moves a file written by [pickAndStore]/[stageBytes] into the managed
  /// images directory, returning its final absolute path. Call this only
  /// once the edit referencing it has actually been persisted — the returned
  /// path, not [stagedPath], is what belongs in the database.
  Future<String> commitStaged(String stagedPath) async {
    final dir = await _imagesDir();
    final destPath = p.join(dir.path, p.basename(stagedPath));
    final source = File(stagedPath);
    try {
      final moved = await source.rename(destPath);
      return moved.path;
    } on FileSystemException {
      // Staging and managed directories can live on different filesystems
      // (e.g. platform temp vs. app documents), which `rename` can't cross.
      // Fall back to copy-then-delete.
      final copied = await source.copy(destPath);
      await source.delete();
      return copied.path;
    }
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
