import 'package:cashlenx/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/domain/repositories/auth_repository.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'demo logout clears local auth state without calling repository',
    () async {
      final repository = _FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);

      notifier.continueAsDemo();
      await notifier.logout();

      expect(container.read(authNotifierProvider).value, isNull);
      expect(repository.logoutCalls, 0);
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  var logoutCalls = 0;

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<User> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<User> loginWithRefreshToken(String refreshToken) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }

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
