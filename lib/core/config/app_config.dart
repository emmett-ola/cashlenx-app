import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment { dev, staging, prod }

class AppConfig {
  static late Environment _environment;
  static late Logger _logger;
  static late String _apiBaseUrl;

  static Future<void> init() async {
    // Load `.env` file from assets
    await dotenv.load(fileName: ".env");

    final envStr = dotenv.env['APP_ENV']?.toLowerCase() ?? 'dev';
    _environment = Environment.values.firstWhere(
      (e) => e.name == envStr,
      orElse: () => Environment.dev,
    );

    _apiBaseUrl = _getBaseUrl();

    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.none,
      ),
    );
  }

  static String _getBaseUrl() {
    final scheme = dotenv.env['API_SCHEME'] ?? 'https';
    final domain = dotenv.env['API_DOMAIN'] ?? 'api.cashlenx.com';
    final port = dotenv.env['API_PORT'];
    final version = dotenv.env['API_VERSION'] ?? 'v1';

    if (port != null && port.isNotEmpty) {
      return '$scheme://$domain:$port/$version';
    }
    return '$scheme://$domain/$version';
  }

  static Logger get logger => _logger;
  static String get apiBaseUrl => _apiBaseUrl;
  static Environment get environment => _environment;
}
