import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/immersive_study_mode.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/data/models/grammar_study_session.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/grammar/grammar_practice_service.dart';
import 'package:jlpt_practice/features/grammar/grammar_study_session_provider.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';
import 'package:jlpt_practice/shared/chat_ui_style.dart';
import 'package:jlpt_practice/shared/streaming_chat_reply.dart';

class GrammarTutorScreen extends ConsumerStatefulWidget {
  const GrammarTutorScreen({required this.grammarId, super.key});
  final String grammarId;

  @override
  ConsumerState<GrammarTutorScreen> createState() => _GrammarTutorScreenState();
}

class _GrammarTutorScreenState extends ConsumerState<GrammarTutorScreen>
    with ImmersiveStudyMode<GrammarTutorScreen> {
  static const _user = ChatUser(id: 'user', firstName: 'You');
  static const _assistant = ChatUser(id: 'ai', firstName: 'AI');
  final _messages = ChatMessagesController();
  final List<GrammarPracticeTurn> _history = [];
  final _input = TextEditingController();
  bool _asking = false;
  bool _waiting = false;
  bool _hasAnswer = false;

  @override
  void dispose() {
    _messages.dispose();
    _input.dispose();
    super.dispose();
  }

  void _sendInput(GrammarPoint grammar, String languageCode) {
    final question = _input.text.trim();
    if (question.isEmpty || _asking) return;
    _input.clear();
    _ask(grammar, languageCode, question);
  }

  Future<void> _ask(
    GrammarPoint grammar,
    String languageCode,
    String text, {
    bool practiceTask = false,
  }) async {
    final question = text.trim();
    if (question.isEmpty || question.length > 300 || _asking) return;
    _messages.addMessage(
      ChatMessage(text: question, user: _user, createdAt: DateTime.now()),
    );
    setState(() {
      _asking = true;
      _waiting = true;
    });
    final reply = StreamingChatReply(_messages, _assistant);
    try {
      final service = await ref.read(grammarPracticeServiceProvider.future);
      final answer = await service.reply(
        grammar: grammar,
        message: question,
        languageCode: languageCode,
        history: List.of(_history),
        practiceTask: practiceTask,
        onPartial: (text) {
          if (!mounted) return;
          if (_waiting) setState(() => _waiting = false);
          reply.update(text);
        },
      );
      if (!mounted) return;
      _history.add(GrammarPracticeTurn(isUser: true, text: question));
      _history.add(GrammarPracticeTurn(isUser: false, text: answer));
      reply.finish(answer);
      setState(() => _hasAnswer = true);
    } catch (error) {
      if (!mounted) return;
      reply.finish(
        context.strings(
          error is OfflineAiException ? error.key : 'offlineInferenceError',
        ),
      );
      setState(() => _hasAnswer = true);
    } finally {
      if (mounted) {
        setState(() {
          _asking = false;
          _waiting = false;
        });
      }
    }
  }

  List<Widget> _suggestions(GrammarPoint grammar, String languageCode) => [
    for (final key in [
      'practicePromptSuggestion',
      'practiceExampleSuggestion',
      'practiceUsageSuggestion',
    ])
      ChatUiStyle.suggestion(
        context.strings(key),
        _asking
            ? null
            : () => _ask(
                grammar,
                languageCode,
                context.strings(key),
                practiceTask: key == 'practicePromptSuggestion',
              ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(grammarCatalogProvider);
    return wrapImmersive(
      catalog.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
        data: (items) {
          final matches = items.where((item) => item.id == widget.grammarId);
          if (matches.isEmpty) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(context.strings('noGrammarResults'))),
            );
          }
          final grammar = matches.first;
          final languageCode =
              ref.watch(appControllerProvider).value?.meaningLanguage ??
              Localizations.localeOf(context).languageCode;
          return TrackGrammarStudy(
            key: ValueKey(grammar.id),
            session: GrammarStudySession(
              level: grammar.level,
              part: (grammar.rank - 1) ~/ 10 + 1,
              kind: GrammarStudyKind.tutor,
              grammarId: grammar.id,
              title: grammar.title,
              updatedAt: DateTime.now(),
            ),
            child: _buildChat(grammar, languageCode),
          );
        },
      ),
    );
  }

  Widget _buildChat(GrammarPoint grammar, String languageCode) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: Text(context.strings('practiceWithAi')),
      actions: [
        IconButton(
          key: const ValueKey('grammar_practice_close'),
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
                  onSendMessage: (message) =>
                      _ask(grammar, languageCode, message.text),
                  readOnly: true,
                  loadingConfig: ChatUiStyle.loading(context, _waiting),
                  messageOptions: ChatUiStyle.messages(context),
                ),
                if (!_hasAnswer && !_asking)
                  ChatUiStyle.suggestions(
                    context: context,
                    centered: true,
                    chips: _suggestions(grammar, languageCode),
                  ),
              ],
            ),
          ),
          if (_hasAnswer || _asking)
            ChatUiStyle.suggestions(
              context: context,
              centered: false,
              chips: _suggestions(grammar, languageCode),
            ),
          ChatUiStyle.composer(
            context: context,
            controller: _input,
            hint: context.strings('practiceChatHint'),
            sendTooltip: context.strings('sendMessage'),
            enabled: !_asking,
            maxLength: 300,
            onSend: () => _sendInput(grammar, languageCode),
            sendKey: const ValueKey('grammar_practice_send'),
          ),
        ],
      ),
    ),
  );
}
