import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../demo/data/demo_data_store.dart';
import '../../domain/models/user.dart';
import '../../data/repositories/auth_repository_impl.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<User?> build() async {
    // Artificial delay to ensure splash screen is visible for at least 2 seconds
    // allowing entrance animations to complete
    await Future.delayed(const Duration(seconds: 2));
    return _checkAuthStatus();
  }

  Future<User?> _checkAuthStatus() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final secureStorage = ref.read(secureStorageServiceProvider);

      final rememberMe = await secureStorage.getRememberMe();
      if (!rememberMe) {
        await secureStorage.clearSession();
        return null;
      }

      final refreshToken = await secureStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        // Try auto-login with refresh token
        try {
          return await repository.loginWithRefreshToken(refreshToken);
        } catch (e) {
          // If refresh token login fails (e.g. expired refresh token), clear all
          await secureStorage.clearAll();
          return null;
        }
      }

      // A persisted access token without its rotating refresh credential is a
      // partial session and must not be restored.
      await secureStorage.clearSession();
      return null;
    } catch (_) {
      try {
        await ref.read(secureStorageServiceProvider).clearSession();
      } catch (_) {
        // The caller still receives a signed-out state if secure storage is
        // temporarily unavailable.
      }
      return null;
    }
  }

  Future<void> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      return await repository.login(username, password, rememberMe: rememberMe);
    });
  }

  Future<void> continueAsDemo() async {
    await ref.read(secureStorageServiceProvider).clearSession();
    ref.read(demoDataStoreProvider).reset();
    ref.read(demoDataRevisionProvider.notifier).bump();

    final now = DateTime.now();
    state = AsyncValue.data(
      User(
        id: 'demo-user',
        username: 'Demo User',
        isActive: true,
        role: 'demo',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> register(
    String username,
    String password,
    String email,
    String verificationToken,
  ) async {
    // Register doesn't automatically login usually, but we can make it so.
    // For now, just call repo and let UI handle success navigation to login.
    final repository = ref.read(authRepositoryProvider);
    await repository.register(username, password, email, verificationToken);
  }

  Future<void> sendVerificationCode(String purpose, String email) {
    return ref
        .read(authRepositoryProvider)
        .sendVerificationCode(purpose, email);
  }

  Future<String> verifyVerificationCode(
    String purpose,
    String email,
    String code,
  ) {
    return ref
        .read(authRepositoryProvider)
        .verifyVerificationCode(purpose, email, code);
  }

  Future<void> requestPasswordReset(String emailOrUsername) async {
    final repository = ref.read(authRepositoryProvider);
    await repository.requestPasswordReset(emailOrUsername);
  }

  Future<void> confirmPasswordReset(String token, String password) async {
    final repository = ref.read(authRepositoryProvider);
    await repository.confirmPasswordReset(token, password);
  }

  Future<void> logout() async {
    final currentUser = state.value;
    if (currentUser?.role == 'demo') {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(null);
  }

  Future<void> expireSession() async {
    await ref.read(secureStorageServiceProvider).clearSession();

    final currentUser = state.value;
    if (currentUser?.role == 'demo') {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider = authProvider;
