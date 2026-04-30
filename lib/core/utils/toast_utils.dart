import 'package:flutter/material.dart';
import '../infrastructure/errors/error_message_resolver.dart';
import '../../theme/app_theme.dart';

class ToastUtils {
  static const _errorMessageResolver = ErrorMessageResolver();

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Handles server responses that might contain errors in the format:
  /// {"errors": [{"message": "..."}]}
  static void showServerErrors(BuildContext context, dynamic error) {
    showError(context, _errorMessageResolver.resolve(error));
  }
}
