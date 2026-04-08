import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/config/app_config.dart';
import 'interceptors/auth_interceptor.dart';

part 'dio_provider.g.dart';

@riverpod
Dio dio(DioRef ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Add Interceptors
  dio.interceptors.addAll([
    AuthInterceptor(ref),
    // LogInterceptor(
    //   requestBody: true,
    //   responseBody: true,
    //   logPrint: (obj) => AppConfig.logger.d(obj),
    // ),
  ]);

  return dio;
}
