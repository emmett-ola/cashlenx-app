import '../../domain/models/user.dart';

abstract class AuthRepository {
  Future<User> login(
    String username,
    String password, {
    bool rememberMe = false,
  });
  Future<void> register(
    String username,
    String password,
    String email,
    String verificationToken,
  );
  Future<void> sendVerificationCode(String purpose, String email);
  Future<String> verifyVerificationCode(
    String purpose,
    String email,
    String code,
  );
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<User> loginWithRefreshToken(String refreshToken);
  Future<void> requestPasswordReset(String emailOrUsername);
  Future<void> confirmPasswordReset(String token, String password);
}
