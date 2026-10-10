import 'package:cashlenx/core/i18n/app_i18n.dart';
import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:cashlenx/features/home/presentation/providers/currency_provider.dart';
import 'package:cashlenx/features/settings/data/user_configuration_sync.dart';
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
  _ConfigurationApi() : super(ApiClient(Dio()));

  @override
  Future<ApiJson> getUserConfiguration() async {
    return <String, dynamic>{
      'data': <String, dynamic>{
        'display_language': AppLanguage.traditionalChinese.serverCode,
        'currency_code': CurrencyOption.sgd.code,
        'active_theme_color': '#4DB6AC',
      },
    };
  }
}
