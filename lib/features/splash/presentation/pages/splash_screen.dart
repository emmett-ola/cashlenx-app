import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Entrance Animation (Zoom In + Fade In) - Duration 700ms
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

    // Pulse Animation for Logo - Continuous
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // Gradient from #008080 to #4DB6AC (Teal to Light Teal)
            colors: [
              Color(0xFF008080),
              Color(0xFF4DB6AC),
            ],
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
                  // Logo with Pulse
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: SvgPicture.asset(
                      'assets/images/logo_white.svg',
                      height: 112, // w-28 = 7rem = 112px
                      width: 112,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // App Name
                  const Text(
                    'CashLenX',
                    style: TextStyle(
                      fontSize: 36, // text-4xl
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5, // tracking-tight
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Slogan
                  const Text(
                    'Your Financial Companion',
                    style: TextStyle(
                      fontSize: 18, // text-lg
                      fontWeight: FontWeight.w400,
                      color: Colors.white70, // text-white/80
                    ),
                  ),

                  // Optional: Loading Indicator can be hidden or styled to match
                  // Design doesn't show one explicitly, but good for UX if waiting
                  const SizedBox(height: 48),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                      strokeWidth: 2,
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
