enum AuthStatus { loading, authenticated, unauthenticated }

class AuthRedirectPolicy {
  final String splashPath;
  final String onboardingPath;
  final String loginPath;
  final String setupPath;
  final String authenticatedHomePath;
  final Set<String> publicAuthPaths;

  const AuthRedirectPolicy({
    required this.splashPath,
    required this.onboardingPath,
    required this.loginPath,
    required this.setupPath,
    required this.authenticatedHomePath,
    this.publicAuthPaths = const {},
  });

  String? redirect({
    required AuthStatus authStatus,
    required String location,
    required bool hasSeenOnboarding,
    required bool hasCompletedSetup,
  }) {
    if (authStatus == AuthStatus.loading) {
      return location == splashPath ? null : splashPath;
    }

    final isSplash = location == splashPath;
    final isOnboarding = location == onboardingPath;
    final isSetup = location == setupPath;
    final isPublicAuthPath = publicAuthPaths.contains(location);

    if (!hasSeenOnboarding) {
      return isOnboarding ? null : onboardingPath;
    }

    if (isOnboarding) {
      return authStatus == AuthStatus.authenticated
          ? (hasCompletedSetup ? authenticatedHomePath : setupPath)
          : loginPath;
    }

    if (authStatus == AuthStatus.authenticated) {
      if (!hasCompletedSetup) return isSetup ? null : setupPath;
      if (isSetup || isSplash || isPublicAuthPath) return authenticatedHomePath;
      return null;
    }

    if (isSplash) return loginPath;
    if (!isPublicAuthPath) return loginPath;
    return null;
  }
}
