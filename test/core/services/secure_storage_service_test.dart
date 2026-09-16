import 'package:cashlenx/core/infrastructure/persistence/memory_key_value_store.dart';
import 'package:cashlenx/core/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saves a complete session', () async {
    final service = SecureStorageService(MemoryKeyValueStore());

    await service.saveSession(accessToken: 'access', refreshToken: 'refresh');

    expect(await service.getToken(), 'access');
    expect(await service.getRefreshToken(), 'refresh');
  });

  test('rejects an incomplete session and clears old tokens', () async {
    final service = SecureStorageService(MemoryKeyValueStore());
    await service.saveSession(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
    );

    await expectLater(
      service.saveSession(accessToken: 'new-access', refreshToken: ''),
      throwsArgumentError,
    );

    expect(await service.getToken(), isNull);
    expect(await service.getRefreshToken(), isNull);
  });

  test('clears session tokens without clearing remember me', () async {
    final service = SecureStorageService(MemoryKeyValueStore());

    await service.saveToken('access');
    await service.saveRefreshToken('refresh');
    await service.saveRememberMe(true);

    await service.clearSession();

    expect(await service.getToken(), isNull);
    expect(await service.getRefreshToken(), isNull);
    expect(await service.getRememberMe(), isTrue);
  });
}
