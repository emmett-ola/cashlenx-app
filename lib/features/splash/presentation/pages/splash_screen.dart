import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeIn),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController.forward().then((_) {
      _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(i18nProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppDesignTokens.primary, AppDesignTokens.primaryLight],
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: SvgPicture.asset(
                      'assets/images/logo_white.svg',
                      height: 112,
                      width: 112,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    appT(context, 'app_name'),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      appT(context, 'app_tagline'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
