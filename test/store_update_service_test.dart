import 'package:flutter_test/flutter_test.dart';
import 'package:sitzplan/services/update_service.dart';

void main() {
  test('Store builds refuse GitHub update checks and downloads', () async {
    expect(UpdateService.isStoreBuild, isTrue);
    final service = UpdateService();
    expect(await service.checkForUpdate(), isNull);
    await expectLater(
      service.download(
        UpdateRelease(
          version: '99.0.0',
          releaseUrl: Uri.parse('https://example.invalid'),
          assetName: 'installer.exe',
          assetUrl: Uri.parse('https://example.invalid/installer.exe'),
          sha256Digest: 'a' * 64,
        ),
      ),
      throwsA(isA<UpdateException>()),
    );
  }, skip: !UpdateService.isStoreBuild);
}
