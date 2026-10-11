import 'package:flutter/services.dart';

import '../core/i18n/app_i18n.dart';

class AppFonts {
  const AppFonts._();

  static const simplifiedChineseFamily = 'CashLenX Noto Sans SC';
  static const traditionalChineseFamily = 'CashLenX Noto Sans TC';
  static const simplifiedChineseAsset = 'assets/fonts/NotoSansSC-UI.ttf';
  static const traditionalChineseAsset = 'assets/fonts/NotoSansTC-UI.ttf';
  static const simplifiedChineseAssetBytes = 17772300;
  static const traditionalChineseAssetBytes = 11941968;

  static Future<void>? _loadFuture;

  static Future<void> ensureBundledFontsLoaded() {
    return _loadFuture ??= Future.wait([
      _loadFont(
        simplifiedChineseFamily,
        simplifiedChineseAsset,
        simplifiedChineseAssetBytes,
      ),
      _loadFont(
        traditionalChineseFamily,
        traditionalChineseAsset,
        traditionalChineseAssetBytes,
      ),
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

  static Future<void> _loadFont(
    String family,
    String asset,
    int expectedBytes,
  ) async {
    final data = await rootBundle.load(asset);
    if (data.lengthInBytes != expectedBytes) {
      throw StateError(
        '$asset does not contain the pinned complete Chinese font '
        '($expectedBytes bytes expected, found ${data.lengthInBytes})',
      );
    }
    final loader = FontLoader(family)..addFont(Future.value(data));
    await loader.load();
  }
}
