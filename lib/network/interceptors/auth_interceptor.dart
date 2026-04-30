import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/services/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final Ref _ref;
  bool _isRefreshing = false;

  AuthInterceptor(this._ref);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
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
    final statusCode = response?.statusCode;

    if ((statusCode == 401 || code == 'UNAUTHORIZED') &&
        err.requestOptions.extra['skipAuthRefresh'] != true) {
      final retryResponse = await _refreshAndRetry(err.requestOptions);
      if (retryResponse != null) {
        handler.resolve(retryResponse);
        return;
      }
    }

    super.onError(err, handler);
  }

  Future<Response<dynamic>?> _refreshAndRetry(
      RequestOptions requestOptions) async {
    if (_isRefreshing) return null;

    final storage = _ref.read(secureStorageServiceProvider);
    final rememberMe = await storage.getRememberMe();
    final refreshToken = await storage.getRefreshToken();
    if (!rememberMe || refreshToken == null || refreshToken.isEmpty) {
      await storage.clearSession();
      return null;
    }

    _isRefreshing = true;
    try {
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final refreshResponse = await refreshDio.post<Map<String, dynamic>>(
        '/open/auth/login',
        data: {'refresh_token': refreshToken},
      );
      final wrapper = refreshResponse.data;
      final authData = wrapper?['data'];
      if (authData is! Map<String, dynamic>) {
        await storage.clearSession();
        return null;
      }

      final accessToken = authData['access_token'];
      final newRefreshToken = authData['refresh_token'];
      if (accessToken is! String || newRefreshToken is! String) {
        await storage.clearSession();
        return null;
      }

      await storage.saveToken(accessToken);
      await storage.saveRefreshToken(newRefreshToken);

      final retryDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final headers = Map<String, dynamic>.from(requestOptions.headers);
      headers['Authorization'] = 'Bearer $accessToken';

      return retryDio.fetch<dynamic>(
        requestOptions.copyWith(
          headers: headers,
          extra: {
            ...requestOptions.extra,
            'skipAuthRefresh': true,
          },
        ),
      );
    } catch (_) {
      await storage.clearSession();
      return null;
    } finally {
      _isRefreshing = false;
    }
  }
}
