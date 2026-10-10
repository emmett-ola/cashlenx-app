import 'package:cashlenx/core/i18n/app_i18n.dart';
import 'package:cashlenx/features/auth/presentation/widgets/auth_language_button.dart';
import 'package:cashlenx/theme/app_fonts.dart';
import 'package:cashlenx/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('switches between complete Simplified and Traditional labels', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});

    await tester.pumpWidget(const ProviderScope(child: _LanguageHarness()));
    await tester.pumpAndSettle();

    expect(find.text('Change Language'), findsOneWidget);

    await tester.tap(find.text('Change Language'));
    await tester.pumpAndSettle();
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('繁體中文'), findsOneWidget);

    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(find.text('更改语言'), findsOneWidget);
    expect(
      _currentTheme(tester).textTheme.bodyMedium?.fontFamily,
      AppFonts.simplifiedChineseFamily,
    );

    await tester.tap(find.text('更改语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('繁體中文'));
    await tester.pumpAndSettle();
    expect(find.text('變更語言'), findsOneWidget);
    expect(
      _currentTheme(tester).textTheme.bodyMedium?.fontFamily,
      AppFonts.traditionalChineseFamily,
    );
  });
}

ThemeData _currentTheme(WidgetTester tester) {
  final context = tester.element(find.byType(AuthLanguageButton));
  return Theme.of(context);
}

class _LanguageHarness extends ConsumerWidget {
  const _LanguageHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(i18nProvider);
    return MaterialApp(
      theme: AppTheme.lightTheme(AppTheme.primaryColor, language: language),
      home: const Scaffold(body: AuthLanguageButton()),
    );
  }
}
