import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mood_aggregator.dart';

class GemmaService {
  GemmaService._();

  static final GemmaService instance = GemmaService._();

  static const String _modelUrl =
      'https://storage.googleapis.com/mediapipe-models/'
      'gemma-4-e2b-it-gpu-int4.task';

  bool _isInitialised = false;

  Future<bool> isModelDownloaded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('model_downloaded') ?? false;
  }

  Future<void> initialise() async {
    if (_isInitialised || !await isModelDownloaded()) {
      return;
    }

    try {
      await FlutterGemmaPlugin.instance.init(
        maxTokens: 200,
        temperature: 0.7,
        topK: 40,
        randomSeed: 42,
      );
      _isInitialised = true;
    } catch (error) {
      debugPrint('GemmaService.initialise failed: $error');
    }
  }

  Future<void> downloadModel({
    required void Function(double) onProgress,
    required void Function() onComplete,
    required void Function(String) onError,
  }) async {
    try {
      final completer = Completer<void>();
      late final StreamSubscription<int> subscription;
      subscription = FlutterGemmaPlugin.instance
          .loadNetworkModelWithProgress(url: _modelUrl)
          .listen(
        (progress) {
          onProgress((progress / 100).clamp(0.0, 1.0));
        },
        onError: (Object error) async {
          await subscription.cancel();
          onError(error.toString());
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () async {
          await subscription.cancel();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('model_downloaded', true);
          await initialise();
          onComplete();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );
      await completer.future;
    } catch (error) {
      onError(error.toString());
    }
  }

  Future<String> instantInsight({
    required String moodLabel,
    required int intensity,
    String? note,
  }) async {
    if (!_isInitialised) {
      return _fallback(moodLabel.toLowerCase());
    }

    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'morning'
        : hour < 17
            ? 'afternoon'
            : hour < 21
                ? 'evening'
                : 'night';

    final prompt = '''
Mood just logged: $moodLabel at intensity $intensity/10.
Time: $timeOfDay.
${note != null && note.isNotEmpty ? 'Note: "$note"' : ''}
Give one warm, specific observation about this mood moment in 1-2 sentences. Be encouraging, never clinical.
''';

    return _runInference(prompt, moodLabel.toLowerCase());
  }

  Future<String> dailyInsight({
    required DayAggregate aggregate,
    required int streakDays,
  }) async {
    if (!_isInitialised) {
      return _fallback(aggregate.dominantMood);
    }

    final notesText = aggregate.notes.isEmpty ? 'none' : aggregate.notes.join(', ');
    final prompt = '''
Today's mood summary:
- Entries logged: ${aggregate.entryCount}
- Dominant mood: ${aggregate.dominantMood}
- Average intensity: ${aggregate.avgIntensity}/10
- Emotional arc: ${aggregate.arc}
- Notes: $notesText
- Current streak: $streakDays days

Give one specific observation about today's pattern and one small actionable suggestion for tomorrow. Max 3 sentences. Be warm and encouraging.
''';

    return _runInference(prompt, aggregate.dominantMood);
  }

  Future<String> _runInference(String prompt, String moodId) async {
    try {
      final result = await FlutterGemmaPlugin.instance.getResponse(prompt: prompt);
      return result?.trim().isNotEmpty == true ? result!.trim() : _fallback(moodId);
    } catch (error) {
      debugPrint('GemmaService inference failed: $error');
      return _fallback(moodId);
    }
  }

  String _fallback(String moodId) {
    const fallbacks = {
      'happy': "You're on a good wave today - carry that into tomorrow.",
      'grateful': "Gratitude is a superpower. You're practising it well.",
      'energised': "Great energy today. Make sure you rest well tonight.",
      'calm': "Calm days build resilience. Well done for noticing.",
      'okay': "Okay days are valid. Tomorrow is a fresh start.",
      'meh': "Flat days happen. One small win tomorrow is enough.",
      'focused': "Focus is rare - you found it today. Note what helped.",
      'tired': "Your body is asking for rest. Honour that tonight.",
      'anxious': "Anxious days are tough. Try 3 slow breaths before sleep.",
      'stressed': "You pushed through a demanding day. Rest is productive too.",
      'sad': "It's okay to feel this. Be gentle with yourself today.",
    };

    return fallbacks[moodId] ??
        'Every log is a step toward self-awareness. Keep going.';
  }

  Future<void> reset() async {
    _isInitialised = false;
    try {
      await FlutterGemmaPlugin.instance.close();
    } catch (_) {
      // Closing is best-effort because the model may not be active.
    }
  }
}
