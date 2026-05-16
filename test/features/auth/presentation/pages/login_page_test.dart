import 'package:cashlenx/core/infrastructure/persistence/memory_key_value_store.dart';
import 'package:cashlenx/core/services/secure_storage_service.dart';
import 'package:cashlenx/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/domain/repositories/auth_repository.dart';
import 'package:cashlenx/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('accepts a username in the login identifier field', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          secureStorageServiceProvider.overrideWithValue(
            SecureStorageService(MemoryKeyValueStore()),
          ),
        ],
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
}

class _FakeAuthRepository implements AuthRepository {
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
  Future<void> register(String username, String password) {
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
