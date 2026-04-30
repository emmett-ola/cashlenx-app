import 'api_exception.dart';

class ErrorMessageResolver {
  const ErrorMessageResolver();

  String resolve(dynamic error) {
    if (error is ApiException) {
      return _messageFromData(error.data) ?? error.message;
    }
    if (error is Map<String, dynamic>) {
      return _messageFromData(error) ?? error.toString();
    }
    return error.toString();
  }

  String? _messageFromData(dynamic data) {
    if (data is! Map<String, dynamic>) return null;

    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      return errors.map((error) {
        if (error is Map) return error['message'] ?? error.toString();
        return error.toString();
      }).join('\n');
    }

    final message = data['message'];
    return message is String && message.isNotEmpty ? message : null;
  }
}
