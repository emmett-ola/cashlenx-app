import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../../settings/data/user_configuration_sync.dart';

final setupServiceProvider = Provider<SetupService>((ref) {
  return const SetupService();
});

final setupCompletedProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(authNotifierProvider.future);
  if (user == null || user.role == 'demo') return true;
  final service = ref.read(setupServiceProvider);
  final localCompleted = await service.hasCompletedSetup(user.id);
  final sync = await ref.watch(userConfigurationSyncProvider.future);

  if (!sync.synchronized || sync.setupCompleted == null) {
    return localCompleted;
  }
  if (!sync.setupCompleted!) return false;

  if (!localCompleted) {
    await service.markSetupCompleted(user.id);
  }
  return true;
});

class SetupService {
  const SetupService();

  static const _setupKeyPrefix = 'has_completed_setup';

  Future<bool> hasCompletedSetup(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key(userId)) ?? false;
  }

  Future<void> markSetupCompleted(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key(userId), true);
  }

  String _key(String userId) => '${_setupKeyPrefix}_$userId';
}
