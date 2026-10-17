import 'package:cashlenx/core/i18n/app_i18n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const approvedSlogans = <AppLanguage, String>{
    AppLanguage.simplifiedChinese: '财流顺时而变，定力由己自持',
    AppLanguage.traditionalChinese: '財流順時而變，定力由己自持',
    AppLanguage.english: 'Times shape your wealth, mind secures your control.',
  };

  for (final entry in approvedSlogans.entries) {
    test('${entry.key.code} uses the approved slogan on brand surfaces', () {
      final translations = AppTranslations(entry.key);

      expect(translations('app_tagline'), entry.value);
      expect(translations('auth_subtitle'), entry.value);
    });
  }

  test('accessibility control labels are localized in every language', () {
    const keys = [
      'back',
      'filter_transactions',
      'add_budget',
      'previous_month',
      'next_month',
      'previous_period',
      'next_period',
      'delete_digit',
      'close',
    ];

    for (final language in AppLanguage.values) {
      final translations = AppTranslations(language);
      for (final key in keys) {
        expect(translations(key), isNot(key), reason: '${language.code}:$key');
      }
    }
  });

  test('transaction entry copy is localized in every language', () {
    const keys = [
      'transaction_choose_category_hint',
      'add_transaction_note_placeholder',
      'complete',
    ];

    for (final language in AppLanguage.values) {
      final translations = AppTranslations(language);
      for (final key in keys) {
        expect(translations(key), isNot(key), reason: '${language.code}:$key');
      }
    }
  });
}
