import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../core/services/theme_service.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveAndContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    
    // Save to SharedPreferences for ContextBuilder and legacy logic
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setBool('profile_setup_complete', true);
    
    // Also save via ThemeService if needed
    await ThemeService.instance.setUserName(name);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        buildAppRoute(const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppTheme.paletteOf(ThemeService.instance.currentTheme);

    return Scaffold(
      backgroundColor: palette.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.seed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.face_retouching_natural_rounded, color: palette.accent, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                "Let's get introduced.",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "What should I call you? I'll use this to personalize our conversations.",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: palette.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: theme.textTheme.titleLarge,
                decoration: InputDecoration(
                  hintText: 'Your name',
                  hintStyle: TextStyle(color: palette.seed.withValues(alpha: 0.2)),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: palette.seed.withValues(alpha: 0.1), width: 2),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: palette.accent, width: 2),
                  ),
                ),
                onSubmitted: (_) => _saveAndContinue(),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveAndContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF534AB7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('profile_setup_complete', true);
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      buildAppRoute(const HomeScreen()),
                    );
                  },
                  child: Text(
                    'Skip for now',
                    style: TextStyle(color: palette.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
