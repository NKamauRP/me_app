import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/chat_controller.dart';
import '../services/ai_service.dart';
import '../services/context_builder.dart';
import '../widgets/model_status_dot.dart';
import 'package:confetti/confetti.dart';
import '../data/chat_database.dart';
import 'chat_screen.dart'; // For self-navigation into new session

class ChatScreen extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;

  const ChatScreen({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatController _controller;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<String> _starters = [];
  bool _startersVisible = true;
  bool _isInit = false;
  late ConfettiController _confettiController;
  bool _hasTriggeredConfetti = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _controller = ChatController(
        sessionId: widget.sessionId,
        sessionTitle: widget.sessionTitle,
      );
      _controller.addListener(_onControllerUpdate);
      await _controller.loadHistory();
      
      final starters = await ContextBuilder.instance.buildStarters();
      
      if (mounted) {
        setState(() {
          _starters = starters;
          if (_controller.messages.isNotEmpty) {
            _startersVisible = false;
          }
          _isInit = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _confettiController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      if (_controller.isSessionFull && !_hasTriggeredConfetti) {
        _hasTriggeredConfetti = true;
        _confettiController.play();
      }
      
      setState(() {});
      // Auto-scroll to bottom when new message arrives
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _handleSend() {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    
    _inputController.clear();
    setState(() => _startersVisible = false);
    _controller.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: const [
          ModelStatusDot(),
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            children: [
              // Message list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _controller.messages.length,
                  itemBuilder: (context, i) {
                    final msg = _controller.messages[i];
                    if (msg.isLoading) return const _TypingIndicator();
                    return _MessageBubble(message: msg);
                  },
                ),
              ),
    
              // Conversation starters
              if (_startersVisible && _starters.isNotEmpty)
                _StarterChips(
                  starters: _starters,
                  onTap: (text) {
                    setState(() => _startersVisible = false);
                    _controller.sendMessage(text);
                  },
                ),
    
              // Error banner
              if (_controller.errorMessage != null)
                Container(
                  color: Colors.red.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(8),
                  width: double.infinity,
                  child: Text(
                    _controller.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
    
              // Input row or "Start Fresh"
              if (_controller.isSessionFull)
                _StartFreshButton(
                  onPressed: _handleStartFresh,
                )
              else
                _InputRow(
                  controller: _inputController,
                  isResponding: _controller.isResponding,
                  onSend: _handleSend,
                ),
            ],
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartFresh() async {
    final currentSummary = await ChatDatabase.instance.getSummary(widget.sessionId);
    final newSessionId = await ChatDatabase.instance.createSession(
      'Follow-up: ${widget.sessionTitle}',
      initialSummary: currentSummary,
    );
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            sessionId: newSessionId,
            sessionTitle: 'Follow-up: ${widget.sessionTitle}',
          ),
        ),
      );
    }
  }
}

class _StartFreshButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _StartFreshButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
      ),
      child: Column(
        children: [
          const Text(
            'Session fully loaded with insights!',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Start Fresh Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F77DD),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.role == 'assistant';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isAssistant ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (isAssistant)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                'ME',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isAssistant 
                ? theme.cardColor 
                : const Color(0xFF7F77DD),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isAssistant ? 4 : 18),
                bottomRight: Radius.circular(isAssistant ? 18 : 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: isAssistant ? colorScheme.onSurface : Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final delay = index * 0.2;
                final value = Interval(delay, delay + 0.4, curve: Curves.easeInOut)
                    .transform(_animationController.value);
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.2 + (0.4 * value)),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

class _StarterChips extends StatelessWidget {
  final List<String> starters;
  final ValueChanged<String> onTap;

  const _StarterChips({required this.starters, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: starters.length,
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              label: Text(
                starters[i],
                style: const TextStyle(color: Color(0xFF534AB7), fontSize: 13),
              ),
              backgroundColor: const Color(0xFF7F77DD).withValues(alpha: 0.08),
              side: const BorderSide(color: Color(0xFF7F77DD), width: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () => onTap(starters[i]),
            ),
          );
        },
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  final TextEditingController controller;
  final bool isResponding;
  final VoidCallback onSend;

  const _InputRow({
    required this.controller,
    required this.isResponding,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Talk to ME...',
                hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.3)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: const Color(0xFF534AB7).withValues(alpha: 0.3)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isResponding ? null : onSend,
            icon: isResponding
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF534AB7)),
                  )
                : const Icon(Icons.send_rounded),
            color: const Color(0xFF534AB7),
          ),
        ],
      ),
    );
  }
}
