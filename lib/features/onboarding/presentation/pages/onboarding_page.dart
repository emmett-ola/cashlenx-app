import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/onboarding_service.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _currentSlide = 0;

  static const _slides = [
    _OnboardingSlide(
      titleKey: 'onboarding_slide1_title',
      descriptionKey: 'onboarding_slide1_desc',
      imageUrl:
          'https://images.unsplash.com/photo-1758522484692-efa6ce38a25f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxmaW5hbmNpYWwlMjBwbGFubmluZyUyMHdvbWFuJTIwc21hcnRwaG9uZXxlbnwxfHx8fDE3NzAzNzIzNTB8MA&ixlib=rb-4.1.0&q=80&w=1080',
      fallbackIcon: Icons.trending_up_rounded,
      fallbackColor: AppDesignTokens.primary,
    ),
    _OnboardingSlide(
      titleKey: 'onboarding_slide2_title',
      descriptionKey: 'onboarding_slide2_desc',
      imageUrl:
          'https://images.unsplash.com/photo-1652422485224-102f6784c149?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxidWRnZXQlMjB0cmFja2luZyUyMGlsbHVzdHJhdGlvbnxlbnwxfHx8fDE3NzAzMTU0MzJ8MA&ixlib=rb-4.1.0&q=80&w=1080',
      fallbackIcon: Icons.pie_chart_rounded,
      fallbackColor: AppDesignTokens.accent,
    ),
    _OnboardingSlide(
      titleKey: 'onboarding_slide3_title',
      descriptionKey: 'onboarding_slide3_desc',
      imageUrl:
          'https://images.unsplash.com/photo-1551288049-bebda4e38f71?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxkYXRhJTIwYW5hbHl0aWNzJTIwZGFzaGJvYXJkfGVufDF8fHx8MTc3MDI5MTc1M3ww&ixlib=rb-4.1.0&q=80&w=1080',
      fallbackIcon: Icons.track_changes_rounded,
      fallbackColor: AppDesignTokens.success,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingServiceProvider).markOnboardingSeen();
    ref.invalidate(onboardingSeenProvider);
    if (!mounted) return;

    final user = ref.read(authNotifierProvider).value;
    context.go(user == null ? '/login' : '/home');
  }

  void _next() {
    if (_currentSlide == _slides.length - 1) {
      _finish();
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(i18nProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppDesignTokens.background, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextButton(
                        onPressed: _finish,
                        child: Text(appT(context, 'skip')),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _slides.length,
                      onPageChanged: (index) {
                        setState(() => _currentSlide = index);
                      },
                      itemBuilder: (context, index) {
                        final slide = _slides[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _OnboardingArtwork(
                                key: ValueKey('onboarding-artwork-$index'),
                                index: index,
                                slide: slide,
                                semanticLabel: appT(context, slide.titleKey),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                appT(context, slide.titleKey),
                                textAlign: TextAlign.center,
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                appT(context, slide.descriptionKey),
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge?.copyWith(
                                  color: AppDesignTokens.mutedText,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_slides.length, (index) {
                            final isActive = index == _currentSlide;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 32 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppDesignTokens.primary
                                    : AppDesignTokens.border,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppDesignTokens.radiusControl,
                              ),
                              gradient: const LinearGradient(
                                colors: [
                                  AppDesignTokens.primary,
                                  AppDesignTokens.primaryLight,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppDesignTokens.primary.withValues(
                                    alpha: 0.24,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _next,
                              icon: const Icon(Icons.chevron_right_rounded),
                              label: Text(
                                _currentSlide == _slides.length - 1
                                    ? appT(context, 'get_started')
                                    : appT(context, 'next'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDesignTokens.radiusControl,
                                  ),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.titleKey,
    required this.descriptionKey,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  final String titleKey;
  final String descriptionKey;
  final String imageUrl;
  final IconData fallbackIcon;
  final Color fallbackColor;
}

class _OnboardingArtwork extends StatelessWidget {
  const _OnboardingArtwork({
    super.key,
    required this.index,
    required this.slide,
    required this.semanticLabel,
  });

  final int index;
  final _OnboardingSlide slide;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 256,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ArtworkFallback(
              key: ValueKey('onboarding-image-fallback-$index'),
              icon: slide.fallbackIcon,
              color: slide.fallbackColor,
            ),
            Image.network(
              slide.imageUrl,
              key: ValueKey('onboarding-network-image-$index'),
              fit: BoxFit.cover,
              semanticLabel: semanticLabel,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return const SizedBox.shrink();
              },
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: ExcludeSemantics(child: Icon(icon, size: 88, color: color)),
    );
  }
}
