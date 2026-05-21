import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class AppTheme {
  // Colors
  static const primaryColor = Color(0xFF008080); // Teal (THEME_PRIMARY)
  static const secondaryColor = Color(0xFF4DB6AC); // Light Teal
  static const errorColor = Color(0xFFD32F2F);
  static const successColor = Color(0xFF388E3C);

  static ThemeData lightTheme(Color themeColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: themeColor,
        brightness: Brightness.light,
        secondary: secondaryColor,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
      ),
    );
  }

  static ThemeData darkTheme(Color themeColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: themeColor,
        brightness: Brightness.dark,
        secondary: secondaryColor,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
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
