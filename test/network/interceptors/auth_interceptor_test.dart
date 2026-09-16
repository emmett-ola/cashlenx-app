import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cashlenx/core/infrastructure/persistence/memory_key_value_store.dart';
import 'package:cashlenx/core/services/secure_storage_service.dart';
import 'package:cashlenx/network/interceptors/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'serializes concurrent refreshes and retries with the rotated token',
    () async {
      final storage = SecureStorageService(MemoryKeyValueStore());
      await storage.saveSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );
      var refreshCalls = 0;
      var expireCalls = 0;

      final adapter = _HandlerAdapter((options) async {
        if (options.path == '/open/auth/login') {
          refreshCalls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _jsonResponse(200, {
            'data': {
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            },
          });
        }
        if (options.headers['Authorization'] == 'Bearer new-access') {
          return _jsonResponse(200, {'data': 'ok'});
        }
        return _jsonResponse(401, {'code': 'UNAUTHORIZED'});
      });
      Dio clientFactory() => _dio(adapter);
      final dio = clientFactory()
        ..interceptors.add(
          AuthInterceptor(
            storage: storage,
            expireSession: () async {
              expireCalls += 1;
              await storage.clearSession();
            },
            dioFactory: clientFactory,
          ),
        );

      final responses = await Future.wait([
        dio.get<Map<String, dynamic>>('/resource'),
        dio.get<Map<String, dynamic>>('/resource'),
      ]);

      expect(
        responses.map((response) => response.statusCode),
        everyElement(200),
      );
      expect(refreshCalls, 1);
      expect(expireCalls, 0);
      expect(await storage.getToken(), 'new-access');
      expect(await storage.getRefreshToken(), 'new-refresh');
    },
  );

  test(
    'keeps the session after a transient refresh transport failure',
    () async {
      final storage = SecureStorageService(MemoryKeyValueStore());
      await storage.saveSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );
      var expireCalls = 0;

      final adapter = _HandlerAdapter((options) async {
        if (options.path == '/open/auth/login') {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: StateError('offline'),
          );
        }
        return _jsonResponse(401, {'code': 'UNAUTHORIZED'});
      });
      Dio clientFactory() => _dio(adapter);
      final dio = clientFactory()
        ..interceptors.add(
          AuthInterceptor(
            storage: storage,
            expireSession: () async {
              expireCalls += 1;
              await storage.clearSession();
            },
            dioFactory: clientFactory,
          ),
        );

      await expectLater(
        dio.get<Map<String, dynamic>>('/resource'),
        throwsA(isA<DioException>()),
      );

      expect(expireCalls, 0);
      expect(await storage.getToken(), 'old-access');
      expect(await storage.getRefreshToken(), 'old-refresh');
    },
  );

  test('expires the current session after a rejected refresh token', () async {
    final storage = SecureStorageService(MemoryKeyValueStore());
    await storage.saveSession(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
    );
    var expireCalls = 0;

    final adapter = _HandlerAdapter((options) async {
      if (options.path == '/open/auth/login') {
        return _jsonResponse(401, {'code': 'UNAUTHORIZED'});
      }
      return _jsonResponse(401, {'code': 'UNAUTHORIZED'});
    });
    Dio clientFactory() => _dio(adapter);
    final dio = clientFactory()
      ..interceptors.add(
        AuthInterceptor(
          storage: storage,
          expireSession: () async {
            expireCalls += 1;
            await storage.clearSession();
          },
          dioFactory: clientFactory,
        ),
      );

    await expectLater(
      dio.get<Map<String, dynamic>>('/resource'),
      throwsA(isA<DioException>()),
    );

    expect(expireCalls, 1);
    expect(await storage.getToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
  });

  test(
    'does not restore a session cleared while refresh is in flight',
    () async {
      final storage = SecureStorageService(MemoryKeyValueStore());
      await storage.saveSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      var expireCalls = 0;

      final adapter = _HandlerAdapter((options) async {
        if (options.path == '/open/auth/login') {
          refreshStarted.complete();
          await releaseRefresh.future;
          return _jsonResponse(200, {
            'data': {
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            },
          });
        }
        return _jsonResponse(401, {'code': 'UNAUTHORIZED'});
      });
      Dio clientFactory() => _dio(adapter);
      final dio = clientFactory()
        ..interceptors.add(
          AuthInterceptor(
            storage: storage,
            expireSession: () async {
              expireCalls += 1;
              await storage.clearSession();
            },
            dioFactory: clientFactory,
          ),
        );

      final request = dio.get<Map<String, dynamic>>('/resource');
      await refreshStarted.future;
      await storage.clearSession();
      releaseRefresh.complete();

      await expectLater(request, throwsA(isA<DioException>()));
      expect(expireCalls, 0);
      expect(await storage.getToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    },
  );
}

Dio _dio(HttpClientAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'https://api.example.test'))
    ..httpClientAdapter = adapter;
}

ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _HandlerAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _HandlerAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
