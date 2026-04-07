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
  final TextEditingController _customMoodController = TextEditingController();

  MoodOption? _selectedMood;
  int _intensity = 5;

  MoodOption get _customMood => mindMoodOptions.firstWhere((mood) => mood.isCustom);

  List<MoodOption> get _gridMoods =>
      mindMoodOptions.where((mood) => !mood.isCustom).toList(growable: false);

  MoodOption? get _effectiveSelectedMood {
    final selectedMood = _selectedMood;
    if (selectedMood == null) {
      return null;
    }

    if (!selectedMood.isCustom) {
      return selectedMood;
    }

    final customLabel = _customMoodController.text.trim();
    return selectedMood.copyWith(
      label: customLabel.isEmpty ? selectedMood.label : customLabel,
    );
  }

  bool get _canContinue {
    if (_selectedMood == null) {
      return false;
    }

    if (_selectedMood!.isCustom) {
      return _customMoodController.text.trim().isNotEmpty;
    }

    return true;
  }

  @override
  void dispose() {
    _customMoodController.dispose();
    super.dispose();
  }

  void _toggleMood(MoodOption mood) {
    if (_selectedMood?.id == mood.id) {
      setState(() {
        _selectedMood = null;
        if (mood.isCustom) {
          _customMoodController.clear();
        }
      });
      return;
    }

    setState(() => _selectedMood = mood);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.select(
      (ThemeService settings) => AppTheme.paletteOf(settings.currentTheme),
    );
    final selectedMood = _effectiveSelectedMood;

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
              final contentWidth = constraints.maxWidth - 40;
              final crossAxisCount = contentWidth < 520 ? 3 : 4;

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
                              color: palette.textMuted,
                            ),
                      ),
                      const SizedBox(height: 28),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _gridMoods.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                        itemBuilder: (context, index) {
                          final mood = _gridMoods[index];
                          return MoodOptionCard(
                            mood: mood,
                            isSelected: _selectedMood?.id == mood.id,
                            onTap: () => _toggleMood(mood),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      MoodOptionCard(
                        mood: _customMood,
                        isSelected: _selectedMood?.id == _customMood.id,
                        isWide: true,
                        onTap: () => _toggleMood(_customMood),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        child: _selectedMood?.isCustom != true
                            ? const SizedBox.shrink()
                            : Padding(
                                key: const ValueKey('custom-mood-input'),
                                padding: const EdgeInsets.only(top: 12),
                                child: TextField(
                                  controller: _customMoodController,
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    hintText: 'Describe your mood...',
                                    prefixIcon: Icon(
                                      Icons.edit_outlined,
                                      color: _customMood.color,
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        child: selectedMood == null
                            ? const SizedBox(height: 24)
                            : Padding(
                                key: ValueKey<String>(
                                  '${selectedMood.id}-${selectedMood.label}',
                                ),
                                padding: const EdgeInsets.only(top: 28),
                                child: MoodIntensitySlider(
                                  value: _intensity,
                                  color: selectedMood.color,
                                  onChanged: (value) {
                                    setState(() => _intensity = value);
                                  },
                                ),
                              ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedActionButton(
                        label: 'Continue',
                        backgroundColor: selectedMood?.color,
                        glowColor: selectedMood?.color,
                        onPressed: !_canContinue || selectedMood == null
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  buildAppRoute(
                                    MindQuestionScreen(
                                      mood: selectedMood,
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
