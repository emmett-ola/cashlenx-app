import 'package:dio/dio.dart';

import '../errors/api_exception.dart';

class DioExceptionMapper {
  const DioExceptionMapper();

  ApiException map(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(message: 'Connection timed out');
      case DioExceptionType.badResponse:
        return _mapBadResponse(error);
      case DioExceptionType.cancel:
        return const ApiException(message: 'Request cancelled');
      case DioExceptionType.unknown:
        return _mapUnknown(error);
      default:
        return ApiException(
          message: 'Something went wrong: ${error.message}',
          statusCode: error.response?.statusCode,
        );
    }
  }

  ApiException _mapBadResponse(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final message = _messageFromData(data) ?? error.message ?? 'Unknown error';

    if (statusCode == 401) {
      return UnauthorizedException(message: message, data: data);
    }
    if (statusCode == 404) {
      return NotFoundException(message: message, data: data);
    }
    if (statusCode != null && statusCode >= 500) {
      return ServerException(
        message: 'Server error: $statusCode',
        statusCode: statusCode,
        data: data,
      );
    }
    if (statusCode == 400 || statusCode == 422) {
      return ValidationException(message: message, data: data);
    }

    return ApiException(message: message, statusCode: statusCode, data: data);
  }

  ApiException _mapUnknown(DioException error) {
    if (error.error.toString().contains('SocketException')) {
      return const NetworkException(message: 'No internet connection');
    }
    return ApiException(
      message: 'Unexpected error occurred: ${error.message}',
      statusCode: error.response?.statusCode,
    );
  }

  String? _messageFromData(dynamic data) {
    if (data is! Map) return null;
    final message = data['message'];
    return message is String && message.isNotEmpty ? message : null;
  }
}
