import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_routes.dart';
import '../../../core/app_theme.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../micro_interactions.dart';
import '../mood_catalog.dart';
import '../providers/mind_me_provider.dart';
import '../reflection_prompt.dart';
import 'mind_result_screen.dart';

class MindQuestionScreen extends StatefulWidget {
  const MindQuestionScreen({
    super.key,
    required this.mood,
    required this.intensity,
  });

  final MoodOption mood;
  final int intensity;

  @override
  State<MindQuestionScreen> createState() => _MindQuestionScreenState();
}

class _MindQuestionScreenState extends State<MindQuestionScreen> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a short answer before submitting.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    MindHaptics.confirm();

    try {
      final result = await context.read<MindMeProvider>().submitMood(
            mood: widget.mood,
            intensity: widget.intensity,
            note: _noteController.text,
          );
      await SoundService.instance.playSuccess();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        buildAppRoute(
          MindResultScreen(
            mood: widget.mood,
            result: result,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while saving your check-in.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prompt = widget.mood.promptForIntensity(widget.intensity);
    final palette =
        context.select((ThemeService settings) => AppTheme.paletteOf(settings.currentTheme));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mind Me'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.backgroundTop,
              palette.backgroundBottom,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              GlassPanel(
                padding: const EdgeInsets.all(20),
                tint: widget.mood.color.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: widget.mood.color.withValues(alpha: 0.16),
                      child: Text(
                        widget.mood.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.mood.label,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Intensity ${widget.intensity}/10',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: widget.mood.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ReflectionPromptCard(
                prompt: prompt,
                intensity: widget.intensity,
                color: widget.mood.color,
                textController: _noteController,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: widget.mood.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: widget.mood.color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.intensity >= 7
                            ? 'Big feelings deserve a gentle answer.'
                            : 'A short note is enough to make today visible.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AnimatedActionButton(
                label: 'Submit check-in',
                icon: Icons.check_circle_outline_rounded,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
