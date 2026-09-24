import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_qa_service.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';

/// Opens the "Ask about this grammar point" chat as a bottom sheet.
Future<void> showGrammarQaChatSheet(
  BuildContext context, {
  required GrammarPoint grammar,
  required String languageCode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _GrammarQaChatSheet(grammar: grammar, languageCode: languageCode),
  );
}

class _GrammarQaChatSheet extends ConsumerStatefulWidget {
  const _GrammarQaChatSheet({
    required this.grammar,
    required this.languageCode,
  });

  final GrammarPoint grammar;
  final String languageCode;

  @override
  ConsumerState<_GrammarQaChatSheet> createState() =>
      _GrammarQaChatSheetState();
}

class _GrammarQaChatSheetState extends ConsumerState<_GrammarQaChatSheet> {
  static const _user = ChatUser(id: 'user', firstName: 'You');
  static const _assistant = ChatUser(id: 'ai', firstName: 'AI');
  final _messages = ChatMessagesController();
  bool _asking = false;

  @override
  void dispose() {
    _messages.dispose();
    super.dispose();
  }

  Future<void> _send(ChatMessage message) async {
    final question = message.text.trim();
    if (question.isEmpty || question.length > 300 || _asking) return;
    _messages.addMessage(
      ChatMessage(text: question, user: _user, createdAt: DateTime.now()),
    );
    setState(() => _asking = true);
    try {
      final service = await ref.read(grammarQaServiceProvider.future);
      final answer = await service.ask(
        grammar: widget.grammar,
        question: question,
        languageCode: widget.languageCode,
      );
      if (!mounted) return;
      _addAnswer(answer);
    } catch (error) {
      if (!mounted) return;
      final key = error is OfflineAiException
          ? error.key
          : 'offlineInferenceError';
      _addAnswer(context.strings(key));
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  void _addAnswer(String answer) {
    _messages.addMessage(
      ChatMessage(text: answer, user: _assistant, createdAt: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.strings('askAboutThisGrammar'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AiChatWidget(
                currentUser: _user,
                aiUser: _assistant,
                controller: _messages,
                onSendMessage: _send,
                readOnly: _asking,
                loadingConfig: LoadingConfig(isLoading: _asking),
                inputOptions: InputOptions(
                  decoration: InputDecoration(
                    hintText: context.strings('askAboutThisGrammarHint'),
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(300)],
                  sendButtonTooltip: context.strings('sendMessage'),
                ),
                welcomeMessageConfig: const WelcomeMessageConfig(
                  title: '',
                  questionsSectionTitle: '',
                  centerVertically: true,
                ),
                exampleQuestions: [
                  ExampleQuestion(
                    question: context.strings('askSuggestionWhenToUse'),
                  ),
                  ExampleQuestion(
                    question: context.strings('askSuggestionMoreExamples'),
                  ),
                  ExampleQuestion(
                    question: context.strings('askSuggestionDifference'),
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
