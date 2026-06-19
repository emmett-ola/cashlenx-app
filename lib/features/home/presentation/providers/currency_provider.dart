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
  eur('EUR', 'Euro', '\u20AC'),
  gbp('GBP', 'British Pound', '\u00A3'),
  jpy('JPY', 'Japanese Yen', '\u00A5'),
  cny('CNY', 'Chinese Yuan', '\u00A5'),
  inr('INR', 'Indian Rupee', '\u20B9'),
  aud('AUD', 'Australian Dollar', r'A$'),
  cad('CAD', 'Canadian Dollar', r'C$'),
  chf('CHF', 'Swiss Franc', 'Fr'),
  hkd('HKD', 'Hong Kong Dollar', r'HK$'),
  sgd('SGD', 'Singapore Dollar', r'S$'),
  krw('KRW', 'South Korean Won', '\u20A9'),
  brl('BRL', 'Brazilian Real', r'R$'),
  mxn('MXN', 'Mexican Peso', r'Mex$'),
  zar('ZAR', 'South African Rand', 'R'),
  rub('RUB', 'Russian Ruble', '\u20BD'),
  thb('THB', 'Thai Baht', '\u0E3F'),
  idr('IDR', 'Indonesian Rupiah', 'Rp'),
  myr('MYR', 'Malaysian Ringgit', 'RM'),
  php('PHP', 'Philippine Peso', '\u20B1'),
  vnd('VND', 'Vietnamese Dong', '\u20AB'),
  twd('TWD', 'Taiwan Dollar', r'NT$');

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
