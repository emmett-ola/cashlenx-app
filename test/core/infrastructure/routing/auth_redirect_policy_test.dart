import 'package:cashlenx/core/infrastructure/routing/auth_redirect_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = AuthRedirectPolicy(
    splashPath: '/',
    onboardingPath: '/onboarding',
    loginPath: '/login',
    authenticatedHomePath: '/home',
    publicAuthPaths: {'/login', '/register', '/forgot-password'},
  );

  test('does not redirect while auth is loading', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.loading,
        location: '/',
        hasSeenOnboarding: false,
      ),
      isNull,
    );
  });

  test('sends first-time users to onboarding', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.unauthenticated,
        location: '/login',
        hasSeenOnboarding: false,
      ),
      '/onboarding',
    );
  });

  test('allows first-time users to stay on onboarding', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.unauthenticated,
        location: '/onboarding',
        hasSeenOnboarding: false,
      ),
      isNull,
    );
  });

  test('sends unauthenticated users to login from protected routes', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.unauthenticated,
        location: '/home',
        hasSeenOnboarding: true,
      ),
      '/login',
    );
  });

  test('allows unauthenticated users on public auth routes', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.unauthenticated,
        location: '/register',
        hasSeenOnboarding: true,
      ),
      isNull,
    );
  });

  test('sends authenticated users away from auth routes', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.authenticated,
        location: '/login',
        hasSeenOnboarding: true,
      ),
      '/home',
    );
  });

  test('sends users away from onboarding after it has been seen', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.unauthenticated,
        location: '/onboarding',
        hasSeenOnboarding: true,
      ),
      '/login',
    );
  });
}
