class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() =>
      'ApiException(message: $message, statusCode: $statusCode)';
}

class NetworkException extends ApiException {
  const NetworkException({required super.message, super.data});
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({required super.message, super.data});
}

class ServerException extends ApiException {
  const ServerException({
    required super.message,
    required super.statusCode,
    super.data,
  });
}

class NotFoundException extends ApiException {
  const NotFoundException({required super.message, super.data});
}

class ValidationException extends ApiException {
  const ValidationException({required super.message, super.data});
}
