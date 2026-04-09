enum MessageRole {
  user,
  model,
}

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final MessageRole role;
  final String content;
  final DateTime timestamp;

  Map<String, String> toTurn() {
    return {
      'role': role == MessageRole.user ? 'user' : 'model',
      'content': content,
    };
  }
}
