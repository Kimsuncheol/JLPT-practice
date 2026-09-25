import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/features/test/practice_ai_tutor_service.dart';
import 'package:jlpt_practice/shared/chat_ui_style.dart';
import 'package:jlpt_practice/shared/streaming_chat_reply.dart';

Future<void> showPracticeAiTutorScreen({
  required BuildContext context,
  required MockTestProblem problem,
  required String selectedAnswer,
  required String explanationLanguage,
  required VoidCallback onContinue,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => PracticeAiTutorScreen(
        problem: problem,
        selectedAnswer: selectedAnswer,
        explanationLanguage: explanationLanguage,
        onContinue: onContinue,
      ),
    ),
  );
}

class PracticeAiTutorScreen extends ConsumerStatefulWidget {
  const PracticeAiTutorScreen({
    required this.problem,
    required this.selectedAnswer,
    required this.explanationLanguage,
    required this.onContinue,
    super.key,
  });

  final MockTestProblem problem;
  final String selectedAnswer;
  final String explanationLanguage;
  final VoidCallback onContinue;

  @override
  ConsumerState<PracticeAiTutorScreen> createState() =>
      _PracticeAiTutorScreenState();
}

class _PracticeAiTutorScreenState extends ConsumerState<PracticeAiTutorScreen> {
  static const _maxQuestions = 10;
  static const _user = ChatUser(id: 'user', firstName: 'You');
  static const _assistant = ChatUser(id: 'ai', firstName: 'AI');

  final _chatController = ChatMessagesController();
  final _input = TextEditingController();
  final List<PracticeTutorMessage> _messages = [];
  PracticeTutorFeedback? _feedback;
  final _streamedFeedback = ValueNotifier<PracticeTutorFeedback?>(null);
  bool _feedbackMessageAdded = false;
  Object? _error;
  bool _loading = true;
  bool _sending = false;
  bool _waiting = false;
  bool _feedbackSent = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _chatController.dispose();
    _streamedFeedback.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final evaluator = await ref.read(practiceAiTutorProvider.future);
      final feedback = await evaluator.explain(
        problem: widget.problem,
        selectedAnswer: widget.selectedAnswer,
        explanationLanguage: widget.explanationLanguage,
        onPartial: (partial) {
          if (mounted) _showFeedback(partial);
        },
      );
      if (!mounted) return;
      _showFeedback(feedback);
      setState(() => _feedback = feedback);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Practice AI Tutor error type: ${error.runtimeType}');
        debugPrint('Practice AI Tutor failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFeedback(PracticeTutorFeedback feedback) {
    _streamedFeedback.value = feedback;
    if (_feedbackMessageAdded) return;
    _feedbackMessageAdded = true;
    _chatController.addMessage(
      ChatMessage.widget(user: _assistant, builder: _buildFeedbackContent),
    );
  }

