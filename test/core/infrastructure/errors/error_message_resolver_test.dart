import 'package:cashlenx/core/infrastructure/errors/api_exception.dart';
import 'package:cashlenx/core/infrastructure/errors/error_message_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ErrorMessageResolver();

  test('resolves server error list messages', () {
    final message = resolver.resolve(
      const ApiException(
        message: 'fallback',
        data: {
          'errors': [
            {'message': 'Email is required'},
            {'message': 'Password is too short'},
          ],
        },
      ),
    );

    expect(message, 'Email is required\nPassword is too short');
  });

  test('falls back to api exception message', () {
    final message = resolver.resolve(
      const ApiException(message: 'Network unavailable'),
    );

    expect(message, 'Network unavailable');
  });
}
