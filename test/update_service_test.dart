import 'package:flutter_test/flutter_test.dart';
import 'package:opentune/core/utils/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService', () {
    test('normalizes version strings with v prefix and build numbers', () {
      expect(UpdateService.normalizeVersion('v0.7.1'), '0.7.1');
      expect(UpdateService.normalizeVersion('V1.2.0+4'), '1.2.0');
      expect(UpdateService.normalizeVersion(' 0.8.0 '), '0.8.0');
    });

    test('compares semantic versions accurately', () {
      expect(UpdateService.isNewerVersion('0.7.1', 'v0.7.2'), isTrue);
      expect(UpdateService.isNewerVersion('0.7.1', 'v0.8.0'), isTrue);
      expect(UpdateService.isNewerVersion('0.7.1', 'v1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('0.7.1', 'v0.7.1'), isFalse);
      expect(UpdateService.isNewerVersion('0.7.1', 'v0.7.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.7.1', 'v0.6.9'), isFalse);
    });

    test('reads current version from bundled pubspec.yaml', () async {
      final version = await UpdateService.getCurrentVersion();
      expect(version, isNotEmpty);
      expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version), isTrue);
    });
  });
}
