import 'package:cashlenx/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedUrl = String.fromEnvironment(
    'EXPECTED_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:10063/api/v1',
  );
  const expectedEnvironment = String.fromEnvironment(
    'EXPECTED_APP_ENV',
    defaultValue: 'dev',
  );

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in TargetPlatform.values) {
    test('preserves the configured API address on ${platform.name}', () async {
      debugDefaultTargetPlatformOverride = platform;
      await AppConfig.init();

      expect(AppConfig.environment.name, expectedEnvironment);
      expect(AppConfig.apiBaseUrl, expectedUrl);
      expect(AppConfig.logger, isNotNull);
    });
  }
}
