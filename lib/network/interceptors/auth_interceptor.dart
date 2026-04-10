import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _ref.read(secureStorageServiceProvider).getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final data = response?.data;
    final code = data is Map ? data['code'] : null;

    if (err.response?.statusCode == 401 || code == 'UNAUTHORIZED') {
      // If we get an unauthorized error, we might want to trigger a refresh
      // But for the "Auto Login on start" logic, it's handled in AuthNotifier.
      
      // For now, if any request fails with 401, we just let it be.
      // In the future, we will implement silent refresh here.
    }
    super.onError(err, handler);
  }
}
