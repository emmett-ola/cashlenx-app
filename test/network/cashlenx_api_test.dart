import 'dart:convert';
import 'dart:typed_data';

import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profile updates omit blank optional values from the request body',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = _HandlerAdapter((options) async {
          requests.add(options);
          return _jsonResponse(200, <String, dynamic>{
            'data': <String, dynamic>{'id': 'user-1'},
          });
        });
      final api = CashlenxApi(ApiClient(dio));

      await api.updateUserProfile(
        nickname: 'Alice',
        avatarUrl: ' ',
        gender: '\t',
        phoneNumber: '',
        location: '   ',
        birthDate: '\n',
      );
      await api.updateUserProfile(
        nickname: '',
        avatarUrl: '',
        gender: '',
        phoneNumber: '',
        location: '',
        birthDate: '',
      );

      expect(requests, hasLength(2));
      expect(requests.first.method, 'PUT');
      expect(requests.first.path, '/user/profile');
      expect(requests.first.data, <String, dynamic>{'nickname': 'Alice'});
      expect(requests.last.data, isEmpty);
    },
  );
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
  const _HandlerAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

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
