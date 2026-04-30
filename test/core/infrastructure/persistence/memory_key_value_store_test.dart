import 'package:cashlenx/core/infrastructure/persistence/memory_key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores reads deletes and clears values', () async {
    final store = MemoryKeyValueStore();

    await store.write('token', 'abc');
    expect(await store.read('token'), 'abc');

    await store.delete('token');
    expect(await store.read('token'), isNull);

    await store.write('a', '1');
    await store.write('b', '2');
    await store.clear();

    expect(await store.read('a'), isNull);
    expect(await store.read('b'), isNull);
  });
}
