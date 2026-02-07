import 'package:riverpod_annotation/riverpod_annotation.dart';
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
      return await repository.getCurrentUser();
    } catch (e) {
      // If error, assume not authenticated
      return null;
    }
  }

  Future<void> login(String username, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      return await repository.login(username, password);
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
