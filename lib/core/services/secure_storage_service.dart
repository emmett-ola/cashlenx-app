import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../infrastructure/persistence/key_value_store.dart';
import '../infrastructure/persistence/secure_key_value_store.dart';

part 'secure_storage_service.g.dart';

@Riverpod(keepAlive: true)
SecureStorageService secureStorageService(Ref ref) {
  return SecureStorageService();
}

class SecureStorageService {
  final KeyValueStore _store;

  SecureStorageService([
    KeyValueStore store = const SecureKeyValueStore(FlutterSecureStorage()),
  ]) : _store = store;

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _rememberMeKey = 'auth_remember_me';

  Future<void> saveToken(String token) async {
    await _store.write(_tokenKey, token);
  }

  Future<String?> getToken() async {
    return await _store.read(_tokenKey);
  }

  Future<void> deleteToken() async {
    await _store.delete(_tokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _store.write(_refreshTokenKey, token);
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      await clearSession();
      throw ArgumentError('Session tokens must not be empty.');
    }

    try {
      // Persist the rotating credential first. An interrupted write may leave
      // an older access token, but never a new access token paired with the
      // already-revoked refresh token.
      await _store.write(_refreshTokenKey, refreshToken);
      await _store.write(_tokenKey, accessToken);
    } catch (_) {
      await clearSession();
      rethrow;
    }
  }

  Future<String?> getRefreshToken() async {
    return await _store.read(_refreshTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _store.delete(_refreshTokenKey);
  }

  Future<void> clearSession() async {
    await _store.delete(_tokenKey);
    await _store.delete(_refreshTokenKey);
  }

  Future<void> saveRememberMe(bool rememberMe) async {
    await _store.write(_rememberMeKey, rememberMe.toString());
  }

  Future<bool> getRememberMe() async {
    final value = await _store.read(_rememberMeKey);
    return value == 'true';
  }

  Future<void> clearAll() async {
    await _store.clear();
  }
}
