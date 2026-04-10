import 'package:shared_preferences/shared_preferences.dart';
import '../data/chat_database.dart';

class ContextBuilder {
  static final ContextBuilder instance = ContextBuilder._();
  ContextBuilder._();

  /// Builds a rich system prompt for the companion chat.
  ///
  /// [sessionTitle] is the current conversation topic so the
  /// model knows what thread it is in.
  Future<String> buildSystemPrompt({
    String? sessionTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final memory = await ChatDatabase.instance.getAllMemory();

    // ── User identity ──────────────────────────────────────────
    final userName = memory['user_name'] ??
        prefs.getString('user_name') ??
        'there';
    final preferredName = memory['preferred_name'] ?? userName;

    // ── Time of day greeting ───────────────────────────────────
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'morning'
        : hour < 17
            ? 'afternoon'
            : hour < 21
                ? 'evening'
                : 'night';

    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : hour < 21
                ? 'Good evening'
                : 'Hey';

    // ── Mood context ───────────────────────────────────────────
    final lastMood = prefs.getString('last_logged_mood') ?? '';
    final moodContext = lastMood.isNotEmpty
        ? 'Their most recently logged mood is "$lastMood".'
        : 'They have not logged a mood today yet.';

    // ── Streak and XP ──────────────────────────────────────────
    final streak = prefs.getInt('streak_days') ?? 0;
    final level = prefs.getInt('user_level') ?? 1;
    final streakContext = streak > 0
        ? 'They are on a $streak-day logging streak (Level $level).'
        : 'They have not started a streak yet.';

    // ── Important memories ─────────────────────────────────────
    // Anything saved via saveMemory() appears here automatically
    final memoryLines = memory.entries
        .where((e) =>
            e.key != 'user_name' && e.key != 'preferred_name')
        .map((e) => '- ${e.key}: ${e.value}')
        .join('\n');

    final memorySection = memoryLines.isNotEmpty
        ? 'Things you remember about this user:\n$memoryLines'
        : '';

    // ── Session context ────────────────────────────────────────
    final sessionContext = sessionTitle != null
        ? 'The current conversation is titled: "$sessionTitle".'
        : '';

    // ── Compose final prompt ───────────────────────────────────
    return '''
You are ME, a warm, compassionate mental health companion inside a mood logging app.
Your role is to support $preferredName's emotional wellbeing through conversation.

USER CONTEXT:
- Name: $preferredName
- Time of day: $timeOfDay ($greeting, $preferredName)
- $moodContext
- $streakContext
$sessionContext
$memorySection

BEHAVIOUR RULES:
- Always address the user as $preferredName naturally (not every message).
- Reference their mood or streak only when relevant — do not force it.
- Be warm, brief, and conversational. Max 60 words per response.
- Ask one thoughtful follow-up question when appropriate.
- Never give clinical diagnoses or medical advice.
- If the user shares something important (name preference, life event,
  trigger, goal), remember it internally and reference it naturally later.
- Stay focused on emotional wellbeing. If asked about unrelated topics
  (coding, news, maths), gently redirect:
  "That's a bit outside my lane — I'm here for how you're feeling. 
   Want to talk about that instead?"
- Never break character. You are always ME, never "an AI" or "a language model".
'''.trim();
  }

  /// Generates 3 context-aware conversation starters.
  /// These are rule-based — no AI inference needed.
  Future<List<String>> buildStarters({String? lastMood}) async {
    final prefs = await SharedPreferences.getInstance();
    final memory = await ChatDatabase.instance.getAllMemory();
    final name = memory['preferred_name'] ??
        prefs.getString('user_name') ??
        '';
    final namePrefix = name.isNotEmpty ? '$name, ' : '';
    final hour = DateTime.now().hour;
    final streak = prefs.getInt('streak_days') ?? 0;
    final mood = lastMood ?? prefs.getString('last_logged_mood') ?? '';

    // Morning starters
    if (hour < 12) {
      return [
        '${namePrefix}how are you feeling this morning?',
        'What does today have in store for you?',
        'Is there anything on your mind before the day begins?',
      ];
    }

    // Mood-aware starters
    if (mood == 'anxious' || mood == 'stressed') {
      return [
        "You logged $mood earlier — want to talk about what's going on?",
        'What\'s been the heaviest part of your day so far?',
        'Sometimes just naming it helps. What\'s weighing on you?',
      ];
    }

    if (mood == 'happy' || mood == 'grateful' || mood == 'energised') {
      return [
        "You're on a good wave today — what's been going well?",
        'What made you smile today?',
        '${namePrefix}what are you feeling grateful for right now?',
      ];
    }

    if (mood == 'tired') {
      return [
        "You logged tired — has it been a draining day?",
        'What would help you wind down tonight?',
        'Rest is important. What does your body need right now?',
      ];
    }

    // Streak-aware starters
    if (streak >= 7) {
      return [
        '$streak days in a row — that\'s real commitment. How are you doing?',
        'You\'ve been showing up consistently. What\'s keeping you going?',
        'What has this week felt like emotionally for you?',
      ];
    }

    // Evening / night fallback
    if (hour >= 20) {
      return [
        '${namePrefix}how did today treat you?',
        'What\'s one thing you want to leave behind from today?',
        'What are you carrying into tomorrow?',
      ];
    }

    // Generic afternoon fallback
    return [
      '${namePrefix}how are you doing right now?',
      'What\'s on your mind today?',
      'Is there anything you want to talk through?',
    ];
  }
}
