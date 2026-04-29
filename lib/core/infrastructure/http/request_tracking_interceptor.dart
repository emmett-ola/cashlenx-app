import 'package:dio/dio.dart';

import '../logging/app_logger.dart';

class RequestTrackingInterceptor extends Interceptor {
  static const _startedAtKey = '_started_at';
  static const _requestIdKey = '_request_id';

  final AppLogger _logger;
  final String Function() _requestIdFactory;

  RequestTrackingInterceptor(
    this._logger, {
    String Function()? requestIdFactory,
  }) : _requestIdFactory = requestIdFactory ?? _defaultRequestId;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = _requestIdFactory();
    options.extra[_startedAtKey] = DateTime.now();
    options.extra[_requestIdKey] = requestId;
    options.headers['x-request-id'] = requestId;
    _logger.debug('${options.method} ${options.path} started [$requestId]');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final elapsed = _elapsed(response.requestOptions);
    final requestId = response.requestOptions.extra[_requestIdKey];
    _logger.info(
      '${response.requestOptions.method} ${response.requestOptions.path} '
      'completed ${response.statusCode} in ${elapsed.inMilliseconds}ms '
      '[$requestId]',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final elapsed = _elapsed(err.requestOptions);
    final requestId = err.requestOptions.extra[_requestIdKey];
    _logger.warning(
      '${err.requestOptions.method} ${err.requestOptions.path} failed '
      '${err.response?.statusCode ?? err.type.name} in '
      '${elapsed.inMilliseconds}ms [$requestId]',
      error: err,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }

  Duration _elapsed(RequestOptions options) {
    final startedAt = options.extra[_startedAtKey];
    if (startedAt is DateTime) {
      return DateTime.now().difference(startedAt);
    }
    return Duration.zero;
  }

  static String _defaultRequestId() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}
