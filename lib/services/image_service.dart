import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  final _picker = ImagePicker();
  final _uuid = const Uuid();

  Future<String> get _photoDir async {
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = p.join(dir.path, 'sitzplan', 'photos');
    await Directory(photoDir).create(recursive: true);
    return photoDir;
  }

  /// Checks if a camera/webcam is available on this platform
  bool get isCameraAvailable {
    if (kIsWeb) return false;
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isLinux ||
        Platform.isWindows;
  }

  Future<String?> pickFromCamera() async {
    if (kIsWeb) return null;

    // Mobile: use image_picker
    if (Platform.isAndroid || Platform.isIOS) {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (picked == null) return null;
      return await _saveAndCompress(File(picked.path));
    }

    // Desktop: use ffmpeg to capture from webcam
    if (Platform.isLinux || Platform.isWindows) {
      return await _captureFromWebcam();
    }

    return null;
  }

  Future<String?> _captureFromWebcam() async {
    final dir = await _photoDir;
    final tempPath = p.join(dir, '_webcam_temp.jpg');

    try {
      ProcessResult result;
      if (Platform.isLinux) {
        // Use ffmpeg to capture a single frame from /dev/video0
        result = await Process.run('ffmpeg', [
          '-y',
          '-f',
          'v4l2',
          '-i',
          '/dev/video0',
          '-frames:v',
          '1',
          '-q:v',
          '2',
          tempPath,
        ]);
      } else {
        // Windows: use dshow
        result = await Process.run('ffmpeg', [
          '-y',
          '-f',
          'dshow',
          '-i',
          'video=Integrated Camera',
          '-frames:v',
          '1',
          '-q:v',
          '2',
          tempPath,
        ]);
      }

      if (result.exitCode != 0) {
        debugPrint('Webcam capture failed: ${result.stderr}');
        return null;
      }

      final file = File(tempPath);
      if (!await file.exists()) return null;

      final saved = await _saveAndCompress(file);
      // Clean up temp file
      await file.delete();
      return saved;
    } catch (e) {
      debugPrint('Webcam error: $e');
      return null;
    }
  }

  Future<String?> pickFromGallery() async {
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      return await _pickFromFileSelector();
    }
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 80,
    );
    if (picked == null) return null;
    return await _saveAndCompress(File(picked.path));
  }

  Future<String?> _pickFromFileSelector() async {
    const typeGroup = XTypeGroup(
      label: 'Bilder',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;
    final path = file.path;
    return await _saveAndCompress(File(path));
  }

  Future<String> _saveAndCompress(File source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Bild konnte nicht gelesen werden');

    // Resize to max 300x300 maintaining aspect ratio
    final resized = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? 300 : -1,
      height: decoded.height >= decoded.width ? 300 : -1,
    );

    final dir = await _photoDir;
    final filename = '${_uuid.v4()}.jpg';
    final outputPath = p.join(dir, filename);
    final jpg = img.encodeJpg(resized, quality: 85);
    await File(outputPath).writeAsBytes(jpg);

    return outputPath;
  }

  Future<void> deletePhoto(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
