import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/services/theme_service.dart';
import '../features/mind/mood_catalog.dart';
import '../features/mind/providers/mind_me_provider.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../shared/widgets/glass_panel.dart';
import '../shared/widgets/halftone_overlay.dart';
import '../widgets/insight_card.dart';

class CompanionScreen extends StatefulWidget {
  const CompanionScreen({super.key});

  @override
  State<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends State<CompanionScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isThinking = false;
  bool _isModelReady = false;
  String _modelLabel = 'AI Model';

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        role: MessageRole.model,
        content: "Hello! I'm ME, your mindful companion. How are you feeling right now?",
      ),
    );
    _loadModelStatus();
  }

  Future<void> _loadModelStatus() async {
    final variant = await AiService.instance.getActiveVariant();
    final ready = await AiService.instance.isModelDownloaded(variant);
    if (!mounted) return;
    setState(() {
      _isModelReady = ready;
      _modelLabel = variant.label;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isThinking) return;

    setState(() {
      _messages.add(ChatMessage(role: MessageRole.user, content: text));
      _isThinking = true;
      _controller.clear();
    });
    _scrollToBottom();

    final provider = context.read<MindMeProvider>();
    final todayMood = provider.todayLog != null
        ? moodOptionById(provider.todayLog!.mood).label
        : null;

    final history = _messages.map((m) => m.toTurn()).toList();

    try {
      final response = await AiService.instance.chat(
        sessionId: 'transient_standalone_companion', // Persistent memory for standalone screen
        history: history,
        todayMood: todayMood,
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: MessageRole.model, content: response));
          _isThinking = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              role: MessageRole.model,
              content: "I'm having a little trouble connecting to my thoughts. Could you try that again?",
            ),
          );
          _isThinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ThemeService>();
    final palette = AppTheme.paletteOf(settings.currentTheme);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mind Companion'),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _isModelReady ? Colors.greenAccent : Colors.orangeAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isModelReady
                      ? '$_modelLabel · On-device'
                      : 'AI Model Not Installed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: HalftoneOverlay(
        opacity: settings.currentTheme == AppThemePreset.night || settings.currentTheme == AppThemePreset.focus 
            ? 0.08 
            : 0.04,
        child: Container(
          decoration: BoxDecoration(
            color: palette.scaffold,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _messages.length + (_isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TypingDots(),
                          ),
                        );
                      }

                      final message = _messages[index];
                      final isUser = message.role == MessageRole.user;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.85,
                            ),
                            child: Column(
                              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isUser ? palette.seed : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                                      bottomRight: Radius.circular(isUser ? 4 : 20),
                                    ),
                                    border: isUser ? null : Border.all(color: palette.textPrimary.withValues(alpha: 0.05)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    message.content,
                                    style: isUser 
                                        ? theme.textTheme.bodyLarge?.copyWith(
                                            color: Colors.white,
                                            fontSize: 15,
                                          )
                                        : theme.textTheme.bodyLarge?.copyWith(
                                            fontFamily: 'Lora',
                                            fontSize: 16,
                                            height: 1.6,
                                          ),
                                  ),
                                ),
                                if (!isUser) ...[
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      'ME · On-device reasoning',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 10,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: palette.textPrimary.withValues(alpha: 0.1)),
                          ),
                          child: TextField(
                            controller: _controller,
                            onSubmitted: (_) => _sendMessage(),
                            style: theme.textTheme.bodyLarge,
                            decoration: const InputDecoration(
                              hintText: 'Share what\'s on your mind...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            color: palette.seed,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