  Future<void> _sendQuestion(String questionText) async {
    final question = questionText.trim();
    if (question.isEmpty ||
        question.length > 500 ||
        _sending ||
        _questionCount >= _maxQuestions) {
      return;
    }

    final history = List<PracticeTutorMessage>.of(_messages);
    _chatController.addMessage(
      ChatMessage(text: question, user: _user, createdAt: DateTime.now()),
    );
    setState(() {
      _messages.add(PracticeTutorMessage(isUser: true, text: question));
      _sending = true;
      _waiting = true;
    });
    final streamedReply = StreamingChatReply(_chatController, _assistant);

    try {
      final evaluator = await ref.read(practiceAiTutorProvider.future);
      final reply = await evaluator.ask(
        problem: widget.problem,
        selectedAnswer: widget.selectedAnswer,
        explanationLanguage: widget.explanationLanguage,
        history: history,
        question: question,
        onPartial: (text) {
          if (!mounted) return;
          if (_waiting) setState(() => _waiting = false);
          streamedReply.update(text);
        },
      );
      if (!mounted) return;
      streamedReply.finish(reply);
      setState(() {
        _messages.add(PracticeTutorMessage(isUser: false, text: reply));
      });
    } catch (_) {
      if (!mounted) return;
      streamedReply.finish(context.strings('aiReplyError'));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _waiting = false;
        });
        if (_questionCount >= _maxQuestions) {
          _chatController.addMessage(
            ChatMessage(
              text: context.strings('conversationLimit'),
              user: _assistant,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    }
  }

  int get _questionCount => _messages.where((message) => message.isUser).length;

  void _sendInput() {
    final question = _input.text.trim();
    if (question.isEmpty || _sending || _questionCount >= _maxQuestions) return;
    _input.clear();
    _sendQuestion(question);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
        title: ChatUiStyle.appBarTitle(
          context,
          Icons.school_rounded,
          context.strings('practiceChatTitle'),
        ),
        actions: [
          IconButton(
            key: const ValueKey('practice_ai_close'),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.strings('temporaryChatNotice'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ChatUiStyle.appBarDivider(context),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _body()),
                  if (_feedback == null && !_loading)
                    ChatUiStyle.suggestions(
                      context: context,
                      centered: true,
                      chips: _questionChips(context),
                    ),
                ],
              ),
            ),
            if (_feedback != null || _loading)
              ChatUiStyle.suggestions(
                context: context,
                centered: false,
                chips: _questionChips(context),
              ),
            if (_feedback != null)
              ChatUiStyle.composer(
                context: context,
                controller: _input,
                hint: context.strings('typeYourQuestion'),
                sendTooltip: context.strings('sendMessage'),
                enabled: !_sending && _questionCount < _maxQuestions,
                maxLength: 500,
                onSend: _sendInput,
                sendKey: const ValueKey('practice_ai_chat_send'),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                key: const ValueKey('practice_ai_continue'),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onContinue();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(context.strings('continue')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null && !_feedbackMessageAdded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44),
              const SizedBox(height: 14),
              Text(
                context.strings(
                  _error is QuotaExceeded
                      ? 'aiTutorBusy'
                      : 'aiTutorUnavailable',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _load,
                child: Text(context.strings('tryAgain')),
              ),
            ],
          ),
        ),
      );
    }

    return AiChatWidget(
      currentUser: _user,
      aiUser: _assistant,
      controller: _chatController,
      onSendMessage: (message) => _sendQuestion(message.text),
      readOnly: true,
      loadingConfig: ChatUiStyle.loading(
        context,
        _waiting || (_loading && !_feedbackMessageAdded),
      ),
      messageOptions: ChatUiStyle.messages(context),
    );
  }

  List<Widget> _questionChips(BuildContext context) => [
    _questionChip(context.strings('explainChoices')),
    _questionChip(context.strings('showEvidence')),
    _questionChip(context.strings('giveExample')),
  ];

  Widget _buildFeedbackContent(BuildContext context) =>
      ValueListenableBuilder<PracticeTutorFeedback?>(
        valueListenable: _streamedFeedback,
        builder: (context, feedback, _) => feedback == null
            ? const SizedBox.shrink()
            : _feedbackContent(context, feedback),
      );

  Widget _feedbackContent(
    BuildContext context,
    PracticeTutorFeedback feedback,
  ) {
    final done = _feedback != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (feedback.summary.isNotEmpty)
            _TutorSection(title: null, body: feedback.summary),
          if (feedback.whyCorrect.isNotEmpty)
            _TutorSection(
              title: context.strings('whyCorrect'),
              body: feedback.whyCorrect,
            ),
          if (feedback.whySelectedIsWrong?.trim().isNotEmpty == true)
            _TutorSection(
              title: context.strings('whyWrong'),
              body: feedback.whySelectedIsWrong!,
            ),
          if (feedback.keyEvidence.isNotEmpty)
            _TutorListSection(
              title: context.strings('keyEvidence'),
              items: feedback.keyEvidence,
              quote: true,
            ),
          if (feedback.learningPoints.isNotEmpty)
            _TutorListSection(
              title: context.strings('learningPoints'),
              items: feedback.learningPoints,
            ),
          if (done) ...[
            const SizedBox(height: 20),
            Text(
              context.strings('aiGeneratedNotice'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (_feedbackSent)
              Text(context.strings('thanksFeedback'))
            else
              Row(
                children: [
                  Text(context.strings('wasHelpful')),
                  IconButton(
                    onPressed: () => setState(() => _feedbackSent = true),
                    icon: const Icon(Icons.thumb_up_outlined),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _feedbackSent = true),
                    icon: const Icon(Icons.thumb_down_outlined),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _questionChip(String label) => ChatUiStyle.suggestion(
    label,
    _feedback == null || _loading || _sending || _questionCount >= _maxQuestions
        ? null
        : () => _sendQuestion(label),
  );
}

class _TutorSection extends StatelessWidget {
  const _TutorSection({required this.title, required this.body});

  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
        ],
        Text(body, style: const TextStyle(height: 1.5)),
      ],
    ),
  );
}

class _TutorListSection extends StatelessWidget {
  const _TutorListSection({
    required this.title,
    required this.items,
    this.quote = false,
  });

  final String title;
  final List<String> items;
  final bool quote;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              quote ? '“$item”' : '• $item',
              style: const TextStyle(height: 1.45),
            ),
          ),
      ],
    ),
  );
}
