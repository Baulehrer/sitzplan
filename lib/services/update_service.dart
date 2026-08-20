import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

typedef UpdateProgress = void Function(int receivedBytes, int totalBytes);

enum UpdateInstallResult { started, requiresUserAction, unsupported }

class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.releaseUrl,
    required this.assetName,
    required this.assetUrl,
  });

  final String version;
  final Uri releaseUrl;
  final String assetName;
  final Uri assetUrl;
}

class UpdateService {
  UpdateService({HttpClient? client}) : _client = client ?? HttpClient();

  static const _latestReleaseUri =
      'https://api.github.com/repos/Baulehrer/sitzplan/releases/latest';
  static const _androidChannel = MethodChannel('de.kaufmann.sitzplan/updater');

  final HttpClient _client;

  Future<UpdateRelease?> checkForUpdate() async {
    if (kIsWeb || kDebugMode || Platform.isIOS) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final request = await _client
        .getUrl(Uri.parse(_latestReleaseUri))
        .timeout(const Duration(seconds: 10));
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, 'Sitzplan/${packageInfo.version}')
      ..set('X-GitHub-Api-Version', '2022-11-28');
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return null;
    }

    final body = await utf8.decoder.bind(response).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return releaseFromGitHubJson(json, packageInfo.version);
  }

  Future<File> download(
    UpdateRelease release, {
    UpdateProgress? onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final updateDirectory = Directory(
      p.join(directory.path, 'sitzplan-update-${release.version}'),
    );
    await updateDirectory.create(recursive: true);
    final target = File(p.join(updateDirectory.path, release.assetName));
    final partial = File('${target.path}.part');
    if (await partial.exists()) await partial.delete();

    final request = await _client
        .getUrl(release.assetUrl)
        .timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.userAgentHeader, 'Sitzplan-Updater');
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw const UpdateException('Das Update konnte nicht geladen werden.');
    }

    final sink = partial.openWrite();
    var received = 0;
    final total = response.contentLength;
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
    if (received == 0 || (total > 0 && received != total)) {
      if (await partial.exists()) await partial.delete();
      throw const UpdateException('Das Update wurde unvollständig geladen.');
    }
    if (await target.exists()) await target.delete();
    return partial.rename(target.path);
  }

  Future<UpdateInstallResult> install(
    UpdateRelease release,
    File package,
  ) async {
    if (Platform.isAndroid) {
      final started = await _androidChannel.invokeMethod<bool>('installApk', {
        'path': package.path,
      });
      return started == true
          ? UpdateInstallResult.started
          : UpdateInstallResult.requiresUserAction;
    }
    if (Platform.isWindows) {
      await Process.start(package.path, const [
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/CLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
      ], mode: ProcessStartMode.detached);
      return UpdateInstallResult.started;
    }
    if (Platform.isLinux) {
      return _installLinuxAppImage(package);
    }
    if (Platform.isMacOS) {
      final opened = await launchUrl(
        Uri.file(package.path),
        mode: LaunchMode.externalApplication,
      );
      return opened
          ? UpdateInstallResult.requiresUserAction
          : UpdateInstallResult.unsupported;
    }
    await launchUrl(release.releaseUrl, mode: LaunchMode.externalApplication);
    return UpdateInstallResult.unsupported;
  }

  Future<UpdateInstallResult> _installLinuxAppImage(File package) async {
    final currentPath = Platform.environment['APPIMAGE'];
    if (currentPath == null || currentPath.isEmpty) {
      return UpdateInstallResult.unsupported;
    }
    final current = File(currentPath);
    if (!await current.exists()) return UpdateInstallResult.unsupported;

    final candidate = File('$currentPath.update');
    final previous = File('$currentPath.previous');
    if (await candidate.exists()) await candidate.delete();
    await package.copy(candidate.path);
    final chmod = await Process.run('chmod', ['+x', candidate.path]);
    if (chmod.exitCode != 0) {
      await candidate.delete();
      throw const UpdateException(
        'Das Update konnte nicht vorbereitet werden.',
      );
    }

    if (await previous.exists()) await previous.delete();
    await current.rename(previous.path);
    try {
      await candidate.rename(current.path);
      await Process.start(
        current.path,
        const [],
        mode: ProcessStartMode.detached,
      );
      await previous.delete();
      Future<void>.delayed(const Duration(milliseconds: 300), () => exit(0));
    } catch (_) {
      if (await current.exists()) await current.delete();
      await previous.rename(current.path);
      rethrow;
    }
    return UpdateInstallResult.started;
  }

  @visibleForTesting
  static bool isNewerVersion(String candidate, String installed) {
    final candidateParts = _versionParts(candidate);
    final installedParts = _versionParts(installed);
    final count = candidateParts.length > installedParts.length
        ? candidateParts.length
        : installedParts.length;
    for (var index = 0; index < count; index++) {
      final left = index < candidateParts.length ? candidateParts[index] : 0;
      final right = index < installedParts.length ? installedParts[index] : 0;
      if (left != right) return left > right;
    }
    return false;
  }

  static List<int> _versionParts(String version) => version
      .split(RegExp(r'[.+-]'))
      .takeWhile((part) => int.tryParse(part) != null)
      .map(int.parse)
      .toList();

  @visibleForTesting
  static UpdateRelease? releaseFromGitHubJson(
    Map<String, dynamic> json,
    String installedVersion,
  ) {
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final tag = json['tag_name'] as String?;
    final version = tag?.replaceFirst(RegExp(r'^v'), '');
    if (version == null || !isNewerVersion(version, installedVersion)) {
      return null;
    }
    final assetName = assetNameForPlatform(version);
    if (assetName == null) return null;
    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    Map<String, dynamic>? asset;
    for (final entry in assets) {
      if (entry['name'] == assetName) {
        asset = entry;
        break;
      }
    }
    final assetUrl = asset?['browser_download_url'] as String?;
    final releaseUrl = json['html_url'] as String?;
    if (assetUrl == null || releaseUrl == null) return null;
    return UpdateRelease(
      version: version,
      releaseUrl: Uri.parse(releaseUrl),
      assetName: assetName,
      assetUrl: Uri.parse(assetUrl),
    );
  }

  @visibleForTesting
  static String? assetNameForPlatform(String version) {
    if (kIsWeb || Platform.isIOS) return null;
    if (Platform.isAndroid) return 'Sitzplan-$version-android.apk';
    if (Platform.isWindows) return 'Sitzplan-$version-Setup.exe';
    if (Platform.isLinux) return 'Sitzplan-$version-x86_64.AppImage';
    if (Platform.isMacOS) return 'Sitzplan-$version-macos.dmg';
    return null;
  }
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
