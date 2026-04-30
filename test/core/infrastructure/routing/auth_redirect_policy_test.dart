import 'package:cashlenx/core/infrastructure/routing/auth_redirect_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = AuthRedirectPolicy(
    splashPath: '/',
    loginPath: '/login',
    authenticatedHomePath: '/home',
    publicAuthPaths: {'/login', '/register', '/forgot-password'},
  );

  test('does not redirect while auth is loading', () {
    expect(
      policy.redirect(authStatus: AuthStatus.loading, location: '/'),
      isNull,
    );
  });

  test('sends unauthenticated users to login from protected routes', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.unauthenticated,
        location: '/home',
      ),
      '/login',
    );
  });

  test('allows unauthenticated users on public auth routes', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.unauthenticated,
        location: '/register',
      ),
      isNull,
    );
  });

  test('sends authenticated users away from auth routes', () {
    expect(
      policy.redirect(
        authStatus: AuthStatus.authenticated,
        location: '/login',
      ),
      '/home',
    );
  });
}
