import 'package:cashlenx/core/infrastructure/routing/auth_redirect_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = AuthRedirectPolicy(
    splashPath: '/',
    onboardingPath: '/onboarding',
    loginPath: '/login',
    setupPath: '/setup',
    authenticatedHomePath: '/home',
    publicAuthPaths: {'/login', '/register', '/forgot-password'},
  );

  test('keeps loading sessions on splash and redirects deep links', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.loading,
        location: '/',
        hasSeenOnboarding: false,
        hasCompletedSetup: false,
      ),
      isNull,
    );
    expect(
      policy.redirect(
        authStatus: AuthStatus.loading,
        location: '/login',
        hasSeenOnboarding: true,
        hasCompletedSetup: false,
      ),
      '/',
    );
  });

  test('sends first-time users to onboarding', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.unauthenticated,
        location: '/login',
        hasSeenOnboarding: false,
        hasCompletedSetup: false,
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
        hasCompletedSetup: false,
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
        hasCompletedSetup: false,
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
        hasCompletedSetup: false,
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
        hasCompletedSetup: true,
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
        hasCompletedSetup: false,
      ),
      '/login',
    );
  });

  test(
    'sends authenticated users to setup until first-login setup completes',
    () {
      expect(
        policy.redirect(
          authStatus: AuthStatus.authenticated,
          location: '/home',
          hasSeenOnboarding: true,
          hasCompletedSetup: false,
        ),
        '/setup',
      );
    },
  );

  test('allows authenticated users to stay on setup before completion', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.authenticated,
        location: '/setup',
        hasSeenOnboarding: true,
        hasCompletedSetup: false,
      ),
      isNull,
    );
  });

  test('sends authenticated users away from setup after completion', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.authenticated,
        location: '/setup',
        hasSeenOnboarding: true,
        hasCompletedSetup: true,
      ),
      '/home',
    );
  });
}
