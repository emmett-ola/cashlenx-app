import 'package:cashlenx/core/i18n/app_i18n.dart';
import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:cashlenx/features/home/presentation/providers/currency_provider.dart';
import 'package:cashlenx/features/settings/data/user_configuration_sync.dart';
import 'package:cashlenx/features/setup/data/setup_service.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:cashlenx/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('authenticated configuration remains authoritative', () async {
    SharedPreferences.setMockInitialValues({
      'app_language': AppLanguage.english.code,
    });
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedUserNotifier.new),
        cashlenxApiProvider.overrideWithValue(_ConfigurationApi()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);

    await container.read(userConfigurationSyncProvider.future);

    expect(container.read(i18nProvider), AppLanguage.traditionalChinese);
    expect(container.read(currencyProvider), CurrencyOption.sgd);
    expect(AppTheme.hexColor(container.read(themeColorProvider)), '#4DB6AC');
  });

  test('server setup state restores preferences on a clean device', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_AuthenticatedUserNotifier.new),
        cashlenxApiProvider.overrideWithValue(
          _ConfigurationApi(setupCompleted: true, currencyCode: 'USD'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(setupCompletedProvider.future), isTrue);
    expect(container.read(currencyProvider), CurrencyOption.usd);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('has_completed_setup_user-1'), isTrue);
  });

  test(
    'unconfigured server account overrides a stale local completion',
    () async {
      SharedPreferences.setMockInitialValues({
        'has_completed_setup_user-1': true,
      });
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_AuthenticatedUserNotifier.new),
          cashlenxApiProvider.overrideWithValue(
            _ConfigurationApi(setupCompleted: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(setupCompletedProvider.future), isFalse);
    },
  );

  test(
    'configuration failure keeps the local offline completion fallback',
    () async {
      SharedPreferences.setMockInitialValues({
        'has_completed_setup_user-1': true,
      });
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_AuthenticatedUserNotifier.new),
          cashlenxApiProvider.overrideWithValue(_ConfigurationApi(fail: true)),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(setupCompletedProvider.future), isTrue);
    },
  );
}

class _AuthenticatedUserNotifier extends AuthNotifier {
  @override
  Future<User?> build() async {
    final now = DateTime(2026);
    return User(
      id: 'user-1',
      username: 'maca',
      isActive: true,
      role: 'user',
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _ConfigurationApi extends CashlenxApi {
  _ConfigurationApi({
    this.setupCompleted = true,
    this.currencyCode = 'SGD',
    this.fail = false,
  }) : super(ApiClient(Dio()));

  final bool setupCompleted;
  final String currencyCode;
  final bool fail;

  @override
  Future<ApiJson> getUserConfiguration() async {
    if (fail) throw StateError('offline');
    return <String, dynamic>{
      'data': <String, dynamic>{
        'display_language': AppLanguage.traditionalChinese.serverCode,
        'currency_code': currencyCode,
        'active_theme_color': '#4DB6AC',
        'setup_completed': setupCompleted,
      },
    };
  }
}
