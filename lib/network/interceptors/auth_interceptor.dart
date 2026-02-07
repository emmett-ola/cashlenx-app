import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip if no-auth header is present (custom header to bypass auth)
    if (options.headers.containsKey('no-auth')) {
      options.headers.remove('no-auth');
      return super.onRequest(options, handler);
    }

    final token = await _ref.read(secureStorageServiceProvider).getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // TODO: Handle Token Refresh logic here if supported
      // For now, we can perhaps trigger a logout or refresh if API supports it.
      // Since refresh token logic is complex (queueing requests), we'll skip for Phase 2 MVP.
    }
    super.onError(err, handler);
  }
}
