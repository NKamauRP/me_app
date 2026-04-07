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
    this.isCustom = false,
  });

  final String id;
  final String label;
  final String emoji;
  final List<String> prompts;
  final Color color;
  final IconData icon;
  final bool isCustom;

  String get hexColor =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  MoodOption copyWith({
    String? id,
    String? label,
    String? emoji,
    List<String>? prompts,
    Color? color,
    IconData? icon,
    bool? isCustom,
  }) {
    return MoodOption(
      id: id ?? this.id,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      prompts: prompts ?? this.prompts,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isCustom: isCustom ?? this.isCustom,
    );
  }

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

const Color _amberMood = Color(0xFFFAC775);
const Color _tealMood = Color(0xFF9FE1CB);
const Color _grayMood = Color(0xFFB4B2A9);
const Color _purpleMood = Color(0xFFAFA9EC);
const Color _blueMood = Color(0xFF85B7EB);
const Color _redMood = Color(0xFFF09595);

const List<MoodOption> mindMoodOptions = [
  MoodOption(
    id: 'happy',
    label: 'Happy',
    emoji: '\u{1F60A}',
    prompts: <String>[
      'What made today feel bright?',
      'What do you want to hold onto from this moment?',
      'How can you carry this energy into the rest of your day?',
    ],
    color: _amberMood,
    icon: Icons.wb_sunny_rounded,
  ),
  MoodOption(
    id: 'grateful',
    label: 'Grateful',
    emoji: '\u{1F64F}',
    prompts: <String>[
      'What are you grateful for right now?',
      'Who or what supported you today?',
      'How did this gratitude shift your perspective today?',
    ],
    color: _tealMood,
    icon: Icons.favorite_rounded,
  ),
  MoodOption(
    id: 'energised',
    label: 'Energised',
    emoji: '\u26A1',
    prompts: <String>[
      'What is giving you energy today?',
      'Where do you want to direct this energy next?',
      'What would help you use this momentum well?',
    ],
    color: _amberMood,
    icon: Icons.bolt_rounded,
  ),
  MoodOption(
    id: 'calm',
    label: 'Calm',
    emoji: '\u{1F60C}',
    prompts: <String>[
      'What is helping you feel steady today?',
      'What part of today feels peaceful?',
      'How can you protect this calm for a little longer?',
    ],
    color: _tealMood,
    icon: Icons.spa_rounded,
  ),
  MoodOption(
    id: 'okay',
    label: 'Okay',
    emoji: '\u{1F610}',
    prompts: <String>[
      'What feels ordinary but important today?',
      'What would make today feel a bit better?',
      'What are you noticing beneath “okay”?',
    ],
    color: _grayMood,
    icon: Icons.thumbs_up_down_rounded,
  ),
  MoodOption(
    id: 'meh',
    label: 'Meh',
    emoji: '\u{1F611}',
    prompts: <String>[
      'What feels flat or uninteresting today?',
      'What are you low on right now?',
      'What small thing might help shift this feeling?',
    ],
    color: _grayMood,
    icon: Icons.sentiment_neutral_rounded,
  ),
  MoodOption(
    id: 'focused',
    label: 'Focused',
    emoji: '\u{1F3AF}',
    prompts: <String>[
      'What has your full attention today?',
      'What are you making progress on right now?',
      'How can you protect your focus for the rest of the day?',
    ],
    color: _purpleMood,
    icon: Icons.track_changes_rounded,
  ),
  MoodOption(
    id: 'tired',
    label: 'Tired',
    emoji: '\u{1F634}',
    prompts: <String>[
      'What drained your energy today?',
      'What kind of rest do you need most right now?',
      'What would help you feel 10% more restored?',
    ],
    color: _blueMood,
    icon: Icons.bedtime_rounded,
  ),
  MoodOption(
    id: 'anxious',
    label: 'Anxious',
    emoji: '\u{1F630}',
    prompts: <String>[
      'What is making you feel uneasy today?',
      'What thought keeps circling right now?',
      'What would help you feel safer in this moment?',
    ],
    color: _redMood,
    icon: Icons.favorite_outline_rounded,
  ),
  MoodOption(
    id: 'stressed',
    label: 'Stressed',
    emoji: '\u{1F624}',
    prompts: <String>[
      'What is putting pressure on you today?',
      'What feels most urgent right now?',
      'What can you release or simplify first?',
    ],
    color: _redMood,
    icon: Icons.psychology_alt_rounded,
  ),
  MoodOption(
    id: 'sad',
    label: 'Sad',
    emoji: '\u{1F622}',
    prompts: <String>[
      'What feels heavy today?',
      'What happened that touched this sadness?',
      'What kind of comfort would help right now?',
    ],
    color: _blueMood,
    icon: Icons.cloud_rounded,
  ),
  MoodOption(
    id: 'custom',
    label: 'Custom',
    emoji: '\u270F\uFE0F',
    prompts: <String>[
      'What word best describes your mood today?',
      'What is this mood asking you to notice?',
      'How would you describe this feeling in your own words?',
    ],
    color: _purpleMood,
    icon: Icons.edit_rounded,
    isCustom: true,
  ),
];

MoodOption moodOptionById(String id) {
  final normalizedId = switch (id) {
    'stress' => 'stressed',
    _ => id,
  };

  return mindMoodOptions.firstWhere(
    (mood) => mood.id == normalizedId,
    orElse: () => mindMoodOptions.first,
  );
}

double moodWellbeingScore(MoodLog moodLog) {
  switch (moodLog.mood) {
    case 'happy':
      return 6.6 + (moodLog.intensity * 0.32);
    case 'grateful':
      return 6.5 + (moodLog.intensity * 0.28);
    case 'energised':
      return 6.3 + (moodLog.intensity * 0.35);
    case 'calm':
      return 6.2 + (moodLog.intensity * 0.26);
    case 'focused':
      return 6.0 + (moodLog.intensity * 0.24);
    case 'okay':
      return 5.6 + (moodLog.intensity * 0.08);
    case 'meh':
      return 5.0 - (moodLog.intensity * 0.10);
    case 'tired':
      return 5.1 - (moodLog.intensity * 0.24);
    case 'sad':
      return 4.9 - (moodLog.intensity * 0.30);
    case 'anxious':
      return 4.8 - (moodLog.intensity * 0.34);
    case 'stress':
    case 'stressed':
      return 4.7 - (moodLog.intensity * 0.35);
    default:
      return 5;
  }
}
