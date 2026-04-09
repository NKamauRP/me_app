import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/services/theme_service.dart';
import '../features/mind/mood_catalog.dart';
import '../features/mind/providers/mind_me_provider.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../shared/widgets/glass_panel.dart';
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

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        role: MessageRole.model,
        content: "Hello! I'm ME, your mindful companion. How are you feeling right now?",
      ),
    );
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
            FutureBuilder<AiModelVariant>(
              future: AiService.instance.getActiveVariant(),
              builder: (context, variantSnapshot) {
                final variant = variantSnapshot.data ?? AiModelVariant.gemma4;
                return FutureBuilder<bool>(
                  future: AiService.instance.isModelDownloaded(variant),
                  builder: (context, snapshot) {
                    final isReady = snapshot.data ?? false;
                    return Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isReady ? Colors.greenAccent : Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isReady ? 'On-device AI Active' : 'AI Model Not Ready',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.backgroundTop, palette.backgroundBottom],
          ),
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
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: GlassPanel(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            borderRadius: 18,
                            tint: isUser ? palette.seed : Colors.white10,
                            child: Text(
                              message.content,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: isUser ? Colors.white : theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassPanel(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        borderRadius: 24,
                        child: TextField(
                          controller: _controller,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: const InputDecoration(
                            hintText: 'Share what\'s on your mind...',
                            border: InputBorder.none,
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
                          Icons.send_rounded,
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
    );
  }
}
