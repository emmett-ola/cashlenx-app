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
  NetworkException({required super.message});
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({required super.message});
}

class ServerException extends ApiException {
  ServerException({required super.message, super.statusCode});
}

class NotFoundException extends ApiException {
  NotFoundException({required super.message});
}

class ValidationException extends ApiException {
  ValidationException({required super.message, super.data});
}
