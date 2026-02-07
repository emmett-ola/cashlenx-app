import 'package:logger/logger.dart';

enum Environment { dev, staging, prod }

class AppConfig {
  static late Environment _environment;
  static late Logger _logger;
  static late String _apiBaseUrl;

  static Future<void> init() async {
    // In a real app, this might load from .env files or build flavors
    // For now, we default to dev
    _environment = Environment.dev;
    _apiBaseUrl = _getBaseUrl(_environment);
    
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: false,
      ),
    );
    
    _logger.i("App initialized in ${_environment.name} mode");
  }

  static String _getBaseUrl(Environment env) {
    switch (env) {
      case Environment.dev:
        return 'https://dev-api.cashlenx.com/v1';
      case Environment.staging:
        return 'https://staging-api.cashlenx.com/v1';
      case Environment.prod:
        return 'https://api.cashlenx.com/v1';
    }
  }

  static Logger get logger => _logger;
  static String get apiBaseUrl => _apiBaseUrl;
  static Environment get environment => _environment;
}
