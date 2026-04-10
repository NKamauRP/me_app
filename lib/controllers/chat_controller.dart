import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/chat_database.dart';
import '../services/ai_service.dart';

class ChatMessage {
  final String role;     // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isLoading;  // true = typing indicator

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isLoading = false,
  });
}

class ChatController extends ChangeNotifier {
  final String sessionId;
  final String sessionTitle;

  ChatController({
    required this.sessionId,
    required this.sessionTitle,
  });

  final List<ChatMessage> messages = [];
  bool isResponding = false;
  String? errorMessage;

  // ── Load existing messages from DB ─────────────────────────────

  Future<void> loadHistory() async {
    final rows = await ChatDatabase.instance
        .getMessages(sessionId, limit: 50);
    messages.clear();
    for (final row in rows) {
      messages.add(ChatMessage(
        role: row['role'] as String,
        content: row['content'] as String,
        timestamp: DateTime.parse(row['timestamp'] as String),
      ));
    }
    notifyListeners();
  }

  // ── Send a message ─────────────────────────────────────────────

  Future<void> sendMessage(String userText) async {
    if (userText.trim().isEmpty || isResponding) return;

    errorMessage = null;

    // 1. Add user message to UI immediately
    final userMsg = ChatMessage(
      role: 'user',
      content: userText.trim(),
      timestamp: DateTime.now(),
    );
    messages.add(userMsg);
    isResponding = true;

    // 2. Show typing indicator
    messages.add(ChatMessage(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      isLoading: true,
    ));
    notifyListeners();

    // 3. Save user message to DB
    await ChatDatabase.instance.insertMessage(
      sessionId: sessionId,
      role: 'user',
      content: userText.trim(),
    );

    // 4. Auto-generate session title from first user message
    if (messages.where((m) => m.role == 'user').length == 1) {
      final title = userText.trim().length > 40
          ? '${userText.trim().substring(0, 40)}…'
          : userText.trim();
      await ChatDatabase.instance
          .updateSessionTitle(sessionId, title);
    }

    // 5. Extract and save user name if mentioned
    _extractAndSaveMemory(userText);

    // 6. Build history for inference (last 20 exchanges)
    final history = await ChatDatabase.instance
        .getHistoryForInference(sessionId, limit: 20);

    // 7. Run inference
    try {
      final response = await AiService.instance.chat(
        history: history,
        sessionTitle: sessionTitle,
      );

      // 8. Remove typing indicator, add real response
      messages.removeLast();
      messages.add(ChatMessage(
        role: 'assistant',
        content: response,
        timestamp: DateTime.now(),
      ));

      // 9. Save assistant response to DB
      await ChatDatabase.instance.insertMessage(
        sessionId: sessionId,
        role: 'assistant',
        content: response,
      );

      // 10. Check if model is downloaded and show one-time prompt
      await _checkAndShowDownloadPrompt();

    } catch (e) {
      if (messages.isNotEmpty && messages.last.isLoading) {
        messages.removeLast();
      }
      errorMessage = 'Something went wrong. Try again.';
      debugPrint('ChatController.sendMessage: $e');
    } finally {
      isResponding = false;
      notifyListeners();
    }
  }

  Future<void> _checkAndShowDownloadPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final shownDownloadPrompt = prefs.getBool('shown_download_prompt') ?? false;

    final isDownloaded = await AiService.instance
        .isModelDownloaded(await AiService.instance.getActiveVariant());

    if (!isDownloaded && !shownDownloadPrompt) {
      await prefs.setBool('shown_download_prompt', true);
      final downloadInfo = ChatMessage(
        role: 'assistant',
        content: '💡 To unlock full AI responses, download an AI model '
                 'in Settings → AI Insights. '
                 'Qwen3 0.6B (~600 MB) works on any phone and is '
                 'a great place to start.',
        timestamp: DateTime.now(),
      );
      messages.add(downloadInfo);
      
      // Also save this tip to DB for persistence in this thread
      await ChatDatabase.instance.insertMessage(
        sessionId: sessionId,
        role: 'assistant',
        content: downloadInfo.content,
      );
    }
  }

  // ── Memory extraction ──────────────────────────────────────────
  // Passively detects when the user mentions their name or
  // other key facts and saves them to user_memory.

  void _extractAndSaveMemory(String text) {
    // Detect "my name is X" or "call me X" or "I'm X"
    final namePatterns = [
      RegExp(r"my name is (\w+)", caseSensitive: false),
      RegExp(r"call me (\w+)", caseSensitive: false),
      RegExp(r"i'?m (\w+)", caseSensitive: false),
      RegExp(r"i am (\w+)", caseSensitive: false),
    ];
    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1) ?? '';
        if (name.length > 1 && name.length < 20) {
          ChatDatabase.instance.saveMemory('preferred_name', name);
          ChatDatabase.instance.saveMemory('user_name', name);
          break;
        }
      }
    }

    // Detect key life mentions worth remembering
    final triggers = {
      'work': r"(work|job|office|boss|colleague)",
      'family': r"(family|mum|dad|sister|brother|partner|husband|wife|kids)",
      'health': r"(health|doctor|hospital|medication|therapy|therapist)",
      'goal': r"(trying to|want to|goal|working on|hope to)",
    };
    for (final entry in triggers.entries) {
      if (RegExp(entry.value, caseSensitive: false).hasMatch(text)) {
        // Save a brief note that this topic has come up
        ChatDatabase.instance.saveMemory(
          'mentioned_${entry.key}',
          'yes — last mention: ${DateTime.now().toIso8601String().substring(0, 10)}',
        );
      }
    }
  }
}
