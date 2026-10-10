import 'package:cashlenx/core/infrastructure/persistence/memory_key_value_store.dart';
import 'package:cashlenx/core/infrastructure/errors/api_exception.dart';
import 'package:cashlenx/core/i18n/app_i18n.dart';
import 'package:cashlenx/core/services/secure_storage_service.dart';
import 'package:cashlenx/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/domain/repositories/auth_repository.dart';
import 'package:cashlenx/features/auth/presentation/pages/login_page.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:cashlenx/features/settings/data/user_configuration_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('accepts a username in the login identifier field', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await tester.binding.setSurfaceSize(const Size(430, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        secureStorageServiceProvider.overrideWithValue(
          SecureStorageService(MemoryKeyValueStore()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: LoginPage())),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'maca');
    await tester.enterText(fields.at(1), 'secret1');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pump();

    expect(repository.lastUsername, 'maca');
    expect(repository.lastPassword, 'secret1');
  });

  testWidgets(
    'keeps credentials and shows the rejection after a failed login',
    (tester) async {
      final repository = _FakeAuthRepository(
        loginError: const UnauthorizedException(
          message: 'Invalid credentials',
          data: {
            'errors': [
              {'message': 'Invalid credentials'},
            ],
          },
        ),
      );
      await tester.binding.setSurfaceSize(const Size(430, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          secureStorageServiceProvider.overrideWithValue(
            SecureStorageService(MemoryKeyValueStore()),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: LoginPage())),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'maca');
      await tester.enterText(fields.at(1), 'wrong-secret');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(authNotifierProvider).hasError, isTrue);
      expect(find.text('maca'), findsOneWidget);
      expect(find.text('wrong-secret'), findsOneWidget);
      expect(find.text('Invalid credentials'), findsOneWidget);
    },
  );

  for (final (languageIndex, language) in AppLanguage.values.indexed) {
    testWidgets(
      'keeps ${language.name} from login through the first demo screen',
      (tester) async {
        SharedPreferences.setMockInitialValues({'app_language': 'en'});
        await tester.binding.setSurfaceSize(const Size(430, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            secureStorageServiceProvider.overrideWithValue(
              SecureStorageService(MemoryKeyValueStore()),
            ),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(
              path: '/login',
              builder: (context, state) => const Scaffold(body: LoginPage()),
            ),
            GoRoute(
              path: '/home',
              builder: (context, state) => const _DemoHomeProbe(),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();

        await tester.tap(find.text('Change Language'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ListTile).at(languageIndex));
        await tester.pumpAndSettle();

        final demoAction = find.text(
          AppTranslations(language)('continue_demo'),
        );
        await tester.ensureVisible(demoAction);
        await tester.tap(demoAction);
        await tester.pumpAndSettle();

        expect(find.text('ready:${language.code}'), findsOneWidget);
        expect(container.read(i18nProvider), language);
      },
    );
  }
}

class _DemoHomeProbe extends ConsumerWidget {
  const _DemoHomeProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(userConfigurationSyncProvider);
    final language = ref.watch(i18nProvider);
    final state = sync.isLoading ? 'loading' : 'ready';
    return Scaffold(body: Text('$state:${language.code}'));
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.loginError});

  final Object? loginError;
  String? lastUsername;
  String? lastPassword;

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<User> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    lastUsername = username;
    lastPassword = password;
    if (loginError case final error?) throw error;

    final now = DateTime(2026);
    return User(
      id: 'user-1',
      username: username,
      isActive: true,
      role: 'user',
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<User> loginWithRefreshToken(String refreshToken) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> register(
    String username,
    String password,
    String email,
    String verificationToken,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendVerificationCode(String purpose, String email) {
    throw UnimplementedError();
  }

  @override
  Future<String> verifyVerificationCode(
    String purpose,
    String email,
    String code,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> requestPasswordReset(String emailOrUsername) {
    throw UnimplementedError();
  }

  @override
  Future<void> confirmPasswordReset(String token, String password) {
    throw UnimplementedError();
  }
}
