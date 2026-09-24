import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/features/test/practice_ai_tutor_service.dart';

Future<void> showPracticeAiTutorSheet({
  required BuildContext context,
  required MockTestProblem problem,
  required String selectedAnswer,
  required String explanationLanguage,
  required VoidCallback onContinue,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: .82,
    child: PracticeAiTutorSheet(
      problem: problem,
      selectedAnswer: selectedAnswer,
      explanationLanguage: explanationLanguage,
      onContinue: onContinue,
    ),
  ),
);

class PracticeAiTutorSheet extends ConsumerStatefulWidget {
  const PracticeAiTutorSheet({
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
  ConsumerState<PracticeAiTutorSheet> createState() =>
      _PracticeAiTutorSheetState();
}

class _PracticeAiTutorSheetState extends ConsumerState<PracticeAiTutorSheet> {
  static const _maxQuestions = 10;
  static const _user = ChatUser(id: 'user', firstName: 'You');
  static const _assistant = ChatUser(id: 'ai', firstName: 'AI');

  final _chatController = ChatMessagesController();
  final List<PracticeTutorMessage> _messages = [];
  PracticeTutorFeedback? _feedback;
  Object? _error;
  bool _loading = true;
  bool _sending = false;
  bool _feedbackSent = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _chatController.dispose();
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
      );
      if (!mounted) return;
      _chatController.addMessage(
        ChatMessage.widget(user: _assistant, builder: _buildFeedbackContent),
      );
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
    });

    try {
      final evaluator = await ref.read(practiceAiTutorProvider.future);
      final reply = await evaluator.ask(
        problem: widget.problem,
        selectedAnswer: widget.selectedAnswer,
        explanationLanguage: widget.explanationLanguage,
        history: history,
        question: question,
      );
      if (!mounted) return;
      _chatController.addMessage(
        ChatMessage(text: reply, user: _assistant, createdAt: DateTime.now()),
      );
      setState(() {
        _messages.add(PracticeTutorMessage(isUser: false, text: reply));
      });
    } catch (_) {
      if (!mounted) return;
      _chatController.addMessage(
        ChatMessage(
          text: context.strings('aiReplyError'),
          user: _assistant,
          createdAt: DateTime.now(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
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

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.strings('aiTutor'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const ValueKey('practice_ai_close'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.strings('temporaryChatNotice'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _body()),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: FilledButton(
            key: const ValueKey('practice_ai_continue'),
            onPressed: () {
              Navigator.pop(context);
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
  );

  Widget _body() {
    if (_loading && _feedback == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.strings('askingAiTutor')),
          ],
        ),
      );
    }
    if (_error != null && _feedback == null) {
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
      readOnly: _sending || _questionCount >= _maxQuestions,
      loadingConfig: LoadingConfig(isLoading: _sending),
      inputOptions: InputOptions(
        decoration: InputDecoration(
          hintText: context.strings('typeYourQuestion'),
        ),
        inputFormatters: [LengthLimitingTextInputFormatter(500)],
        sendButtonTooltip: context.strings('sendMessage'),
        sendButtonBuilder: (onSend) => IconButton.filled(
          key: const ValueKey('practice_ai_chat_send'),
          tooltip: context.strings('sendMessage'),
          onPressed: onSend,
          icon: const Icon(Icons.send_rounded),
        ),
      ),
    );
  }

  Widget _buildFeedbackContent(BuildContext context) {
    final feedback = _feedback!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TutorSection(title: null, body: feedback.summary),
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
          const SizedBox(height: 4),
          Text(
            context.strings('askFollowUp'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _questionChip(context.strings('explainChoices')),
              if (widget.problem.passage.isNotEmpty)
                _questionChip(context.strings('showEvidence')),
              _questionChip(context.strings('giveExample')),
            ],
          ),
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
      ),
    );
  }

  Widget _questionChip(String label) => ActionChip(
    label: Text(label),
    onPressed: _sending || _questionCount >= _maxQuestions
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
