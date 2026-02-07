import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/models/user.dart';

part 'auth_dto.freezed.dart';
part 'auth_dto.g.dart';

// --- Requests ---

@freezed
class LoginRequest with _$LoginRequest {
  const factory LoginRequest({
    String? username,
    String? password,
    @JsonKey(name: 'refresh_token') String? refreshToken,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
}

@freezed
class RegisterRequest with _$RegisterRequest {
  const factory RegisterRequest({
    required String username,
    required String password,
  }) = _RegisterRequest;

  factory RegisterRequest.fromJson(Map<String, dynamic> json) => _$RegisterRequestFromJson(json);
}

// --- Responses ---

@freezed
class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required String token,
    required User user,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);
}
