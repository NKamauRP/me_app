import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model_management/cancel_token.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mood_aggregator.dart';

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
  smolLm(
    'SmolLM 135M',
    'smollm_135m.task',
    // Smallest public model — great for testing the download flow
    'https://huggingface.co/litert-community/SmolLM-135M-Instruct/resolve/main/SmolLM-135M-Instruct_multi-prefill-seq_q8_ekv1280.task',
    '~166 MB',
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
            // progress is DownloadProgress object with .percentage (int 0-100)
            // If the plugin passes a raw int, handle both cases safely:
            double p;
            if (progress is int) {
              p = progress / 100.0;
            } else {
              try {
                // DownloadProgress object
                p = ((progress as dynamic).percentage as int) / 100.0;
              } catch (_) {
                p = downloadProgress.value; // keep last known value
              }
            }
            p = p.clamp(0.0, 1.0);
            downloadProgress.value = p;
            onProgress?.call(p);
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
      orElse: () => AiModelVariant.smolLm,
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
      await setActiveVariant(AiModelVariant.smolLm);
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
