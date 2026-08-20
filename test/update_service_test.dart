import 'package:flutter_test/flutter_test.dart';
import 'package:sitzplan/services/update_service.dart';

void main() {
  group('UpdateService version comparison', () {
    test('detects newer semantic versions', () {
      expect(UpdateService.isNewerVersion('1.4.1', '1.4.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.5.0', '1.4.99'), isTrue);
      expect(UpdateService.isNewerVersion('2.0.0', '1.99.99'), isTrue);
    });

    test('does not downgrade or reinstall the same version', () {
      expect(UpdateService.isNewerVersion('1.4.0', '1.4.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.3.9', '1.4.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.4', '1.4.0'), isFalse);
    });

    test('accepts GitHub-style version suffixes', () {
      expect(UpdateService.isNewerVersion('1.4.1+8', '1.4.0+7'), isTrue);
      expect(UpdateService.isNewerVersion('1.4.0+8', '1.4.0+7'), isTrue);
    });
  });

  group('GitHub release parsing', () {
    test('selects the current platform asset from a stable release', () {
      final assetName = UpdateService.assetNameForPlatform('1.5.0');
      if (assetName == null) return;
      final release = UpdateService.releaseFromGitHubJson({
        'tag_name': 'v1.5.0',
        'html_url': 'https://github.com/Baulehrer/sitzplan/releases/v1.5.0',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': assetName,
            'browser_download_url': 'https://example.invalid/$assetName',
          },
        ],
      }, '1.4.0');

      expect(release, isNotNull);
      expect(release!.version, '1.5.0');
      expect(release.assetName, assetName);
    });

    test('ignores prereleases and releases without the required asset', () {
      expect(
        UpdateService.releaseFromGitHubJson({
          'tag_name': 'v2.0.0-beta',
          'html_url': 'https://example.invalid/release',
          'prerelease': true,
          'assets': const [],
        }, '1.4.0'),
        isNull,
      );
      expect(
        UpdateService.releaseFromGitHubJson({
          'tag_name': 'v1.5.0',
          'html_url': 'https://example.invalid/release',
          'assets': const [],
        }, '1.4.0'),
        isNull,
      );
    });
  });
}
