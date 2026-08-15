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
