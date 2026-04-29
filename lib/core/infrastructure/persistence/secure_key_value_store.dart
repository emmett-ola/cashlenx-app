import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'key_value_store.dart';

class SecureKeyValueStore implements KeyValueStore {
  final FlutterSecureStorage _storage;

  const SecureKeyValueStore([
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  ]) : _storage = storage;

  @override
  Future<void> clear() => _storage.deleteAll();

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
