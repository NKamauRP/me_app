import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/services/theme_service.dart';
import '../features/mind/providers/mind_me_provider.dart';
import '../services/ai_service.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    await context.read<MindMeProvider>().initialize();
    
    // Check if a background download was left active and re-attach
    unawaited(AiService.instance.resumeActiveDownload());

    await Future<void>.delayed(const Duration(milliseconds: 1600));

    if (!mounted) {
      return;
    }

    final themeService = context.read<ThemeService>();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final isSetupComplete = prefs.getBool('profile_setup_complete') ?? false;

    if (themeService.isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        buildAppRoute(const OnboardingScreen()),
      );
    } else if (!isSetupComplete) {
      Navigator.of(context).pushReplacementNamed('/profile_setup');
    } else {
      Navigator.of(context).pushReplacement(
        buildAppRoute(const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        context.select((ThemeService settings) => AppTheme.paletteOf(settings.currentTheme));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.heroTop,
              palette.heroBottom,
              palette.accent,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 108,
                width: 108,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'ME',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Mind Me',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Show up for one minute today.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
