import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:cashlenx/features/onboarding/data/onboarding_service.dart';
import 'package:cashlenx/features/setup/data/setup_service.dart';
import 'package:cashlenx/main.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:cashlenx/routing/app_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('supported web destinations render directly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_DemoAuthNotifier.new),
        onboardingSeenProvider.overrideWith((ref) async => true),
        setupCompletedProvider.overrideWith((ref) async => true),
        cashlenxApiProvider.overrideWithValue(_RouterFakeCashlenxApi()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    await container.read(onboardingSeenProvider.future);
    await container.read(setupCompletedProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CashLenXApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = container.read(routerProvider);
    for (final scenario in <(String, String)>[
      ('/home', 'Total Balance'),
      ('/categories', 'Manage your categories'),
      ('/budgets', 'Manage your spending limits'),
      ('/settings', 'Preferences'),
      ('/transactions', 'Transactions'),
      ('/statistics', 'More Statistics'),
    ]) {
      router.go(scenario.$1);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, scenario.$1);
      expect(find.text(scenario.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    router.go('/unsupported');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.text('/unsupported'), findsOneWidget);
  });
}

class _RouterFakeCashlenxApi extends CashlenxApi {
  _RouterFakeCashlenxApi() : super(ApiClient(Dio()));

  @override
  Future<ApiJson> listAllCategories({
    String? type,
    String? parentId,
    int? limit,
    int? offset,
  }) async {
    return {
      'code': 'OK',
      'message': '',
      'data': <dynamic>[],
      'meta': <String, dynamic>{},
      'errors': <dynamic>[],
      'extra': <String, dynamic>{},
    };
  }
}

class _DemoAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async {
    final now = DateTime(2026);
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
