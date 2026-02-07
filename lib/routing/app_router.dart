import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../features/splash/presentation/pages/splash_screen.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/home/presentation/pages/home_page.dart';

part 'app_router.g.dart';

@riverpod
GoRouter router(RouterRef ref) {
  // Watch auth state to trigger redirects
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
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
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
    ],
    redirect: (context, state) {
      // If auth state is loading, stay on splash (or return null if on splash)
      if (authState.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/';

      // If logged in
      if (isLoggedIn) {
        // If on splash or login, go to home
        if (isSplash || isLoggingIn) {
          return '/home';
        }
      } 
      // If not logged in
      else {
        // If not on login, go to login
        if (!isLoggingIn && !isSplash) {
          return '/login';
        }
        // If on splash, go to login (once loading is done)
        if (isSplash && !authState.isLoading) {
          return '/login';
        }
      }

      return null;
    },
  );
}
