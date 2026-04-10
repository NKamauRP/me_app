import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mood_aggregator.dart';
import '../data/chat_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model catalogue
// ─────────────────────────────────────────────────────────────────────────────

/// All on-device models the app supports.
///
/// Use only PUBLIC models (no HuggingFace auth required) to avoid silent
/// download failures. Gemma 3 1B from litert-community is gated — avoid it.
enum AiModelVariant {
  gemma4(
    'Gemma 4 E2B',
    'gemma-4-E2B-it.litertlm',
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    '~1.4 GB',
    ModelType.gemmaIt,
  ),
  phi4(
    'Phi-4 Mini',
    'phi4_q8_ekv1280.task',
    'https://huggingface.co/litert-community/Phi-4-mini-instruct/resolve/main/phi4_q8_ekv1280.task',
    '~1.9 GB',
    ModelType.general,
  ),
  qwen3(
    'Qwen3 0.6B',
    'qwen3_0.6b.task',
    'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B_multi-prefill-seq_q8_ekv1280.task',
    '~600 MB',
    ModelType.gemmaIt,
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
// MoodState
// ─────────────────────────────────────────────────────────────────────────────

class MoodState {
  String mood;
  String trend;
  List<String> triggers;

  MoodState({
    required this.mood,
    required this.trend,
    required this.triggers,
  });
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
  CancelToken? _cancelToken;
  bool _modelRegistered = false; // prevents re-registering on every inference

  final ValueNotifier<bool> isDownloading = ValueNotifier<bool>(false);
  // Progress stored as 0.0–1.0 for use in LinearProgressIndicator
  final ValueNotifier<double> downloadProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<String?> downloadError = ValueNotifier<String?>(null);

  // ── lifecycle ──────────────────────────────────────────────────────────────

  /// Call once in main() before runApp().
  ///
  /// flutter_gemma v0.13+ automatically handles Android Foreground Service
  /// for downloads >500 MB — no separate background_service plugin needed.
  static void initializePlugin() {
    FlutterGemma.initialize(
      maxDownloadRetries: 10,
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

  /// Downloads [variant] from the network.
  ///
  /// flutter_gemma's [fromNetwork] with [foreground: true] automatically
  /// starts an Android foreground service that survives the user leaving the
  /// Settings screen or minimising the app. No extra plugin is needed.
  ///
  /// Progress from the plugin is already in the range 0–100 (int). We
  /// normalise it to 0.0–1.0 for [downloadProgress] which drives the UI.
  Future<void> downloadModel({
    required AiModelVariant variant,
    void Function(double progress)? onProgress,
    void Function()? onComplete,
    void Function(String message)? onError,
  }) async {
    if (isDownloading.value) {
      onError?.call('A download is already in progress.');
      return;
    }

    isDownloading.value = true;
    downloadProgress.value = 0.0;
    downloadError.value = null;
    _cancelToken = CancelToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_downloading_ai_model', true);
    await prefs.setString('downloading_ai_model_name', variant.name);

    try {
      await FlutterGemma.installModel(
        modelType: variant.modelType,
      )
          .fromNetwork(
            variant.url,
            // DO NOT pass foreground: true — not a valid parameter,
            // foreground service is automatic for files > 500MB
          )
          .withCancelToken(_cancelToken!)
          .withProgress((progress) {
            // progress is an int from 0 to 100
            final double p = progress / 100.0;
            final clamped = p.clamp(0.0, 1.0);
            downloadProgress.value = clamped;
            onProgress?.call(clamped);
          })
          .install();

      // Only clean up old model AFTER successful download
      final oldVariant = await getActiveVariant();
      if (oldVariant != variant) {
        final oldPath = await getModelPath(oldVariant);
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          try { await oldFile.delete(); } catch (_) {}
        }
      }

      _chatModel = null;
      _modelRegistered = false;
      downloadProgress.value = 1.0;
      await setActiveVariant(variant);
      await prefs.setBool('is_downloading_ai_model', false);
      _cancelToken = null;
      onComplete?.call();

    } on Object catch (error) {
      final isCancelled = _cancelToken != null &&
          CancelToken.isCancel(error);

      if (!isCancelled) {
        // Delete partial/corrupt file on failure
        try {
          final path = await getModelPath(variant);
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}

        final msg = error.toString();
        downloadError.value = msg;
        await prefs.setBool('is_downloading_ai_model', false);
        onError?.call(msg);
      } else {
        // Cancelled intentionally — clean up quietly
        try {
          final path = await getModelPath(variant);
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
        await prefs.setBool('is_downloading_ai_model', false);
        downloadError.value = null;
      }
    } finally {
      isDownloading.value = false;
      _cancelToken = null;
    }
  }

  /// Call this to let the user cancel a stalled or unwanted download.
  void cancelDownload() {
    _cancelToken?.cancel('User cancelled download');
  }

  /// Called on app startup. Clears stale download flags.
  /// Does NOT re-trigger a download — flutter_gemma's foreground
  /// service survives app restart on its own. Re-triggering causes
  /// a double-download race condition.
  Future<void> resumeActiveDownload() async {
    final prefs = await SharedPreferences.getInstance();
    final wasDownloading = prefs.getBool('is_downloading_ai_model') ?? false;
    if (!wasDownloading) return;

    final modelName = prefs.getString('downloading_ai_model_name');
    if (modelName == null) {
      await prefs.setBool('is_downloading_ai_model', false);
      return;
    }

    final variant = AiModelVariant.values.firstWhere(
      (v) => v.name == modelName,
      orElse: () => AiModelVariant.qwen3,
    );

    // If file is already fully present, clear the flag and move on
    if (await isModelDownloaded(variant)) {
      final meta = await getModelMetadata(variant);
      final sizeStr = meta['size'] as String? ?? '--';
      final sizeGB = double.tryParse(
              sizeStr.replaceAll(' GB', '').trim()) ??
          0.0;
      if (sizeGB > 0.05) {
        // File looks complete (> 50 MB present)
        await prefs.setBool('is_downloading_ai_model', false);
        await setActiveVariant(variant);
        return;
      }
    }

    // Partial/missing file — delete the fragment and clear flag.
    // The user must manually restart the download from Settings.
    try {
      final path = await getModelPath(variant);
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    await prefs.setBool('is_downloading_ai_model', false);
    downloadError.value =
        'Previous download was incomplete. Please download again.';
  }

  // ── model management ──────────────────────────────────────────────────────
  
  /// Deletes the physical litert/task model file from the device to save space.
  Future<void> deleteActiveModel({bool keepVariantConfig = false}) async {
    try {
      await _chatModel?.close();
    } catch (_) {}
    _chatModel = null;
    _modelRegistered = false;

    try {
      final variant = await getActiveVariant();
      final path = await getModelPath(variant);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Deleted model file: $path');
      }
    } catch (e) {
      debugPrint('Error deleting model: $e');
    }

    if (!keepVariantConfig) {
      await setActiveVariant(AiModelVariant.qwen3);
    }
  }

  // ── model init ────────────────────────────────────────────────────────────

  /// Ensures the model is loaded and returns true if ready.
  Future<bool> _ensureInitialised() async {
    if (_chatModel != null) return true;

    // Prevent concurrent init calls
    if (_isInitialising) {
      // Wait up to 10 seconds for the concurrent init to finish
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_chatModel != null) return true;
        if (!_isInitialising) break;
      }
      return _chatModel != null;
    }

    final variant = await getActiveVariant();
    if (!await isModelDownloaded(variant)) return false;

    _isInitialising = true;
    try {
      // Register the local file with the plugin — only if not already done.
      // Calling installModel().fromFile() repeatedly re-initialises the
      // native engine and causes GPU delegate crashes on the second call.
      if (!_modelRegistered) {
        await FlutterGemma.installModel(
          modelType: variant.modelType,
        ).fromFile(await getModelPath(variant)).install();
        _modelRegistered = true;
      }

      _chatModel = await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        preferredBackend: PreferredBackend.gpu,
      );
      return _chatModel != null;
    } catch (e) {
      debugPrint('AiService._ensureInitialised: $e');
      _modelRegistered = false; // allow retry on next call
      return false;
    } finally {
      _isInitialising = false;
    }
  }

  // ── MoodState & Summarization Helpers ─────────────────────────────────────

  MoodState _extractMoodState(String text) {
    // Lightweight keyword detection for placeholders as requested
    String mood = 'neutral';
    String trend = 'stable';
    List<String> triggers = [];

    final lowTriggers = text.toLowerCase();
    if (lowTriggers.contains('work') || lowTriggers.contains('job')) triggers.add('work');
    if (lowTriggers.contains('family') || lowTriggers.contains('home')) triggers.add('family');
    if (lowTriggers.contains('health') || lowTriggers.contains('tired')) triggers.add('health');
    
    if (lowTriggers.contains('better') || lowTriggers.contains('happy')) mood = 'positive';
    if (lowTriggers.contains('worse') || lowTriggers.contains('sad')) mood = 'negative';

    return MoodState(mood: mood, trend: trend, triggers: triggers);
  }

  Future<String> _generateSummary(String oldSummary, List<Map<String, String>> messages) async {
    final ready = await _ensureInitialised();
    if (!ready) return oldSummary;

    final historyText = messages.map((m) => '${m['role']}: ${m['content']}').join('\n');
    final prompt = """
Current Conversation Summary:
$oldSummary

New messages to incorporate:
$historyText

TASK:
Summarize user's emotional state, triggers, and mood trend in under 80 tokens.
Return only the new summary.
""";

    try {
      final session = await _chatModel!.createChat(
        temperature: 0.3,
        systemInstruction: 'You are a concise summarizer for a mental health app.',
      );
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      
      final buffer = StringBuffer();
      await for (final resp in session.generateChatResponseAsync()) {
        if (resp is TextResponse) buffer.write(resp.token);
      }
      return buffer.toString().trim();
    } catch (e) {
      debugPrint('AiService._generateSummary Error: $e');
      return oldSummary;
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

  Future<String> chat({
    required String sessionId,
    required List<Map<String, String>> history,
    String? todayMood,
    String? sessionTitle,
  }) async {
    final ready = await _ensureInitialised();
    if (!ready) {
      return "I'm still warming up. Give me a moment and try again!";
    }

    try {
      // 1. Fetch current summary and update mood state
      String currentSummary = await ChatDatabase.instance.getSummary(sessionId) ?? "";
      final lastUserMsg = history.lastWhere((m) => m['role'] == 'user')['content'] ?? "";
      final moodState = _extractMoodState(lastUserMsg);

      // 2. Token / Length check for summarization
      const int maxRecent = 4;
      const int summaryTriggerCount = 8;
      
      List<Map<String, String>> recentMessages = history;

      // Estimate tokens
      int historyLength = history.fold(0, (sum, m) => sum + (m['content']?.length ?? 0));
      int estimatedTokens = historyLength ~/ 4;

      if (history.length > summaryTriggerCount || estimatedTokens > 1800) {
        debugPrint('AiService.chat: Summarization triggered (Count: ${history.length}, Tokens: $estimatedTokens)');
        
        // Summarize all but the last 4 messages
        final olderCount = history.length - maxRecent;
        if (olderCount > 0) {
          final olderMessages = history.sublist(0, olderCount);
          currentSummary = await _generateSummary(currentSummary, olderMessages);
          await ChatDatabase.instance.updateSummary(sessionId, currentSummary);
          recentMessages = history.sublist(olderCount);
        }
      } else {
        // Just keep last 4 for prompt relevance if not summarizing
        if (history.length > maxRecent) {
          recentMessages = history.sublist(history.length - maxRecent);
        }
      }

      // 3. Build structured prompt
      final recentText = recentMessages.map((m) => '${m['role'] == 'user' ? 'User' : 'Assistant'}: ${m['content']}').join('\n');
      
      final prompt = """
You are a mood support assistant inside a mood tracking app.

USER MOOD STATE (structured):
- Current mood: ${moodState.mood}
- Trend: ${moodState.trend}
- Triggers: ${moodState.triggers.join(', ')}

CONVERSATION SUMMARY:
$currentSummary

RECENT MESSAGES (last $maxRecent only):
$recentText

RULES:
- Respond in max 2 sentences
- Be emotionally supportive
- Do not repeat earlier responses
- Do not act like a general chatbot
- Focus on mood insight, not conversation expansion

Assistant:
""";

      debugPrint('AiService.chat: Prompt Length: ${prompt.length}, Est Tokens: ${prompt.length ~/ 4}');

      // 4. Run inference with timeout
      final session = await _chatModel!.createChat(
        temperature: 0.8,
        topK: 40,
        randomSeed: DateTime.now().millisecondsSinceEpoch % 10000,
        systemInstruction: prompt,
      );

      final buffer = StringBuffer();
      // Use 6s timeout for the entire generation process
      await for (final response in session.generateChatResponseAsync().timeout(const Duration(seconds: 6))) {
        if (response is TextResponse) buffer.write(response.token);
      }

      final result = buffer.toString().trim();
      return result.isNotEmpty ? result : "I'm still here—can you rephrase that?";
    } catch (e) {
      debugPrint('AiService.chat Error: $e');
      if (e is TimeoutException) {
        return "I'm still here—tell me a bit more.";
      }
      return "I'm still here—can you rephrase that?";
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
      'weekly': "Your weekly patterns are valuable. Reviewing them helps you grow.",
      'monthly': "A month of reflection is a huge win. You're building a great habit.",
    };
    return fallbacks[moodId.toLowerCase()] ??
        "Every log is a step toward self-awareness. Keep going.";
  }

  // ── reset ─────────────────────────────────────────────────────────────────

  Future<void> reset() async {
    cancelDownload(); // cancel any active download first
    try {
      await _chatModel?.close();
    } catch (_) {}
    _chatModel = null;
    _isInitialising = false;
    _modelRegistered = false;
    _cancelToken = null;
    isDownloading.value = false;
    downloadProgress.value = 0.0;
    downloadError.value = null;
  }
}
