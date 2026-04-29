import 'key_value_store.dart';

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values;

  MemoryKeyValueStore([Map<String, String>? initialValues])
      : _values = Map.of(initialValues ?? const {});

  @override
  Future<void> clear() async {
    _values.clear();
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
