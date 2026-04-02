import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_routes.dart';
import '../../../core/app_theme.dart';
import '../../../core/services/theme_service.dart';
import '../micro_interactions.dart';
import '../mood_catalog.dart';
import '../mood_slider.dart';
import '../widgets/mood_option_card.dart';
import 'mind_question_screen.dart';

class MoodSelectionScreen extends StatefulWidget {
  const MoodSelectionScreen({super.key});

  @override
  State<MoodSelectionScreen> createState() => _MoodSelectionScreenState();
}

class _MoodSelectionScreenState extends State<MoodSelectionScreen> {
  MoodOption? _selectedMood;
  int _intensity = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'How are you feeling today?',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Choose one mood, set the intensity, and we will guide the reflection.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                      const SizedBox(height: 32),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: mindMoodOptions.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final mood = mindMoodOptions[index];
                          return MoodOptionCard(
                            mood: mood,
                            isSelected: mood == _selectedMood,
                            onTap: () {
                              setState(() => _selectedMood = mood);
                            },
                          );
                        },
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        child: _selectedMood == null
                            ? const SizedBox(height: 24)
                            : Padding(
                                key: ValueKey<String>(_selectedMood!.id),
                                padding: const EdgeInsets.only(top: 28),
                                child: MoodIntensitySlider(
                                  value: _intensity,
                                  color: _selectedMood!.color,
                                  onChanged: (value) {
                                    setState(() => _intensity = value);
                                  },
                                ),
                              ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedActionButton(
                        label: 'Continue',
                        onPressed: _selectedMood == null
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  buildAppRoute(
                                    MindQuestionScreen(
                                      mood: _selectedMood!,
                                      intensity: _intensity,
                                    ),
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
