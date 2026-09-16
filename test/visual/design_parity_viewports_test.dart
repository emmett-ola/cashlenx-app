import 'dart:typed_data';

import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:cashlenx/features/home/presentation/pages/home_page.dart';
import 'package:cashlenx/features/profile/presentation/pages/profile_page.dart';
import 'package:cashlenx/shared/widgets/mobile_page_shell.dart';
import 'package:cashlenx/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final comparator = goldenFileComparator;
  if (comparator is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenFileComparator(
      comparator.basedir.resolve('design_parity_viewports_test.dart'),
      precisionTolerance: 0.02,
    );
  }

  const viewports = <String, Size>{
    'phone-390': Size(390, 844),
    'shell-430': Size(430, 932),
    'tablet-768': Size(768, 1024),
  };

  for (final entry in viewports.entries) {
    testWidgets('dashboard visual acceptance at ${entry.key}', (tester) async {
      await _pumpDemoPage(tester, entry.value, const HomePage());

      expect(find.text('Total Balance'), findsOneWidget);
      expect(find.text('Coffee beans'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('visual-root')),
        matchesGoldenFile('goldens/dashboard-${entry.key}.png'),
      );
    });
  }

  testWidgets('settings and profile visual acceptance at shell width', (
    tester,
  ) async {
    await _pumpDemoPage(tester, viewports['shell-430']!, const HomePage());
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('visual-root')),
      matchesGoldenFile('goldens/settings-shell-430.png'),
    );

    await _pumpDemoPage(tester, viewports['shell-430']!, const ProfilePage());
    expect(find.text('Personal Information'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('visual-root')),
      matchesGoldenFile('goldens/profile-shell-430.png'),
    );
  });
}

// Flutter's software renderer has small platform- and engine-specific
// anti-aliasing differences. Keep a narrow tolerance while semantic assertions
// continue to protect required content and interactions.
class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(
         precisionTolerance >= 0 && precisionTolerance <= 1,
         'precisionTolerance must be between 0 and 1',
       ),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed || result.diffPercent <= _precisionTolerance) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Future<void> _pumpDemoPage(WidgetTester tester, Size size, Widget page) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(
    overrides: [authNotifierProvider.overrideWith(_DemoAuthNotifier.new)],
  );
  addTearDown(container.dispose);
  await container.read(authNotifierProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(AppDesignTokens.primary),
        home: RepaintBoundary(
          key: const ValueKey('visual-root'),
          child: MobilePageShell(child: page),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _DemoAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async {
    final now = DateTime(2026, 8, 21);
    return User(
      id: 'demo-user',
      username: 'Demo User',
      isActive: true,
      role: 'demo',
      createdAt: now,
      updatedAt: now,
    );
  }
}
