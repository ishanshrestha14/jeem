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
