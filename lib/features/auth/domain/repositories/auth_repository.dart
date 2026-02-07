import '../../../../network/api_exceptions.dart';
import '../../domain/models/user.dart';

abstract class AuthRepository {
  Future<User> login(String username, String password);
  Future<void> register(String username, String password);
  Future<void> logout();
  Future<User?> getCurrentUser(); // From local storage or profile API
}
