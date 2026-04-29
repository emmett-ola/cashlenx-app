import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../features/auth/domain/models/user.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/splash/presentation/pages/splash_screen.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/home/presentation/pages/home_page.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(RouterRef ref) {
  final listenable =
      ValueNotifier<AsyncValue<User?>>(ref.read(authNotifierProvider));
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

      // If auth state is loading, stay on splash (or return null if on splash)
      if (authState.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';
      final isResettingPassword = state.matchedLocation == '/forgot-password';
      final isSplash = state.matchedLocation == '/';

      // If logged in
      if (isLoggedIn) {
        // If on splash or login, go to home
        if (isSplash || isLoggingIn || isRegistering || isResettingPassword) {
          return '/home';
        }
      }
      // If not logged in
      else {
        // If not on login and not on splash, go to login
        if (!isLoggingIn &&
            !isRegistering &&
            !isResettingPassword &&
            !isSplash) {
          return '/login';
        }
        // If on splash, go to login
        if (isSplash) {
          return '/login';
        }
      }

      return null;
    },
  );
}
