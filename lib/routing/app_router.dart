import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/infrastructure/routing/auth_redirect_policy.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/splash/presentation/pages/splash_screen.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/onboarding/data/onboarding_service.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/setup/data/setup_service.dart';
import '../features/setup/presentation/pages/currency_setup_page.dart';
import '../shared/widgets/mobile_page_shell.dart';

part 'app_router.g.dart';

const _authRedirectPolicy = AuthRedirectPolicy(
  splashPath: '/',
  onboardingPath: '/onboarding',
  loginPath: '/login',
  setupPath: '/setup',
  authenticatedHomePath: '/home',
  publicAuthPaths: {'/login', '/register', '/forgot-password'},
);

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final listenable = ValueNotifier<Object>(Object());
  ref.listen(authNotifierProvider, (previous, next) {
    listenable.value = Object();
  });
  ref.listen(onboardingSeenProvider, (previous, next) {
    listenable.value = Object();
  });
  ref.listen(setupCompletedProvider, (previous, next) {
    listenable.value = Object();
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
        builder: (context, state) => const MobilePageShell(child: LoginPage()),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) =>
            const MobilePageShell(child: OnboardingPage()),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) =>
            const MobilePageShell(child: RegisterPage()),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) =>
            const MobilePageShell(child: ForgotPasswordPage()),
      ),
      GoRoute(
        path: '/currency-setup',
        name: 'currency-setup',
        builder: (context, state) => const _ProtectedRoute(
          child: MobilePageShell(child: CurrencySetupPage()),
        ),
      ),
      GoRoute(
        path: '/setup',
        name: 'setup',
        builder: (context, state) => const MobilePageShell(
          child: CurrencySetupPage(firstLoginSetup: true),
        ),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const _ProtectedRoute(
            child: MobilePageShell(
              child: HomePage(section: HomeSection.dashboard),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/categories',
        name: 'categories',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const _ProtectedRoute(
            child: MobilePageShell(
              child: HomePage(section: HomeSection.categories),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/budgets',
        name: 'budgets',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const _ProtectedRoute(
            child: MobilePageShell(
              child: HomePage(section: HomeSection.budget),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const _ProtectedRoute(
            child: MobilePageShell(
              child: HomePage(section: HomeSection.settings),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/transactions',
        name: 'transactions',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const _ProtectedRoute(
            child: MobilePageShell(
              child: HomePage(section: HomeSection.transactions),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/transactions/:transactionId',
        name: 'transaction-detail',
        pageBuilder: (context, state) {
          final origin = state.uri.queryParameters['from'] == 'home'
              ? HomeSection.dashboard
              : HomeSection.transactions;
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: _ProtectedRoute(
              child: MobilePageShell(
                child: HomePage(
                  section: origin,
                  transactionId: state.pathParameters['transactionId'],
                ),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/statistics',
        name: 'statistics',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const _ProtectedRoute(
            child: MobilePageShell(
              child: HomePage(section: HomeSection.statistics),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) {
          final returnPath = state.uri.queryParameters['from'] == 'settings'
              ? '/settings'
              : '/home';
          return _ProtectedRoute(
            child: MobilePageShell(child: ProfilePage(returnPath: returnPath)),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => _ProtectedRoute(
      child: MobilePageShell(
        child: _UnknownRoutePage(location: state.uri.path),
      ),
    ),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final onboardingState = ref.read(onboardingSeenProvider);
      final setupState = ref.read(setupCompletedProvider);
      final hasSeenOnboarding = onboardingState.value;
      final location = state.matchedLocation;

      final isProtectedDestination =
          location != _authRedirectPolicy.splashPath &&
          location != _authRedirectPolicy.onboardingPath &&
          location != _authRedirectPolicy.setupPath &&
          !_authRedirectPolicy.publicAuthPaths.contains(location);
      if (authState.isLoading && isProtectedDestination) {
        return null;
      }

      if (hasSeenOnboarding == null) return null;
      if (authState.value != null && setupState.value == null) return null;

      return _authRedirectPolicy.redirect(
        authStatus: authState.isLoading
            ? AuthStatus.loading
            : authState.value != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        location: location,
        hasSeenOnboarding: hasSeenOnboarding,
        hasCompletedSetup: setupState.value ?? true,
      );
    },
  );
}

class _ProtectedRoute extends ConsumerWidget {
  const _ProtectedRoute({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final setupState = ref.watch(setupCompletedProvider);

    if (authState.value == null || setupState.value != true) {
      return const SplashScreen();
    }

    return child;
  }
}

class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Page not found',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                location,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Return home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
