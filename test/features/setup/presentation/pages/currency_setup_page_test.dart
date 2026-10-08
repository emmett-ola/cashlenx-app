import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:cashlenx/features/home/presentation/providers/currency_provider.dart';
import 'package:cashlenx/features/settings/data/user_configuration_sync.dart';
import 'package:cashlenx/features/setup/data/setup_service.dart';
import 'package:cashlenx/features/setup/presentation/pages/currency_setup_page.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:cashlenx/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
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

  testWidgets('persists first-login currency before completing setup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = _ConfigurationApi();
    final setup = _RecordingSetupService();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_UserAuthNotifier.new),
        cashlenxApiProvider.overrideWithValue(api),
        setupServiceProvider.overrideWithValue(setup),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    final router = _setupRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme(AppDesignTokens.primary),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await _selectSgdAndFinish(tester);
    await tester.pumpAndSettle();

    expect(api.currencyCode, 'SGD');
    expect(setup.completedUserId, 'user-1');
    expect(container.read(currencyProvider), CurrencyOption.sgd);
    expect(router.routeInformationProvider.value.uri.path, '/home');

    await container
        .read(currencyProvider.notifier)
        .setCurrency(CurrencyOption.usd);
    container.invalidate(userConfigurationSyncProvider);
    await container.read(userConfigurationSyncProvider.future);
    expect(container.read(currencyProvider), CurrencyOption.sgd);
  });

  testWidgets('keeps setup incomplete when currency persistence fails', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = _ConfigurationApi(updateError: StateError('Save failed'));
    final setup = _RecordingSetupService();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_UserAuthNotifier.new),
        cashlenxApiProvider.overrideWithValue(api),
        setupServiceProvider.overrideWithValue(setup),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    final router = _setupRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme(AppDesignTokens.primary),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await _selectSgdAndFinish(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(router.routeInformationProvider.value.uri.path, '/setup');
    expect(setup.completedUserId, isNull);
    expect(find.textContaining('Save failed'), findsOneWidget);
  });
}

GoRouter _setupRouter() {
  return GoRouter(
    initialLocation: '/setup',
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) =>
            const CurrencySetupPage(firstLoginSetup: true),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
    ],
  );
}

Future<void> _selectSgdAndFinish(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'Singapore');
  await tester.pump();
  await tester.tap(find.text('SGD'));
  final finish = find.widgetWithText(FilledButton, 'Finish Setup');
  await tester.ensureVisible(finish);
  await tester.tap(finish);
}

class _UserAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async {
    final now = DateTime(2026);
    return User(
      id: 'user-1',
      username: 'maca',
      isActive: true,
      role: 'user',
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _RecordingSetupService extends SetupService {
  String? completedUserId;

  @override
  Future<void> markSetupCompleted(String userId) async {
    completedUserId = userId;
  }
}

class _ConfigurationApi extends CashlenxApi {
  _ConfigurationApi({this.updateError}) : super(ApiClient(Dio()));

  final Object? updateError;
  String currencyCode = 'USD';

  @override
  Future<ApiJson> updateUserConfiguration({
    required String displayLanguage,
    required String currencyCode,
    required String activeThemeColor,
  }) async {
    if (updateError case final error?) throw error;
    this.currencyCode = currencyCode;
    return <String, dynamic>{'data': <String, dynamic>{}};
  }

  @override
  Future<ApiJson> getUserConfiguration() async {
    return <String, dynamic>{
      'data': <String, dynamic>{
        'display_language': 'en',
        'currency_code': currencyCode,
        'active_theme_color': '#008080',
      },
    };
  }
}
