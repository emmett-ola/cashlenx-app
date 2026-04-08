import 'package:flutter/material.dart';
import '../../network/api_exceptions.dart';
import '../../theme/app_theme.dart';

class ToastUtils {
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
    String? message;

    if (error is ApiException) {
      final data = error.data;
      if (data is Map<String, dynamic>) {
        final errors = data['errors'];
        if (errors is List && errors.isNotEmpty) {
          message = errors
              .map((e) => e is Map ? e['message'] : e.toString())
              .join('\n');
        } else {
          message = data['message'] ?? error.message;
        }
      } else {
        message = error.message;
      }
    } else if (error is Map<String, dynamic>) {
      final errors = error['errors'];
      if (errors is List && errors.isNotEmpty) {
        message = errors
            .map((e) => e is Map ? e['message'] : e.toString())
            .join('\n');
      } else {
        message = error['message'];
      }
    }

    showError(context, message ?? error.toString());
  }
}
