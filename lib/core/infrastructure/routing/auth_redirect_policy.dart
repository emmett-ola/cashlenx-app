enum AuthStatus { loading, authenticated, unauthenticated }

class AuthRedirectPolicy {
  final String splashPath;
  final String loginPath;
  final String authenticatedHomePath;
  final Set<String> publicAuthPaths;

  const AuthRedirectPolicy({
    required this.splashPath,
    required this.loginPath,
    required this.authenticatedHomePath,
    this.publicAuthPaths = const {},
  });

  String? redirect({
    required AuthStatus authStatus,
    required String location,
  }) {
    if (authStatus == AuthStatus.loading) return null;

    final isSplash = location == splashPath;
    final isPublicAuthPath = publicAuthPaths.contains(location);

    if (authStatus == AuthStatus.authenticated) {
      if (isSplash || isPublicAuthPath) return authenticatedHomePath;
      return null;
    }

    if (isSplash) return loginPath;
    if (!isPublicAuthPath) return loginPath;
    return null;
  }
}
