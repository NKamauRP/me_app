import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/services/notification_service.dart';
import '../core/services/theme_service.dart';
import '../shared/widgets/main_cta.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = [
    const _OnboardingSlide(
      title: 'Welcome to ME',
      subtitle: 'Your compassionate space for emotional awareness and mindful reflection.',
      icon: Icons.psychology_alt_rounded,
      color: Colors.blueAccent,
    ),
    const _OnboardingSlide(
      title: 'Private & Local',
      subtitle: 'Your logs and insights never leave your device. Zero cloud, zero tracking, total privacy.',
      icon: Icons.shield_rounded,
      color: Colors.greenAccent,
    ),
    const _OnboardingSlide(
      title: 'Gentle Nudges',
      subtitle: 'Allow notifications for a daily 1-minute reflection to help you stay in tune with yourself.',
      icon: Icons.notifications_active_rounded,
      color: Colors.orangeAccent,
      isPermissionSlide: true,
    ),
    const _OnboardingSlide(
      title: 'On-Device AI',
      subtitle: 'ME uses powerful offline models for insights. You can pick and download your AI companion in Settings.',
      icon: Icons.auto_awesome_rounded,
      color: Colors.purpleAccent,
    ),
  ];

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  Future<void> _handleNext() async {
    if (_currentPage < _slides.length - 1) {
      if (_slides[_currentPage].isPermissionSlide) {
        await NotificationService.instance.requestPermissionIfNeeded();
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final themeService = context.read<ThemeService>();
    await themeService.completeOnboarding();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      buildAppRoute(const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.select((ThemeService s) => AppTheme.paletteOf(s.currentTheme));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.backgroundTop,
              palette.backgroundBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: slide.color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(slide.icon, size: 80, color: slide.color),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: palette.seed,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            slide.subtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: palette.textMuted,
                              height: 1.5,
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
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? palette.seed : palette.seed.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    MainCta(
                      title: _currentPage == _slides.length - 1 ? 'Get Started' : 'Continue',
                      subtitle: _currentPage == 2 ? 'We will ask for permission' : 'Swipe to learn more',
                      badgeLabel: _currentPage == _slides.length - 1 ? 'READY' : 'SETUP',
                      onTap: _handleNext,
                      accentColor: palette.seed,
                    ),
                    if (_currentPage < _slides.length - 1)
                      TextButton(
                        onPressed: _finishOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(color: palette.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isPermissionSlide;

  const _OnboardingSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isPermissionSlide = false,
  });
}
