import 'package:cashlenx/core/infrastructure/http/request_tracking_interceptor.dart';
import 'package:cashlenx/core/infrastructure/logging/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds a request id header and logs request start', () {
    final logger = _MemoryLogger();
    final interceptor = RequestTrackingInterceptor(
      logger,
      requestIdFactory: () => 'request-1',
    );
    final options = RequestOptions(path: '/items', method: 'GET');

    interceptor.onRequest(options, _NoopRequestHandler());

    expect(options.headers['x-request-id'], 'request-1');
    expect(options.extra['_request_id'], 'request-1');
    expect(logger.debugMessages.single, contains('GET /items started'));
  });
}

class _MemoryLogger implements AppLogger {
  final debugMessages = <String>[];

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    debugMessages.add(message);
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {}
}

class _NoopRequestHandler extends RequestInterceptorHandler {
  @override
  void next(RequestOptions requestOptions) {}
}
