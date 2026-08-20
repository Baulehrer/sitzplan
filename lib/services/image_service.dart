import 'dart:async';
import 'dart:io';
import 'dart:convert';
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
        Platform.isWindows ||
        Platform.isMacOS;
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
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return await _captureFromWebcam();
    }

    return null;
  }

  Future<String?> _captureFromWebcam() async {
    final dir = await _photoDir;
    final tempPath = p.join(dir, '_webcam_temp.jpg');
    final ffmpeg = await _ffmpegExecutable();

    try {
      late final List<String> arguments;
      if (Platform.isLinux) {
        final device = await _firstLinuxCamera();
        arguments = [
          '-y',
          '-f',
          'v4l2',
          '-i',
          device,
          '-frames:v',
          '1',
          '-q:v',
          '2',
          tempPath,
        ];
      } else if (Platform.isWindows) {
        final device = await _firstWindowsCamera(ffmpeg);
        arguments = [
          '-y',
          '-f',
          'dshow',
          '-i',
          'video=$device',
          '-frames:v',
          '1',
          '-q:v',
          '2',
          tempPath,
        ];
      } else {
        final deviceIndex = await _firstMacCamera(ffmpeg);
        arguments = [
          '-y',
          '-f',
          'avfoundation',
          '-framerate',
          '30',
          '-i',
          '$deviceIndex:none',
          '-frames:v',
          '1',
          '-q:v',
          '2',
          tempPath,
        ];
      }

      final result = await _runFfmpeg(ffmpeg, arguments);
      if (result.exitCode != 0) {
        debugPrint('Webcam capture failed: ${result.stderr}');
        throw CameraCaptureException(
          'Die Kamera konnte kein Foto aufnehmen. Prüfe die Kameraberechtigung und ob eine andere Anwendung die Kamera verwendet.',
        );
      }

      final file = File(tempPath);
      if (!await file.exists()) return null;

      final saved = await _saveAndCompress(file);
      // Clean up temp file
      await file.delete();
      return saved;
    } on CameraCaptureException {
      rethrow;
    } catch (e) {
      debugPrint('Webcam error: $e');
      throw CameraCaptureException('Kameraaufnahme fehlgeschlagen: $e');
    } finally {
      final temp = File(tempPath);
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<String> _ffmpegExecutable() async {
    final executableName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final bundled = File(
      p.join(p.dirname(Platform.resolvedExecutable), executableName),
    );
    if (await bundled.exists()) return bundled.path;

    try {
      final result = await Process.run(executableName, ['-version']);
      if (result.exitCode == 0) return executableName;
    } catch (_) {
      // A bundled executable is expected in release packages. Development
      // builds may fall back to a system installation.
    }
    throw const CameraCaptureException(
      'Das mitgelieferte Kameramodul wurde nicht gefunden. Installiere die App erneut.',
    );
  }

  Future<String> _firstLinuxCamera() async {
    final devices = await Directory('/dev')
        .list()
        .where((entry) => p.basename(entry.path).startsWith('video'))
        .map((entry) => entry.path)
        .toList();
    devices.sort();
    if (devices.isEmpty) {
      throw const CameraCaptureException('Keine Kamera wurde erkannt.');
    }
    return devices.first;
  }

  Future<String> _firstWindowsCamera(String ffmpeg) async {
    final result = await _runFfmpeg(ffmpeg, const [
      '-hide_banner',
      '-list_devices',
      'true',
      '-f',
      'dshow',
      '-i',
      'dummy',
    ]);
    var match = RegExp(
      r'"([^"]+)"\s+\(video\)',
      caseSensitive: false,
    ).firstMatch(result.stderr);
    if (match == null) {
      final videoSection = result.stderr
          .split('DirectShow audio devices')
          .first;
      match = RegExp(r'"([^"@][^"]*)"').firstMatch(videoSection);
    }
    if (match == null) {
      throw const CameraCaptureException(
        'Keine Windows-Kamera wurde erkannt. Prüfe die Kamera-Berechtigung in den Windows-Einstellungen.',
      );
    }
    return match.group(1)!;
  }

  Future<String> _firstMacCamera(String ffmpeg) async {
    final result = await _runFfmpeg(ffmpeg, const [
      '-hide_banner',
      '-f',
      'avfoundation',
      '-list_devices',
      'true',
      '-i',
      '',
    ]);
    final videoSection = result.stderr
        .split('AVFoundation audio devices')
        .first;
    final matches = RegExp(r'\[(\d+)\]\s+.+').allMatches(videoSection);
    if (matches.isEmpty) {
      throw const CameraCaptureException(
        'Keine macOS-Kamera wurde erkannt. Erlaube den Kamerazugriff in den Systemeinstellungen.',
      );
    }
    return matches.first.group(1)!;
  }

  Future<_ProcessOutput> _runFfmpeg(
    String executable,
    List<String> arguments,
  ) async {
    final process = await Process.start(executable, arguments);
    final stdoutFuture = utf8.decoder.bind(process.stdout).join();
    final stderrFuture = utf8.decoder.bind(process.stderr).join();
    late final int exitCode;
    try {
      exitCode = await process.exitCode.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      process.kill();
      throw const CameraCaptureException(
        'Die Kamera hat nicht rechtzeitig geantwortet.',
      );
    }
    return _ProcessOutput(exitCode, await stdoutFuture, await stderrFuture);
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

  Future<List<String>> pickMultipleFromGallery() async {
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      const typeGroup = XTypeGroup(
        label: 'Bilder',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);
      final saved = <String>[];
      for (final file in files) {
        saved.add(await _saveAndCompress(File(file.path)));
      }
      return saved;
    }

    final picked = await _picker.pickMultiImage(
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 80,
    );
    final saved = <String>[];
    for (final image in picked) {
      saved.add(await _saveAndCompress(File(image.path)));
    }
    return saved;
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

class CameraCaptureException implements Exception {
  final String message;

  const CameraCaptureException(this.message);

  @override
  String toString() => message;
}

class _ProcessOutput {
  final int exitCode;
  final String stdout;
  final String stderr;

  const _ProcessOutput(this.exitCode, this.stdout, this.stderr);
}
