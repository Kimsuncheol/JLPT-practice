import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';

/// Keeps all partial text in one assistant bubble as tokens arrive.
class StreamingChatReply {
  StreamingChatReply(this.controller, this.assistant)
    : _id = 'ai_${DateTime.now().microsecondsSinceEpoch}',
      _createdAt = DateTime.now();

  final ChatMessagesController controller;
  final ChatUser assistant;
  final String _id;
  final DateTime _createdAt;
  bool _started = false;

  ChatMessage _message(String text, {required bool streaming}) => ChatMessage(
    text: text,
    user: assistant,
    createdAt: _createdAt,
    isMarkdown: true,
    customProperties: {'id': _id, 'isStreaming': streaming},
  );

  void update(String text) {
    if (text.isEmpty) return;
    if (!_started) {
      _started = true;
      controller.addStreamingMessage(_message(text, streaming: true));
    } else {
      controller.updateMessage(_message(text, streaming: true));
    }
  }

  void finish(String text) {
    if (!_started) {
      controller.addMessage(_message(text, streaming: false));
    } else {
      controller.updateMessage(_message(text, streaming: false));
      controller.stopStreamingMessage(_id);
    }
  }
}
