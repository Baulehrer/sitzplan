import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sitzplan/services/update_service.dart';

void main() {
  test(
    'Store builds refuse GitHub checks, downloads and installer starts',
    () async {
      expect(UpdateService.isStoreBuild, isTrue);
      final service = UpdateService();
      final release = UpdateRelease(
        version: '99.0.0',
        releaseUrl: Uri.parse('https://example.invalid'),
        assetName: 'installer.exe',
        assetUrl: Uri.parse('https://example.invalid/installer.exe'),
        sha256Digest: 'a' * 64,
      );
      expect(await service.checkForUpdate(), isNull);
      await expectLater(
        service.download(release),
        throwsA(isA<UpdateException>()),
      );
      expect(
        await service.install(release, File('nonexistent-installer.exe')),
        UpdateInstallResult.unsupported,
      );
    },
    skip: !UpdateService.isStoreBuild,
  );
}
