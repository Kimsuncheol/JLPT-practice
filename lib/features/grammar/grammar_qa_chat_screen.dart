import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_qa_service.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';
import 'package:jlpt_practice/shared/chat_ui_style.dart';
import 'package:jlpt_practice/shared/streaming_chat_reply.dart';

Future<void> showGrammarQaChatScreen(
  BuildContext context, {
  required GrammarPoint grammar,
  required String languageCode,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          GrammarQaChatScreen(grammar: grammar, languageCode: languageCode),
    ),
  );
}

class GrammarQaChatScreen extends ConsumerStatefulWidget {
  const GrammarQaChatScreen({
    required this.grammar,
    required this.languageCode,
    super.key,
  });

  final GrammarPoint grammar;
  final String languageCode;

  @override
  ConsumerState<GrammarQaChatScreen> createState() =>
      _GrammarQaChatScreenState();
}

class _GrammarQaChatScreenState extends ConsumerState<GrammarQaChatScreen> {
  static const _user = ChatUser(id: 'user', firstName: 'You');
  static const _assistant = ChatUser(id: 'ai', firstName: 'AI');
  final _messages = ChatMessagesController();
  final _input = TextEditingController();
  final List<String> _pendingMessages = [];
  bool _asking = false;
  bool _waiting = false;
  bool _hasAnswer = false;

  @override
  void dispose() {
    _pendingMessages.clear();
    _messages.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(ChatMessage message) async => _queueQuestion(message.text);

  void _sendInput() {
    final question = _input.text.trim();
    if (question.isEmpty || question.length > 300) return;
    _input.clear();
    _queueQuestion(question);
  }

  void _queueQuestion(String text) {
    final question = text.trim();
    if (question.isEmpty || question.length > 300) return;
    _messages.addMessage(
      ChatMessage(text: question, user: _user, createdAt: DateTime.now()),
    );
    setState(() => _pendingMessages.add(question));
    _startNextQuestion();
  }

  void _startNextQuestion() {
    if (!mounted || _asking || _pendingMessages.isEmpty) return;
    final question = _pendingMessages.removeAt(0);
    _generate(question);
  }

  Future<void> _generate(String question) async {
    setState(() {
      _asking = true;
      _waiting = true;
    });
    final reply = StreamingChatReply(_messages, _assistant);
    try {
      final service = await ref.read(grammarQaServiceProvider.future);
      final answer = await service.ask(
        grammar: widget.grammar,
        question: question,
        languageCode: widget.languageCode,
        onPartial: (text) {
          if (!mounted) return;
          if (_waiting) setState(() => _waiting = false);
          reply.update(text);
        },
      );
      if (!mounted) return;
      reply.finish(answer);
      setState(() => _hasAnswer = true);
    } catch (error) {
      if (!mounted) return;
      final key = error is OfflineAiException
          ? error.key
          : 'offlineInferenceError';
      reply.finish(context.strings(key));
      setState(() => _hasAnswer = true);
    } finally {
      if (mounted) {
        setState(() {
          _asking = false;
          _waiting = false;
        });
        _startNextQuestion();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.strings('grammarChatTitle')),
        actions: [
          IconButton(
            key: const ValueKey('grammar_chat_close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  AiChatWidget(
                    currentUser: _user,
                    aiUser: _assistant,
                    controller: _messages,
                    onSendMessage: _send,
                    readOnly: true,
                    loadingConfig: ChatUiStyle.loading(context, _waiting),
                    messageOptions: ChatUiStyle.messages(context),
                  ),
                  if (!_hasAnswer && !_asking)
                    ChatUiStyle.suggestions(
                      context: context,
                      centered: true,
                      chips: [
                        ChatUiStyle.suggestion(
                          context.strings('askSuggestionWhenToUse'),
                          _asking
                              ? null
                              : () => _queueQuestion(
                                  context.strings('askSuggestionWhenToUse'),
                                ),
                        ),
                        ChatUiStyle.suggestion(
                          context.strings('askSuggestionMoreExamples'),
                          _asking
                              ? null
                              : () => _queueQuestion(
                                  context.strings('askSuggestionMoreExamples'),
                                ),
                        ),
                        ChatUiStyle.suggestion(
                          context.strings('askSuggestionDifference'),
                          _asking
                              ? null
                              : () => _queueQuestion(
                                  context.strings('askSuggestionDifference'),
                                ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (_hasAnswer || _asking)
              ChatUiStyle.suggestions(
                context: context,
                centered: false,
                chips: [
                  for (final key in [
                    'askSuggestionWhenToUse',
                    'askSuggestionMoreExamples',
                    'askSuggestionDifference',
                  ])
                    ChatUiStyle.suggestion(
                      context.strings(key),
                      _asking
                          ? null
                          : () => _queueQuestion(context.strings(key)),
                    ),
                ],
              ),
            ChatUiStyle.composer(
              context: context,
              controller: _input,
              hint: context.strings('askAboutThisGrammarHint'),
              sendTooltip: context.strings('sendMessage'),
              enabled: true,
              maxLength: 300,
              onSend: _sendInput,
            ),
            if (_pendingMessages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      context
                          .strings('queuedChatMessages')
                          .replaceAll('{count}', '${_pendingMessages.length}'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
