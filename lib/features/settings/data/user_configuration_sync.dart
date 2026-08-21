import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../network/cashlenx_api.dart';
import '../../../theme/app_theme.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../demo/data/demo_data_store.dart';
import '../../home/presentation/providers/currency_provider.dart';

final userConfigurationSyncProvider = FutureProvider<void>((ref) async {
  final user = await ref.watch(authNotifierProvider.future);
  if (user == null) return;

  try {
    final response = user.role == 'demo'
        ? await ref.read(demoDataStoreProvider).getConfiguration()
        : await ref.read(cashlenxApiProvider).getUserConfiguration();
    final data = _responseData(response);
    final language = AppLanguage.fromCode(data['display_language']?.toString());
    final currency = CurrencyOption.fromCode(
      data['currency_code']?.toString().toUpperCase(),
    );
    final color = AppTheme.colorFromHex(data['active_theme_color']?.toString());

    await ref.read(i18nProvider.notifier).setLanguage(language);
    if (currency != null) {
      await ref.read(currencyProvider.notifier).setCurrency(currency);
    }
    if (color != null) {
      await ref.read(themeColorProvider.notifier).setColor(color);
    }
  } catch (_) {
    // Local preferences remain the offline fallback when configuration sync
    // cannot reach the authenticated service.
  }
});

final persistUserConfigurationProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    final language = ref.read(i18nProvider).serverCode;
    final currency = ref.read(currencyProvider).code;
    final color = AppTheme.hexColor(ref.read(themeColorProvider));

    if (user.role == 'demo') {
      await ref
          .read(demoDataStoreProvider)
          .updateConfiguration(
            displayLanguage: language,
            currencyCode: currency,
            activeThemeColor: color,
          );
      return;
    }

    await ref
        .read(cashlenxApiProvider)
        .updateUserConfiguration(
          displayLanguage: language,
          currencyCode: currency,
          activeThemeColor: color,
        );
  };
});

Map<String, dynamic> _responseData(ApiJson response) {
  final data = response['data'];
  return data is Map ? Map<String, dynamic>.from(data) : response;
}
