import 'package:flutter/services.dart';

import '../core/i18n/app_i18n.dart';

class AppFonts {
  const AppFonts._();

  static const simplifiedChineseFamily = 'CashLenX Noto Sans SC';
  static const traditionalChineseFamily = 'CashLenX Noto Sans TC';
  static const simplifiedChineseAsset = 'assets/fonts/NotoSansSC-UI.ttf';
  static const traditionalChineseAsset = 'assets/fonts/NotoSansTC-UI.ttf';

  static Future<void>? _loadFuture;

  static Future<void> ensureBundledFontsLoaded() {
    return _loadFuture ??= Future.wait([
      _loadFont(simplifiedChineseFamily, simplifiedChineseAsset),
      _loadFont(traditionalChineseFamily, traditionalChineseAsset),
    ]);
  }

  static String? familyFor(AppLanguage language) => switch (language) {
    AppLanguage.english => null,
    AppLanguage.simplifiedChinese => simplifiedChineseFamily,
    AppLanguage.traditionalChinese => traditionalChineseFamily,
  };

  static List<String> fallbackFamiliesFor(AppLanguage language) =>
      switch (language) {
        AppLanguage.traditionalChinese => const [
          traditionalChineseFamily,
          simplifiedChineseFamily,
        ],
        AppLanguage.english || AppLanguage.simplifiedChinese => const [
          simplifiedChineseFamily,
          traditionalChineseFamily,
        ],
      };

  static Future<void> _loadFont(String family, String asset) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }
}
