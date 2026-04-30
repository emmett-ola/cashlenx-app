import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/response_wrapper.dart';
import '../../../../network/cashlenx_api.dart';
import '../models/auth_dto.dart';
import '../../domain/models/user.dart';

part 'auth_remote_data_source.g.dart';

@riverpod
AuthRemoteDataSource authRemoteDataSource(AuthRemoteDataSourceRef ref) {
  return AuthRemoteDataSource(ref.watch(cashlenxApiProvider));
}

class AuthRemoteDataSource {
  final CashlenxApi _api;

  AuthRemoteDataSource(this._api);

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _api.login(
        username: request.username,
        password: request.password,
        refreshToken: request.refreshToken,
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
    await _api.register(
      username: request.username,
      password: request.password,
    );
  }

  Future<void> requestPasswordReset(String emailOrUsername) async {
    await _api.requestPasswordReset(emailOrUsername);
  }

  Future<void> confirmPasswordReset(String token, String password) async {
    await _api.confirmPasswordReset(
      token: token,
      password: password,
    );
  }

  Future<void> logout({String? refreshToken}) async {
    await _api.logout(refreshToken: refreshToken);
  }

  Future<User> getProfile() async {
    final response = await _api.getUserProfile();

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
