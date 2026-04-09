import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mood_aggregator.dart';

class LocalAiPlugin {
  LocalAiPlugin._();

  static final LocalAiPlugin instance = LocalAiPlugin._();

  Future<void> initialize() async {
    await FlutterGemma.initialize();
  }
}

enum AiModelVariant {
  gemma4('Gemma 4 E2B', 'gemma_4_e2b.task', 'https://storage.googleapis.com/mediapipe-models/gemma-4-e2b-it-gpu-int4.task', '1.3 GB'),
  gemma2b('Gemma 2B Base', 'gemma_2b_base.task', 'https://storage.googleapis.com/mediapipe-models/gemma-2b-it-gpu-int4.task', '1.4 GB'),
  phi2('Phi-2 (Microsoft)', 'phi2_cpu.task', 'https://storage.googleapis.com/mediapipe-models/phi-2-gpu-int4.task', '1.5 GB');

  final String label;
  final String fileName;
  final String url;
  final String estimate;

  const AiModelVariant(this.label, this.fileName, this.url, this.estimate);
}

class AiService {
  AiService._();

  static final AiService instance = AiService._();

  static const _activeModelKey = 'ai_active_model_variant';

  Future<void> initialize() async {
    await LocalAiPlugin.instance.initialize();
  }

  Future<AiModelVariant> getActiveVariant() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_activeModelKey);
    return AiModelVariant.values.firstWhere(
      (v) => v.name == name,
      orElse: () => AiModelVariant.gemma4,
    );
  }

  Future<void> setActiveVariant(AiModelVariant variant) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeModelKey, variant.name);
    _chatModel = null;
  }

  Future<String> getModelPath(AiModelVariant variant) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${variant.fileName}';
  }

  Future<Map<String, dynamic>> getModelMetadata(AiModelVariant variant) async {
    try {
      final path = await getModelPath(variant);
      final file = File(path);
      final exists = await file.exists();
      
      String size = '--';
      if (exists) {
        final bytes = await file.length();
        size = '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
      }

      return {
        'path': path,
        'size': size,
        'exists': exists,
      };
    } catch (e) {
      debugPrint('AiService: getModelMetadata error: $e');
      return {
        'path': 'error',
        'size': '--',
        'exists': false,
      };
    }
  }

  bool _isInitialising = false;
  bool _isDownloading = false;
  InferenceModel? _chatModel;

  Future<bool> isModelDownloaded(AiModelVariant variant) async {
    final path = await getModelPath(variant);
    return File(path).exists();
  }

  Future<bool> _ensureInitialised() async {
    if (_chatModel != null) return true;
    if (_isInitialising) return false;
    
    final variant = await getActiveVariant();
    if (!await isModelDownloaded(variant)) return false;

    _isInitialising = true;
    try {
      final path = await getModelPath(variant);
      
      // Modern API: Install from file then get active model
      await FlutterGemma.installModel(
        modelType: variant == AiModelVariant.phi2 ? ModelType.phi : ModelType.gemmaIt,
      ).fromFile(path).install();

      _chatModel = await FlutterGemma.getActiveModel();
      
      return true;
    } catch (error) {
      debugPrint('AiService initialisation failed: $error');
      return false;
    } finally {
      _isInitialising = false;
    }
  }

  Future<void> downloadModel({
    required AiModelVariant variant,
    required void Function(double) onProgress,
    required void Function() onComplete,
    required void Function(String) onError,
  }) async {
    if (_isDownloading) {
      onError('A model download is already in progress.');
      return;
    }

    _isDownloading = true;
    try {
      // Modern API: use installModel().fromNetwork().withProgress().install()
      await FlutterGemma.installModel(
        modelType: variant == AiModelVariant.phi2 ? ModelType.phi : ModelType.gemmaIt,
      ).fromNetwork(variant.url).withProgress(
        (progress) => onProgress(progress / 100),
      ).install();
      onComplete();
    } catch (error) {
      onError(error.toString());
    } finally {
      _isDownloading = false;
    }
  }

  // Common Inference Methods
  Future<String> instantInsight({
    required String moodLabel,
    required int intensity,
    String? note,
  }) async {
    final ready = await _ensureInitialised();
    if (!ready) return _fallback(moodLabel.toLowerCase());

    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : hour < 21 ? 'evening' : 'night';

    final prompt = '''<start_of_turn>user
Mood logged: $moodLabel at intensity $intensity/10.
Time: $timeOfDay.
${note != null && note.isNotEmpty ? 'Note: "$note"' : ''}
Give one warm, specific observation in 1-2 sentences.
Be encouraging, never clinical.<end_of_turn>
<start_of_turn>model
''';
    return await _runInference(prompt, moodLabel.toLowerCase());
  }

  Future<String> dailyInsight({
    required DayAggregate aggregate,
    required int streakDays,
  }) async {
    final ready = await _ensureInitialised();
    if (!ready) return _fallback(aggregate.dominantMood);

    final notesText = aggregate.notes.isEmpty ? 'none' : aggregate.notes.join(', ');

    final prompt = '''<start_of_turn>user
Today's mood summary:
- Entries: ${aggregate.entryCount}
- Dominant mood: ${aggregate.dominantMood}
- Average intensity: ${aggregate.avgIntensity}/10
- Emotional arc: ${aggregate.arc}
- Notes: $notesText
- Streak: $streakDays days
Give one observation and one small suggestion for tomorrow.
Max 3 sentences. Be warm and encouraging.<end_of_turn>
<start_of_turn>model
''';
    return await _runInference(prompt, aggregate.dominantMood);
  }

  Future<String> weeklyInsight({required Map<String, dynamic> aggregate}) async {
    final ready = await _ensureInitialised();
    if (!ready) return "You've had a consistent week of logging. Take a moment to appreciate your effort.";

    final prompt = '''<start_of_turn>user
Review my last 7 days of moods:
- Top mood: ${aggregate['dominantMood']}
- Avg intensity: ${aggregate['avgIntensity']}/10
- Total logs: ${aggregate['entryCount']}
- Mood distribution: ${aggregate['moodDistribution']}
- Selected notes: ${aggregate['notes'].join('; ')}
Give me a supportive summary of my week and one thing to try next week. Max 3 sentences.<end_of_turn>
<start_of_turn>model
''';
    return await _runInference(prompt, 'weekly');
  }

  Future<String> monthlyInsight({required Map<String, dynamic> aggregate}) async {
    final ready = await _ensureInitialised();
    if (!ready) return "A whole month of check-ins! That is incredible dedication to your mental wellbeing.";

    final prompt = '''<start_of_turn>user
Review my last 30 days of moods:
- Top mood: ${aggregate['dominantMood']}
- Avg intensity: ${aggregate['avgIntensity']}/10
- Total logs: ${aggregate['entryCount']}
- Notes history: ${aggregate['notes'].join('; ')}
Explain the biggest theme you see in my month and give one long-term encouragement. Max 4 sentences.<end_of_turn>
<start_of_turn>model
''';
    return await _runInference(prompt, 'monthly');
  }

  Future<String> generateDailyTip({required String lastMood}) async {
    final ready = await _ensureInitialised();
    if (!ready) return "Try taking five deep breaths today - it's a simple way to reset.";

    final prompt = '''<start_of_turn>user
My last logged mood was "$lastMood".
Give me one very short, actionable mental health tip for tomorrow based on this.
Max 12 words. Be warm.<end_of_turn>
<start_of_turn>model
''';
    return await _runInference(prompt, 'tip');
  }

  Future<String> chat({required List<Map<String, String>> history, String? todayMood}) async {
    final ready = await _ensureInitialised();
    if (!ready) return "I'm still getting ready. Is there anything else you'd like to share?";

    final systemPrompt = "You are 'ME', a compassionate mental health companion. "
        "You are non-clinical, supportive, and focus on emotional awareness. "
        "${todayMood != null ? "Today, the user feels '$todayMood'." : ""} "
        "Keep responses brief (max 60 words).";

    final chatBuffer = StringBuffer('<start_of_turn>user\n$systemPrompt\n');
    for (final turn in history) {
      final role = turn['role'] == 'user' ? 'user' : 'model';
      chatBuffer.write('<start_of_turn>$role\n${turn['content']}<end_of_turn>\n');
    }
    chatBuffer.write('<start_of_turn>model\n');
    
    try {
      // Aggregate the stream into a single string for legacy compatibility
      final session = await _chatModel?.createChat(
        temperature: 0.7,
        randomSeed: 42,
        topK: 40,
      );
      
      if (session == null) return _fallback('chat');
      
      // Add the user query to the context first
      await session.addQueryChunk(Message.text(text: chatBuffer.toString(), isUser: true));
      
      final responseStream = session.generateChatResponseAsync();
      
      final buffer = StringBuffer();
      await for (final response in responseStream) {
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }
      
      final result = buffer.toString();
      return result.trim().isNotEmpty ? result.trim() : _fallback('chat');
    } catch (error) {
      debugPrint('AiService chat failed: $error');
      return _fallback('chat');
    }
  }

  Future<String> _runInference(String prompt, String moodId) async {
    try {
      // Create a ephemeral session for one-shot inference
      final session = await _chatModel?.createChat(
        temperature: 0.7,
        randomSeed: 42,
        topK: 40,
      );
      
      if (session == null) return _fallback(moodId);
      
      // Add the prompt to the context first
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      
      final responseStream = session.generateChatResponseAsync();
      
      final buffer = StringBuffer();
      await for (final response in responseStream) {
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }
      
      final result = buffer.toString();
      return result.trim().isNotEmpty ? result.trim() : _fallback(moodId);
    } catch (error) {
      debugPrint('AiService inference failed: $error');
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
    return fallbacks[moodId.toLowerCase()] ?? 'Every log is a step toward self-awareness. Keep going.';
  }

  Future<void> reset() async {
    _isInitialising = false;
    _isDownloading = false;
    _chatModel = null;
    // Note: Modern API handles model lifecycle internally
  }
}
