import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/secure_storage_service.dart';
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
        // If not remember me, we still want to check if there is a session for this app run,
        // but if it's a fresh start, we clear.
        // Actually, your requirement: "once user close the app, tokens lost"
        await secureStorage.clearAll();
        return null;
      }

      final refreshToken = await secureStorage.getRefreshToken();
      if (refreshToken != null) {
        // Try auto-login with refresh token
        try {
          return await repository.loginWithRefreshToken(refreshToken);
        } catch (e) {
          // If refresh token login fails (e.g. expired refresh token), clear all
          await secureStorage.clearAll();
          return null;
        }
      }

      return await repository.getCurrentUser();
    } catch (e) {
      // If error (e.g. token expired), assume not authenticated
      return null;
    }
  }

  Future<void> login(String username, String password, {bool rememberMe = false}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      return await repository.login(username, password, rememberMe: rememberMe);
    });
  }

  Future<void> register(String username, String password) async {
    // Register doesn't automatically login usually, but we can make it so.
    // For now, just call repo and let UI handle success navigation to login.
    final repository = ref.read(authRepositoryProvider);
    await repository.register(username, password);
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(null);
  }
}
