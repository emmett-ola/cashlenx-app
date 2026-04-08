class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => 'ApiException(message: $message, statusCode: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException({required super.message, super.data});
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({required super.message, super.data});
}

class ServerException extends ApiException {
  ServerException({required super.message, super.statusCode, super.data});
}

class NotFoundException extends ApiException {
  NotFoundException({required super.message, super.data});
}

class ValidationException extends ApiException {
  ValidationException({required super.message, super.data});
}
