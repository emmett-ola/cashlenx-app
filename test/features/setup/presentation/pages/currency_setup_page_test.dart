import 'package:cashlenx/features/home/presentation/providers/currency_provider.dart';
import 'package:cashlenx/features/setup/presentation/pages/currency_setup_page.dart';
import 'package:cashlenx/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('currency catalog matches the complete live setup list', () {
    expect(CurrencyOption.values, hasLength(21));
    expect(CurrencyOption.fromCode('SGD'), CurrencyOption.sgd);
    expect(CurrencyOption.fromCode('VND')?.symbol, '₫');
  });

  testWidgets('first-login setup uses the official logo and searchable list', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppDesignTokens.primary),
          home: const CurrencySetupPage(firstLoginSetup: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('setup-official-logo')), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('CX'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Singapore');
    await tester.pump();

    expect(find.text('SGD'), findsOneWidget);
    expect(find.text('Singapore Dollar'), findsOneWidget);
    expect(find.text('USD'), findsNothing);
  });
}
