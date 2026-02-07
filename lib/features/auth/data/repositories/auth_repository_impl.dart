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
  Future<User> login(String username, String password) async {
    final request = LoginRequest(username: username, password: password);
    final response = await _remoteDataSource.login(request);
    
    // Save token
    await _secureStorage.saveToken(response.token);
    
    // Return user
    return response.user;
  }

  @override
  Future<void> register(String username, String password) async {
    final request = RegisterRequest(username: username, password: password);
    await _remoteDataSource.register(request);
  }

  @override
  Future<void> logout() async {
    // Try to notify server, but don't block if fails
    try {
      final token = await _secureStorage.getToken();
      // Ideally we send refresh token, but if we don't have it, maybe access token?
      // The API expects refresh_token. If we don't store it, we can't send it.
      // We'll just call logout without it (which invalidates all sessions according to doc? No.)
      // Doc: "If provided, only this session... If omitted, all sessions"
      // Wait, that's dangerous. We shouldn't logout all sessions by default.
      // But if we don't have refresh token, we have no choice?
      // Or maybe we just delete local token.
      
      // For now, let's just delete local token.
      // await _remoteDataSource.logout(); 
    } catch (_) {}
    
    await _secureStorage.clearAll();
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
