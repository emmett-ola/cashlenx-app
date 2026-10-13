import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/app_i18n.dart';
import 'app_fonts.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

final themeColorProvider = NotifierProvider<ThemeColorNotifier, Color>(
  ThemeColorNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
}

class ThemeColorNotifier extends Notifier<Color> {
  static const _themeColorKey = 'theme-color';

  @override
  Color build() {
    _loadSavedColor();
    return AppTheme.primaryColor;
  }

  Future<void> setColor(Color color) async {
    state = color;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeColorKey, AppTheme.hexColor(color));
  }

  Future<void> _loadSavedColor() async {
    final preferences = await SharedPreferences.getInstance();
    final color = AppTheme.colorFromHex(preferences.getString(_themeColorKey));
    if (color != null) {
      state = color;
    }
  }
}

class AppDesignTokens {
  const AppDesignTokens._();

  // Brand and semantic colors from the live Figma Make source.
  static const primary = Color(0xFF008080);
  static const primaryLight = Color(0xFF4DB6AC);
  static const primaryDark = Color(0xFF004D40);
  static const secondary = Color(0xFF4A6363);
  static const accent = Color(0xFFFF8A65);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const background = Color(0xFFF9FAFB);
  static const surface = Colors.white;
  static const border = Color(0xFFE5E7EB);
  static const softFill = Color(0xFFF3F4F6);
  static const text = Color(0xFF111827);
  static const mutedText = Color(0xFF6B7280);

  // The design follows a 4 px spacing grid.
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;
  static const space12 = 48.0;

  static const radiusControl = 8.0;
  static const radiusField = 8.0;
  static const radiusCard = 16.0;
  static const radiusHero = 24.0;
  static const mobileCanvasMaxWidth = 430.0;
}

class AppMotion {
  const AppMotion._();

  static const entranceDuration = Duration(milliseconds: 240);
  static const feedbackDuration = Duration(milliseconds: 240);
  static const reducedMotionFadeDuration = Duration(milliseconds: 160);
  static const strongEaseOut = Cubic(0.23, 1, 0.32, 1);
}

@immutable
class AppSurfaceColors extends ThemeExtension<AppSurfaceColors> {
  const AppSurfaceColors({
    required this.background,
    required this.surface,
    required this.softFill,
    required this.border,
    required this.text,
    required this.mutedText,
    required this.navMuted,
  });

  static const light = AppSurfaceColors(
    background: AppDesignTokens.background,
    surface: AppDesignTokens.surface,
    softFill: AppDesignTokens.softFill,
    border: AppDesignTokens.border,
    text: AppDesignTokens.text,
    mutedText: AppDesignTokens.mutedText,
    navMuted: Color(0xFF9CA3AF),
  );

  static const dark = AppSurfaceColors(
    background: Color(0xFF0B1114),
    surface: Color(0xFF11191D),
    softFill: Color(0xFF1A252A),
    border: Color(0xFF34434A),
    text: Color(0xFFF3F4F6),
    mutedText: Color(0xFFB0BBC0),
    navMuted: Color(0xFF95A3AA),
  );

  final Color background;
  final Color surface;
  final Color softFill;
  final Color border;
  final Color text;
  final Color mutedText;
  final Color navMuted;

  @override
  AppSurfaceColors copyWith({
    Color? background,
    Color? surface,
    Color? softFill,
    Color? border,
    Color? text,
    Color? mutedText,
    Color? navMuted,
  }) {
    return AppSurfaceColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      softFill: softFill ?? this.softFill,
      border: border ?? this.border,
      text: text ?? this.text,
      mutedText: mutedText ?? this.mutedText,
      navMuted: navMuted ?? this.navMuted,
    );
  }

  @override
  AppSurfaceColors lerp(covariant AppSurfaceColors? other, double t) {
    if (other == null) return this;
    return AppSurfaceColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      softFill: Color.lerp(softFill, other.softFill, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      navMuted: Color.lerp(navMuted, other.navMuted, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSurfaceColors get appColors {
    final theme = Theme.of(this);
    return theme.extension<AppSurfaceColors>() ??
        (theme.brightness == Brightness.dark
            ? AppSurfaceColors.dark
            : AppSurfaceColors.light);
  }
}

class AppTheme {
  static const primaryColor = AppDesignTokens.primary;
  static const secondaryColor = AppDesignTokens.primaryLight;
  static const accentColor = AppDesignTokens.accent;
  static const errorColor = AppDesignTokens.error;
  static const successColor = AppDesignTokens.success;
  static const warningColor = AppDesignTokens.warning;

  static ThemeData lightTheme(
    Color themeColor, {
    AppLanguage language = AppLanguage.english,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: themeColor,
      brightness: Brightness.light,
      secondary: secondaryColor,
      error: errorColor,
    ).copyWith(primary: themeColor, onPrimary: Colors.white);

    return _withLocalizedFonts(
      ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: colorScheme,
        extensions: const [AppSurfaceColors.light],
        scaffoldBackgroundColor: AppDesignTokens.background,
        cardTheme: const CardThemeData(
          color: AppDesignTokens.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppDesignTokens.radiusCard),
            ),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: AppDesignTokens.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppDesignTokens.radiusCard),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(AppDesignTokens.radiusControl),
              ),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppDesignTokens.radiusField),
            ),
          ),
          filled: true,
          fillColor: AppDesignTokens.softFill,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppDesignTokens.surface,
          surfaceTintColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(color: AppDesignTokens.border),
      ),
      language,
    );
  }

  static ThemeData darkTheme(
    Color themeColor, {
    AppLanguage language = AppLanguage.english,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: themeColor,
      brightness: Brightness.dark,
      secondary: secondaryColor,
      error: errorColor,
    ).copyWith(primary: themeColor, onPrimary: Colors.white);

    return _withLocalizedFonts(
      ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        extensions: const [AppSurfaceColors.dark],
        scaffoldBackgroundColor: AppSurfaceColors.dark.background,
        canvasColor: AppSurfaceColors.dark.surface,
        cardTheme: CardThemeData(
          color: AppSurfaceColors.dark.surface,
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppSurfaceColors.dark.surface,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppDesignTokens.radiusCard),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(AppDesignTokens.radiusControl),
              ),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppDesignTokens.radiusField),
            ),
          ),
          filled: true,
          fillColor: AppSurfaceColors.dark.softFill,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppSurfaceColors.dark.surface,
          surfaceTintColor: Colors.transparent,
        ),
        dividerTheme: DividerThemeData(color: AppSurfaceColors.dark.border),
      ),
      language,
    );
  }

  static ThemeData _withLocalizedFonts(ThemeData theme, AppLanguage language) {
    final family = AppFonts.familyFor(language);
    final fallback = AppFonts.fallbackFamiliesFor(language);
    return theme.copyWith(
      textTheme: theme.textTheme.apply(
        fontFamily: family,
        fontFamilyFallback: fallback,
      ),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamily: family,
        fontFamilyFallback: fallback,
      ),
    );
  }

  static Color? colorFromHex(String? value) {
    final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value ?? '');
    if (match == null) return null;

    final rgb = int.parse(match.group(1)!, radix: 16);
    return Color(0xFF000000 | rgb);
  }

  static String hexColor(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
