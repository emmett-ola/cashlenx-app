import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/models/auth_dto.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_repository_impl.g.dart';

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(secureStorageServiceProvider),
  );
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorage;

  AuthRepositoryImpl(this._remoteDataSource, this._secureStorage);

  @override
  Future<User> login(String username, String password,
      {bool rememberMe = false}) async {
    final request = LoginRequest(username: username, password: password);
    final response = await _remoteDataSource.login(request);

    // Save tokens and preference
    await _secureStorage.saveToken(response.accessToken);
    await _secureStorage.saveRefreshToken(response.refreshToken);
    await _secureStorage.saveRememberMe(rememberMe);

    // Return user
    return response.user;
  }

  @override
  Future<User> loginWithRefreshToken(String refreshToken) async {
    final request = LoginRequest(refreshToken: refreshToken);
    final response = await _remoteDataSource.login(request);

    // Save tokens
    await _secureStorage.saveToken(response.accessToken);
    await _secureStorage.saveRefreshToken(response.refreshToken);

    return response.user;
  }

  @override
  Future<void> register(String username, String password) async {
    final request = RegisterRequest(username: username, password: password);
    await _remoteDataSource.register(request);
  }

  @override
  Future<void> requestPasswordReset(String emailOrUsername) async {
    await _remoteDataSource.requestPasswordReset(emailOrUsername);
  }

  @override
  Future<void> confirmPasswordReset(String token, String password) async {
    await _remoteDataSource.confirmPasswordReset(token, password);
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      await _remoteDataSource.logout(refreshToken: refreshToken);
    } catch (_) {
      // Local logout should still complete if the server session is already gone.
    } finally {
      // Only clear session tokens, keep the rememberMe preference.
      await _secureStorage.clearSession();
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    // Check if we have a token
    final token = await _secureStorage.getToken();
    if (token == null) return null;

    try {
      final user = await _remoteDataSource.getProfile();
      return user;
    } catch (e) {
      // If profile fetch fails (e.g. 401), we should probably clear token?
      // For now, return null.
      return null;
    }
  }
}
