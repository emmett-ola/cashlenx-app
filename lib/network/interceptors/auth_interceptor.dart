import 'dart:async';

import 'package:dio/dio.dart';
import '../../core/config/app_config.dart';
import '../../core/services/secure_storage_service.dart';

enum _RefreshOutcome { success, terminalFailure, transientFailure, superseded }

class _RefreshResult {
  final _RefreshOutcome outcome;
  final String? accessToken;

  const _RefreshResult(this.outcome, [this.accessToken]);
}

class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final Future<void> Function() _expireSession;
  final Dio Function() _dioFactory;
  Future<_RefreshResult>? _refreshFuture;

  AuthInterceptor({
    required SecureStorageService storage,
    required Future<void> Function() expireSession,
    Dio Function()? dioFactory,
  }) : _storage = storage,
       _expireSession = expireSession,
       _dioFactory = dioFactory ?? _createDio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isAnonymousRequest(options)) {
      super.onRequest(options, handler);
      return;
    }

    final token = await _storage.getToken();
    if (token != null && token.isNotEmpty) {
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
        !_isAnonymousRequest(err.requestOptions) &&
        err.requestOptions.extra['skipAuthRefresh'] != true) {
      final retryResponse = await _refreshAndRetry(err.requestOptions);
      if (retryResponse != null) {
        handler.resolve(retryResponse);
        return;
      }
    }

    super.onError(err, handler);
  }

  bool _isAnonymousRequest(RequestOptions options) {
    return options.extra['skipAuth'] == true ||
        options.path == '/open/auth/login' ||
        options.path == '/open/auth/register' ||
        options.path == '/open/auth/reset-password' ||
        options.path == '/open/auth/reset-password/confirm';
  }

  Future<Response<dynamic>?> _refreshAndRetry(
    RequestOptions requestOptions,
  ) async {
    final currentAccessToken = await _storage.getToken();
    final failedAccessToken = _bearerToken(
      requestOptions.headers['Authorization'],
    );
    if (currentAccessToken != null &&
        currentAccessToken.isNotEmpty &&
        failedAccessToken != null &&
        currentAccessToken != failedAccessToken) {
      return _retry(requestOptions, currentAccessToken);
    }

    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _expireSessionIfCurrent(null);
      return null;
    }

    final result = await _serializedRefresh(refreshToken);
    switch (result.outcome) {
      case _RefreshOutcome.success:
        return _retry(requestOptions, result.accessToken!);
      case _RefreshOutcome.terminalFailure:
        await _expireSessionIfCurrent(refreshToken);
        return null;
      case _RefreshOutcome.transientFailure:
      case _RefreshOutcome.superseded:
        return null;
    }
  }

  Future<Response<dynamic>> _retry(
    RequestOptions requestOptions,
    String accessToken,
  ) {
    final retryDio = _dioFactory();
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    headers['Authorization'] = 'Bearer $accessToken';

    return retryDio.fetch<dynamic>(
      requestOptions.copyWith(
        headers: headers,
        extra: {...requestOptions.extra, 'skipAuthRefresh': true},
      ),
    );
  }

  Future<_RefreshResult> _serializedRefresh(String refreshToken) async {
    final existing = _refreshFuture;
    if (existing != null) return existing;

    final future = _refreshAccessToken(refreshToken);
    _refreshFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    }
  }

  Future<_RefreshResult> _refreshAccessToken(String refreshToken) async {
    try {
      final refreshDio = _dioFactory();

      final refreshResponse = await refreshDio.post<Map<String, dynamic>>(
        '/open/auth/login',
        data: {'refresh_token': refreshToken},
      );
      final wrapper = refreshResponse.data;
      final authData = wrapper?['data'];
      if (authData is! Map<String, dynamic>) {
        return const _RefreshResult(_RefreshOutcome.terminalFailure);
      }

      final accessToken = authData['access_token'];
      final newRefreshToken = authData['refresh_token'];
      if (accessToken is! String ||
          accessToken.isEmpty ||
          newRefreshToken is! String ||
          newRefreshToken.isEmpty) {
        return const _RefreshResult(_RefreshOutcome.terminalFailure);
      }

      if (await _storage.getRefreshToken() != refreshToken) {
        return const _RefreshResult(_RefreshOutcome.superseded);
      }

      await _storage.saveSession(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );
      return _RefreshResult(_RefreshOutcome.success, accessToken);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        return const _RefreshResult(_RefreshOutcome.terminalFailure);
      }
      return const _RefreshResult(_RefreshOutcome.transientFailure);
    } catch (_) {
      return const _RefreshResult(_RefreshOutcome.terminalFailure);
    }
  }

  Future<void> _expireSessionIfCurrent(String? refreshToken) async {
    final current = await _storage.getRefreshToken();
    if (refreshToken == null) {
      if (current == null || current.isEmpty) await _expireSession();
      return;
    }
    if (current == refreshToken) await _expireSession();
  }

  static String? _bearerToken(dynamic authorization) {
    if (authorization is! String || !authorization.startsWith('Bearer ')) {
      return null;
    }
    final value = authorization.substring('Bearer '.length);
    return value.isEmpty ? null : value;
  }

  static Dio _createDio() {
    return Dio(
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
  }
}
