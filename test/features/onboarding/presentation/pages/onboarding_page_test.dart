import 'package:cashlenx/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:cashlenx/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('uses live-design photos with deterministic fallbacks', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(430, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppDesignTokens.primary),
          home: const OnboardingPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('onboarding-artwork-0')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-image-fallback-0')),
      findsOneWidget,
    );

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('onboarding-network-image-0')),
    );
    final provider = image.image as NetworkImage;
    expect(provider.url, contains('images.unsplash.com/photo-1758522484692'));

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('onboarding-artwork-1')), findsOneWidget);
    expect(find.text('Plan Your Budgets'), findsOneWidget);
  });
}
