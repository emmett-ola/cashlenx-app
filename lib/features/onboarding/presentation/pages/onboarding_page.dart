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
      icon: Icons.trending_up_rounded,
      titleKey: 'onboarding_slide1_title',
      descriptionKey: 'onboarding_slide1_desc',
      color: AppTheme.primaryColor,
    ),
    _OnboardingSlide(
      icon: Icons.pie_chart_rounded,
      titleKey: 'onboarding_slide2_title',
      descriptionKey: 'onboarding_slide2_desc',
      color: Color(0xFFFF8A65),
    ),
    _OnboardingSlide(
      icon: Icons.track_changes_rounded,
      titleKey: 'onboarding_slide3_title',
      descriptionKey: 'onboarding_slide3_desc',
      color: Color(0xFF10B981),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
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
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 192,
                              height: 192,
                              decoration: BoxDecoration(
                                color: slide.color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                slide.icon,
                                size: 96,
                                color: slide.color,
                              ),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              appT(context, slide.titleKey),
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              appT(context, slide.descriptionKey),
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
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
                                  ? AppTheme.primaryColor
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.secondaryColor,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(
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
                                borderRadius: BorderRadius.circular(8),
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
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final Color color;

  const _OnboardingSlide({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.color,
  });
}
