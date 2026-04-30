import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return const OnboardingService();
});

final onboardingSeenProvider = FutureProvider<bool>((ref) {
  return ref.read(onboardingServiceProvider).hasSeenOnboarding();
});

class OnboardingService {
  const OnboardingService();

  static const _hasSeenOnboardingKey = 'has_seen_onboarding';

  Future<bool> hasSeenOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_hasSeenOnboardingKey) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_hasSeenOnboardingKey, true);
  }
}
