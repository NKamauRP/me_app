import 'package:flutter/material.dart';

import '../../models/mood_log.dart';

class MoodOption {
  const MoodOption({
    required this.id,
    required this.label,
    required this.emoji,
    required this.prompts,
    required this.color,
    required this.icon,
  });

  final String id;
  final String label;
  final String emoji;
  final List<String> prompts;
  final Color color;
  final IconData icon;

  String promptForIntensity(int intensity) {
    if (prompts.isEmpty) {
      return 'What stood out for you today?';
    }

    if (intensity >= 8) {
      return prompts.last;
    }

    if (intensity >= 5) {
      return prompts[prompts.length > 1 ? 1 : 0];
    }

    return prompts.first;
  }
}

const List<MoodOption> mindMoodOptions = [
  MoodOption(
    id: 'stress',
    label: 'Stress',
    emoji: '\u{1F635}',
    prompts: <String>[
      'What is causing your stress today?',
      'What feels most important to release right now?',
      'What would make today feel 10% lighter?',
    ],
    color: Color(0xFFE77752),
    icon: Icons.psychology_alt_rounded,
  ),
  MoodOption(
    id: 'happy',
    label: 'Happy',
    emoji: '\u{1F60A}',
    prompts: <String>[
      'What made you feel good today?',
      'What moment do you want to remember from today?',
      'How can you carry this energy into tomorrow?',
    ],
    color: Color(0xFFF5B94A),
    icon: Icons.wb_sunny_rounded,
  ),
  MoodOption(
    id: 'anxious',
    label: 'Anxious',
    emoji: '\u{1F62C}',
    prompts: <String>[
      'What is making you feel uneasy today?',
      'What thought is asking for your attention right now?',
      'What would help you feel safer in this moment?',
    ],
    color: Color(0xFF7C86F7),
    icon: Icons.favorite_outline_rounded,
  ),
  MoodOption(
    id: 'tired',
    label: 'Tired',
    emoji: '\u{1F634}',
    prompts: <String>[
      'What drained your energy today?',
      'Where did your energy go most today?',
      'What kind of rest would actually help tonight?',
    ],
    color: Color(0xFF4F9B93),
    icon: Icons.nightlight_round,
  ),
];

MoodOption moodOptionById(String id) {
  return mindMoodOptions.firstWhere(
    (mood) => mood.id == id,
    orElse: () => mindMoodOptions.first,
  );
}

double moodWellbeingScore(MoodLog moodLog) {
  switch (moodLog.mood) {
    case 'happy':
      return 6 + (moodLog.intensity * 0.4);
    case 'tired':
      return 6 - (moodLog.intensity * 0.25);
    case 'stress':
      return 5.5 - (moodLog.intensity * 0.35);
    case 'anxious':
      return 5.2 - (moodLog.intensity * 0.35);
    default:
      return 5;
  }
}
