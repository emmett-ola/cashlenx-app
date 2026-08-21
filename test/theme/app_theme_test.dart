import 'package:cashlenx/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('design tokens match the live Figma Make foundation', () {
    expect(AppDesignTokens.primary, const Color(0xFF008080));
    expect(AppDesignTokens.primaryLight, const Color(0xFF4DB6AC));
    expect(AppDesignTokens.accent, const Color(0xFFFF8A65));
    expect(AppDesignTokens.error, const Color(0xFFEF4444));
    expect(AppDesignTokens.success, const Color(0xFF10B981));
    expect(AppDesignTokens.background, const Color(0xFFF9FAFB));
    expect(AppDesignTokens.radiusControl, 8);
    expect(AppDesignTokens.radiusCard, 16);
    expect(AppDesignTokens.radiusHero, 24);
  });

  test('theme color notifier loads and persists selected color', () async {
    SharedPreferences.setMockInitialValues({'theme-color': '#42A5F5'});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeColorProvider), AppTheme.primaryColor);

    await Future<void>.delayed(Duration.zero);
    expect(container.read(themeColorProvider), const Color(0xFF42A5F5));

    await container
        .read(themeColorProvider.notifier)
        .setColor(const Color(0xFFEC407A));

    expect(container.read(themeColorProvider), const Color(0xFFEC407A));

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('theme-color'), '#EC407A');
  });
}
