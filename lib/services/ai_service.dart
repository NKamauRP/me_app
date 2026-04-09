import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mood_aggregator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model catalogue
// ─────────────────────────────────────────────────────────────────────────────

/// All on-device models the app supports.
///
/// URLs point to HuggingFace `litert-community` public repos so no
/// authentication token is required by default.
enum AiModelVariant {
  gemma4(
    'Gemma 4 E2B',
    'gemma_4_e2b.task',
    // Public litert-community build — no HF token needed
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-int4.task',
    '~1.3 GB',
    ModelType.gemmaIt,
  ),
  gemma3(
    'Gemma 3 1B',
    'gemma_3_1b.task',
    // Gated litert-community build — HF token required
    'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
    '~600 MB',
    ModelType.gemmaIt,
  ),
  phi4(
    'Phi-4 Mini',
    'phi4_mini.task',
    // Public litert-community build — no HF token needed
    'https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/phi-4-mini-instruct-int4.task',
    '~2.3 GB',
    ModelType.general,
  );

  final String label;
  final String fileName;
  final String url;
  final String estimate;
  final ModelType modelType;

  const AiModelVariant(
    this.label,
    this.fileName,
    this.url,
    this.estimate,
    this.modelType,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AiService
// ─────────────────────────────────────────────────────────────────────────────

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const _activeModelKey = 'ai_active_model_variant';

  InferenceModel? _chatModel;
  bool _isInitialising = false;
  bool _isDownloading = false;

  // ── lifecycle ──────────────────────────────────────────────────────────────

  /// Call once in main() before runApp().
  static void initializePlugin() {
    FlutterGemma.initialize(
      maxDownloadRetries: 5,
    );
  }

  // ── variant management ────────────────────────────────────────────────────

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
    _chatModel = null; // force re-init on next use
  }

  // ── file helpers ──────────────────────────────────────────────────────────

