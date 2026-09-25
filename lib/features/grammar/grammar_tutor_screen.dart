import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
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
  static const _introPrompt =
      'Introduce this grammar point. Explain its meaning and formation, give '
      'two Japanese example sentences with natural translations, then invite '
      'me to write my own sentence using it.';
  final _messages = ChatMessagesController();
  final _input = TextEditingController();
  InferenceModelSession? _session;
  StreamSubscription<String>? _sub;
  bool _isBusy = false;
  bool _waiting = false;
  bool _hasSentIntro = false;
  bool _introFinished = false;
  bool _introFailed = false;

  @override
  void dispose() {
    final sub = _sub;
    if (sub != null) unawaited(sub.cancel());
    final session = _session;
    // Canceling the Dart stream alone may leave native inference running.
    if (session != null) unawaited(session.close());
    _messages.dispose();
    _input.dispose();
    super.dispose();
  }

  void _sendInput(GrammarPoint grammar, String languageCode) {
    final question = _input.text.trim();
    if (question.isEmpty || _isBusy || !_introFinished) return;
    _input.clear();
    _ask(grammar, languageCode, question);
  }

  Future<void> _ask(
    GrammarPoint grammar,
    String languageCode,
    String text, {
    bool practiceTask = false,
    bool intro = false,
  }) async {
    final question = text.trim();
    if (question.isEmpty ||
        question.length > 300 ||
        _isBusy ||
        (!intro && !_introFinished)) {
      return;
    }
    if (!intro) {
      _messages.addMessage(
        ChatMessage(text: question, user: _user, createdAt: DateTime.now()),
      );
    }
    setState(() {
      _isBusy = true;
      _waiting = true;
      if (intro) _introFailed = false;
    });
    final reply = StreamingChatReply(_messages, _assistant);
    try {
      final service = await ref.read(grammarPracticeServiceProvider.future);
      if (!mounted) return;
      final request = service.buildRequest(
        grammar: grammar,
        message: question,
        languageCode: languageCode,
        history: const [],
        practiceTask: practiceTask,
      );
      var session = _session;
      if (session == null) {
        final model = await service.controller.getLoadedModel();
        if (!mounted) return;
        session = await model.openSession(
          systemInstruction: request.system,
          temperature: 0.1,
          topP: 0.9,
          maxOutputTokens: 320,
        );
        if (!mounted) {
          await session.close();
          return;
        }
        _session = session;
      }
      await session.addQueryChunk(
        Message.text(text: request.input, isUser: true),
      );
      if (!mounted) return;
      final buffer = StringBuffer();
      _sub = session.getResponseAsync().listen(
        (token) {
          if (!mounted) return;
          buffer.write(token);
          if (_waiting) setState(() => _waiting = false);
          reply.update(buffer.toString());
        },
        onDone: () {
          if (!mounted) return;
          final answer = buffer.toString().trim();
          if (answer.isEmpty || answer.length > 4000) {
            _showError(
              reply,
              const OfflineAiException('offlineInvalidResponse'),
              intro: intro,
            );
            return;
          }
          reply.finish(answer);
          setState(() {
            if (intro) _introFinished = true;
            _isBusy = false;
            _waiting = false;
            _sub = null;
          });
        },
        onError: (Object error, StackTrace stackTrace) {
          if (mounted) _showError(reply, error, intro: intro);
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (mounted) _showError(reply, error, intro: intro);
    }
  }

  void _showError(
    StreamingChatReply reply,
    Object error, {
    bool intro = false,
  }) {
    final sub = _sub;
    if (sub != null) unawaited(sub.cancel());
    final session = _session;
    if (session != null) unawaited(session.close());
    reply.finish(
      context.strings(
        error is OfflineAiException ? error.key : 'offlineInferenceError',
      ),
    );
    setState(() {
      if (intro) _introFailed = true;
      _isBusy = false;
      _waiting = false;
      _sub = null;
      _session = null;
    });
  }

  List<Widget> _suggestions(GrammarPoint grammar, String languageCode) => [
    for (final key in [
      'practicePromptSuggestion',
      'practiceExampleSuggestion',
      'practiceUsageSuggestion',
    ])
      ChatUiStyle.suggestion(
        context.strings(key),
        _isBusy
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
          if (!_hasSentIntro) {
            _hasSentIntro = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _ask(
                  grammar,
                  languageCode,
                  _introPrompt,
                  practiceTask: true,
                  intro: true,
                );
              }
            });
          }
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
            child: AiChatWidget(
              currentUser: _user,
              aiUser: _assistant,
              controller: _messages,
              onSendMessage: (message) =>
                  _ask(grammar, languageCode, message.text),
              readOnly: true,
              loadingConfig: ChatUiStyle.loading(context, _waiting),
              messageOptions: ChatUiStyle.messages(context),
            ),
          ),
          if (_introFinished)
            ChatUiStyle.suggestions(
              context: context,
              centered: false,
              chips: _suggestions(grammar, languageCode),
            ),
          if (_introFailed)
            TextButton(
              onPressed: _isBusy
                  ? null
                  : () => _ask(
                      grammar,
                      languageCode,
                      _introPrompt,
                      practiceTask: true,
                      intro: true,
                    ),
              child: Text(context.strings('tryAgain')),
            ),
          ChatUiStyle.composer(
            context: context,
            controller: _input,
            hint: context.strings('practiceChatHint'),
            sendTooltip: context.strings('sendMessage'),
            enabled: _introFinished && !_isBusy,
            maxLength: 300,
            onSend: () => _sendInput(grammar, languageCode),
            sendKey: const ValueKey('grammar_practice_send'),
          ),
        ],
      ),
    ),
  );
}
