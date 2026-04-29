import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../network/api_client.dart';
import '../../../../core/network/response_wrapper.dart';
import '../models/auth_dto.dart';
import '../../domain/models/user.dart';

part 'auth_remote_data_source.g.dart';

@riverpod
AuthRemoteDataSource authRemoteDataSource(AuthRemoteDataSourceRef ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider));
}

class AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSource(this._apiClient);

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/open/auth/login',
        data: request.toJson(),
      );

      final wrapper = ResponseWrapper<AuthResponse>.fromJson(
        response,
        (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
      );

      if (wrapper.data == null) {
        throw Exception(wrapper.message);
      }

      return wrapper.data!;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register(RegisterRequest request) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/open/auth/register',
      data: request.toJson(),
    );
  }

  Future<void> logout({String? refreshToken}) async {
    await _apiClient.post(
      '/open/auth/logout',
      data: refreshToken != null ? {'refresh_token': refreshToken} : null,
    );
  }

  Future<User> getProfile() async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/user/profile');

    final wrapper = ResponseWrapper<User>.fromJson(
      response,
      (json) => User.fromJson(json as Map<String, dynamic>),
    );

    if (wrapper.data == null) {
      throw Exception(wrapper.message);
    }

    return wrapper.data!;
  }
}
