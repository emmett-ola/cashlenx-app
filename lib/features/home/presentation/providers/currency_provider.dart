import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final currencyProvider = NotifierProvider<CurrencyNotifier, CurrencyOption>(
  CurrencyNotifier.new,
);

class CurrencyNotifier extends Notifier<CurrencyOption> {
  static const _currencyKey = 'currency';

  @override
  CurrencyOption build() {
    _loadSavedCurrency();
    return CurrencyOption.usd;
  }

  Future<void> setCurrency(CurrencyOption currency) async {
    state = currency;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_currencyKey, currency.code);
  }

  Future<void> _loadSavedCurrency() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_currencyKey);
    final currency = CurrencyOption.fromCode(saved);
    if (currency != null) state = currency;
  }
}

enum CurrencyOption {
  usd('USD', 'US Dollar', r'$'),
  cny('CNY', 'Chinese Yuan', '\u00A5'),
  hkd('HKD', 'Hong Kong Dollar', r'$'),
  twd('TWD', 'Taiwan New Dollar', r'$');

  const CurrencyOption(this.code, this.name, this.symbol);

  final String code;
  final String name;
  final String symbol;

  static CurrencyOption? fromCode(String? code) {
    for (final currency in values) {
      if (currency.code == code) return currency;
    }
    return null;
  }
}
