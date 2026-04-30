import 'package:cashlenx/core/infrastructure/errors/api_exception.dart';
import 'package:cashlenx/core/infrastructure/http/dio_exception_mapper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = DioExceptionMapper();

  DioException badResponse(int statusCode, Map<String, dynamic> data) {
    final requestOptions = RequestOptions(path: '/test');
    return DioException(
      requestOptions: requestOptions,
      response: Response(
        requestOptions: requestOptions,
        statusCode: statusCode,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );
  }

  test('maps unauthorized responses', () {
    final exception = mapper.map(
      badResponse(401, {'message': 'Unauthorized'}),
    );

    expect(exception, isA<UnauthorizedException>());
    expect(exception.message, 'Unauthorized');
  });

  test('maps validation responses', () {
    final exception = mapper.map(
      badResponse(422, {'message': 'Invalid email'}),
    );

    expect(exception, isA<ValidationException>());
    expect(exception.message, 'Invalid email');
  });

  test('maps timeout responses to network exceptions', () {
    final exception = mapper.map(
      DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    expect(exception, isA<NetworkException>());
  });
}
