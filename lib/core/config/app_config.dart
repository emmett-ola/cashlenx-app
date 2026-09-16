import 'package:logger/logger.dart';
import '../infrastructure/logging/app_logger.dart';
import '../infrastructure/logging/logger_app_logger.dart';

enum Environment { dev, staging, prod }

class AppConfig {
  static late Environment _environment;
  static late AppLogger _logger;
  static late String _apiBaseUrl;

  static Future<void> init() async {
    const envStr = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    _environment = Environment.values.firstWhere(
      (e) => e.name == envStr.toLowerCase(),
      orElse: () => Environment.dev,
    );

    _apiBaseUrl = _getBaseUrl();

    _logger = LoggerAppLogger(
      Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.none,
        ),
      ),
    );
  }

  static String _getBaseUrl() {
    const scheme = String.fromEnvironment('API_SCHEME', defaultValue: 'http');
    const domain = String.fromEnvironment(
      'API_DOMAIN',
      defaultValue: '127.0.0.1',
    );
    const port = String.fromEnvironment('API_PORT', defaultValue: '10063');
    const version = String.fromEnvironment(
      'API_VERSION',
      defaultValue: 'api/v0',
    );

    if (port.isNotEmpty) {
      return '$scheme://$domain:$port/$version';
    }
    return '$scheme://$domain/$version';
  }

  static AppLogger get logger => _logger;
  static String get apiBaseUrl => _apiBaseUrl;
  static Environment get environment => _environment;
}
