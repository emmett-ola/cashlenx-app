import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/infrastructure/routing/auth_redirect_policy.dart';
import '../features/auth/domain/models/user.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/splash/presentation/pages/splash_screen.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/home/presentation/pages/home_page.dart';

part 'app_router.g.dart';

const _authRedirectPolicy = AuthRedirectPolicy(
  splashPath: '/',
  loginPath: '/login',
  authenticatedHomePath: '/home',
  publicAuthPaths: {'/login', '/register', '/forgot-password'},
);

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final listenable = ValueNotifier<AsyncValue<User?>>(
    ref.read(authNotifierProvider),
  );
  ref.listen(authNotifierProvider, (previous, next) {
    listenable.value = next;
  });

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false, // Reduced noise
    refreshListenable: listenable,
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      return _authRedirectPolicy.redirect(
        authStatus: authState.isLoading
            ? AuthStatus.loading
            : authState.value != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        location: state.matchedLocation,
      );
    },
  );
}
