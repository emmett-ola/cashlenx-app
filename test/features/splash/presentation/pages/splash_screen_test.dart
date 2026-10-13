import 'package:cashlenx/features/splash/presentation/pages/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash enters quickly from a subtle visible scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SplashScreen())),
    );

    final scaleFinder = find.byKey(const ValueKey('splash-entrance-scale'));
    final fadeFinder = find.byKey(const ValueKey('splash-entrance-fade'));
    var scale = tester.widget<ScaleTransition>(scaleFinder);
    var fade = tester.widget<FadeTransition>(fadeFinder);
    expect(scale.scale.value, closeTo(0.96, 0.001));
    expect(fade.opacity.value, 0);

    await tester.pump(const Duration(milliseconds: 80));
    scale = tester.widget<ScaleTransition>(scaleFinder);
    fade = tester.widget<FadeTransition>(fadeFinder);
    expect(scale.scale.value, greaterThan(0.96));
    expect(scale.scale.value, lessThanOrEqualTo(1));
    expect(fade.opacity.value, greaterThan(0));

    await tester.pumpAndSettle();
    scale = tester.widget<ScaleTransition>(scaleFinder);
    fade = tester.widget<FadeTransition>(fadeFinder);
    expect(scale.scale.value, 1);
    expect(fade.opacity.value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion keeps the splash static while fading', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const SplashScreen(),
        ),
      ),
    );

    final scaleFinder = find.byKey(const ValueKey('splash-entrance-scale'));
    final fadeFinder = find.byKey(const ValueKey('splash-entrance-fade'));
    var scale = tester.widget<ScaleTransition>(scaleFinder);
    var fade = tester.widget<FadeTransition>(fadeFinder);
    expect(scale.scale.value, 1);
    expect(fade.opacity.value, 0);

    await tester.pump(const Duration(milliseconds: 80));
    scale = tester.widget<ScaleTransition>(scaleFinder);
    fade = tester.widget<FadeTransition>(fadeFinder);
    expect(scale.scale.value, 1);
    expect(fade.opacity.value, greaterThan(0));

    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