  Future<String> getModelPath(AiModelVariant variant) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${variant.fileName}';
  }

  Future<bool> isModelDownloaded(AiModelVariant variant) async {
    try {
      final path = await getModelPath(variant);
      return File(path).exists();
    } catch (_) {
      return false;
    }
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
      return {'path': path, 'size': size, 'exists': exists};
    } catch (e) {
      debugPrint('AiService.getModelMetadata: $e');
      return {'path': '--', 'size': '--', 'exists': false};
    }
  }

  // ── download ──────────────────────────────────────────────────────────────

  Future<void> downloadModel({
    required AiModelVariant variant,
    required void Function(double progress) onProgress,
    required void Function() onComplete,
    required void Function(String message) onError,
  }) async {
    if (_isDownloading) {
      onError('A model download is already in progress.');
      return;
    }
    _isDownloading = true;
    try {
      await FlutterGemma.installModel(
        modelType: variant.modelType,
      ).fromNetwork(
        variant.url,
        // foreground: null → auto-detect (>500 MB uses foreground service)
      ).withProgress(
        (progress) => onProgress(progress / 100.0),
      ).install();
      _chatModel = null; // ensure fresh init after download
      onComplete();
    } catch (error) {
      onError(error.toString());
    } finally {
      _isDownloading = false;
    }
  }

  // ── model init ────────────────────────────────────────────────────────────

  /// Ensures the model is loaded and returns true if ready.
  Future<bool> _ensureInitialised() async {
    if (_chatModel != null) return true;
    if (_isInitialising) {
      // Wait briefly for concurrent init
      await Future.delayed(const Duration(milliseconds: 200));
      return _chatModel != null;
    }

    final variant = await getActiveVariant();
    if (!await isModelDownloaded(variant)) return false;

    _isInitialising = true;
    try {
      // Install from the local file so MediaPipe registers it as the active model
      await FlutterGemma.installModel(
        modelType: variant.modelType,
      ).fromFile(await getModelPath(variant)).install();

      _chatModel = await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        preferredBackend: PreferredBackend.gpu,
      );
      return true;
    } catch (e) {
      debugPrint('AiService._ensureInitialised: $e');
      return false;
    } finally {
      _isInitialising = false;
    }
  }

  // ── inference helpers ─────────────────────────────────────────────────────

  Future<String> _runInference(String userPrompt, String fallbackMoodId) async {
    final ready = await _ensureInitialised();
    if (!ready) return _fallback(fallbackMoodId);

    try {
      final session = await _chatModel!.createChat(
        temperature: 0.7,
        topK: 40,
        randomSeed: 42,
        systemInstruction:
            'You are ME, a compassionate mental health companion. '
            'Be warm, non-clinical, and concise. Max 3 sentences.',
      );
      await session.addQueryChunk(
        Message.text(text: userPrompt, isUser: true),
      );
      final buffer = StringBuffer();
      await for (final response in session.generateChatResponseAsync()) {
        if (response is TextResponse) buffer.write(response.token);
      }
      final result = buffer.toString().trim();
      return result.isNotEmpty ? result : _fallback(fallbackMoodId);
    } catch (e) {
      debugPrint('AiService._runInference: $e');
      return _fallback(fallbackMoodId);
    }
  }

  // ── public inference API ──────────────────────────────────────────────────

  Future<String> instantInsight({
    required String moodLabel,
    required int intensity,
    String? note,
  }) async {
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'morning'
        : hour < 17
            ? 'afternoon'
            : hour < 21
                ? 'evening'
                : 'night';

    final prompt = 'Mood logged: $moodLabel at intensity $intensity/10. '
        'Time: $timeOfDay. '
        '${note != null && note.isNotEmpty ? 'Note: "$note". ' : ''}'
        'Give one warm, specific observation in 1-2 sentences. '
        'Be encouraging, never clinical.';

    return _runInference(prompt, moodLabel.toLowerCase());
  }

  Future<String> dailyInsight({
    required DayAggregate aggregate,
    required int streakDays,
  }) async {
    final notesText =
        aggregate.notes.isEmpty ? 'none' : aggregate.notes.join(', ');

    final prompt =
        "Today's mood summary — entries: ${aggregate.entryCount}, "
        "dominant mood: ${aggregate.dominantMood}, "
        "average intensity: ${aggregate.avgIntensity}/10, "
        "arc: ${aggregate.arc}, notes: $notesText, streak: $streakDays days. "
        'Give one observation and one small suggestion for tomorrow in max 3 sentences.';

    return _runInference(prompt, aggregate.dominantMood);
  }

  Future<String> weeklyInsight({required Map<String, dynamic> aggregate}) async {
    final notes = (aggregate['notes'] as List?)?.join('; ') ?? 'none';
    final prompt =
        'Review my last 7 days — top mood: ${aggregate['dominantMood']}, '
        'avg intensity: ${aggregate['avgIntensity']}/10, '
        'total logs: ${aggregate['entryCount']}, '
        'mood distribution: ${aggregate['moodDistribution']}, '
        'notes: $notes. '
        'Supportive summary + one thing to try next week. Max 3 sentences.';

    return _runInference(prompt, 'weekly');
  }

  Future<String> monthlyInsight({required Map<String, dynamic> aggregate}) async {
    final notes = (aggregate['notes'] as List?)?.join('; ') ?? 'none';
    final prompt =
        'Review my last 30 days — top mood: ${aggregate['dominantMood']}, '
        'avg intensity: ${aggregate['avgIntensity']}/10, '
        'total logs: ${aggregate['entryCount']}, '
        'notes: $notes. '
        'Biggest theme + one long-term encouragement. Max 4 sentences.';

    return _runInference(prompt, 'monthly');
  }

  Future<String> generateDailyTip({required String lastMood}) async {
    final prompt =
        'My last logged mood was "$lastMood". '
        'Give me one very short, actionable mental health tip for tomorrow. '
        'Max 12 words. Be warm.';
    return _runInference(prompt, 'tip');
  }

  /// Multi-turn chat used by the Companion screen.
  Future<String> chat({
    required List<Map<String, String>> history,
    String? todayMood,
  }) async {
    final ready = await _ensureInitialised();
    if (!ready) {
      return "I'm still warming up. Give me a moment and try again!";
    }

    try {
      final session = await _chatModel!.createChat(
        temperature: 0.8,
        topK: 40,
        randomSeed: DateTime.now().millisecondsSinceEpoch % 10000,
        systemInstruction:
            "You are 'ME', a warm and compassionate mental health companion. "
            "You are non-clinical, supportive, and focus on emotional awareness. "
            "${todayMood != null ? "Today the user feels '$todayMood'. " : ''}"
            "Keep responses brief (max 60 words). "
            "Ask one follow-up question when appropriate.",
      );

      // Replay history so the model has context
      for (final turn in history) {
        final isUser = turn['role'] == 'user';
        await session.addQueryChunk(
          Message.text(text: turn['content'] ?? '', isUser: isUser),
        );
      }

      final buffer = StringBuffer();
      await for (final response in session.generateChatResponseAsync()) {
        if (response is TextResponse) buffer.write(response.token);
      }

      final result = buffer.toString().trim();
      return result.isNotEmpty ? result : _fallback('chat');
    } catch (e) {
      debugPrint('AiService.chat: $e');
      return _fallback('chat');
    }
  }

  // ── fallbacks ─────────────────────────────────────────────────────────────

  String _fallback(String moodId) {
    const fallbacks = {
      'happy': "You're on a good wave today — carry that into tomorrow.",
      'grateful': "Gratitude is a superpower. You're practising it well.",
      'energised': "Great energy today. Make sure you rest well tonight.",
      'calm': "Calm days build resilience. Well done for noticing.",
      'okay': "Okay days are valid. Tomorrow is a fresh start.",
      'meh': "Flat days happen. One small win tomorrow is enough.",
      'focused': "Focus is rare — you found it today. Note what helped.",
      'tired': "Your body is asking for rest. Honour that tonight.",
      'anxious': "Anxious days are tough. Try 3 slow breaths before sleep.",
      'stressed': "You pushed through a demanding day. Rest is productive too.",
      'sad': "It's okay to feel this. Be gentle with yourself today.",
      'chat': "I'm here to listen whenever you're ready to share.",
      'tip': "Try taking five deep breaths today — a simple way to reset.",
    };
    return fallbacks[moodId.toLowerCase()] ??
        'Every log is a step toward self-awareness. Keep going.';
  }

  // ── reset ─────────────────────────────────────────────────────────────────

  Future<void> reset() async {
    try {
      await _chatModel?.close();
    } catch (_) {}
    _chatModel = null;
    _isInitialising = false;
    _isDownloading = false;
  }
}
