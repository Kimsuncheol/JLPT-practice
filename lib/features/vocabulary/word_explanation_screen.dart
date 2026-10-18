import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/core/api/jlpt_tutor_service.dart';
import 'package:jlpt_practice/core/api/jlpt_word_service.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/shared/api_tutor_chat.dart';

/// Word explanations and subsequent tutoring share one package-backed chat.
class WordExplanationScreen extends StatefulWidget {
  const WordExplanationScreen({
    required this.level,
    required this.language,
    this.word = '',
    this.contextSentence = '',
    super.key,
  });
  final String level, language, word, contextSentence;

  @override
  State<WordExplanationScreen> createState() => _WordExplanationScreenState();
}

class _WordExplanationScreenState extends State<WordExplanationScreen> {
  Map<String, dynamic> _wordContext = const {};

  Future<TutorReply> _explain(JlptApiClient client) async {
    final result = await JlptWordService(client).explain(
      word: widget.word,
      context: widget.contextSentence,
      level: widget.level,
      language: widget.language,
    );
    if (!mounted) return const TutorReply(text: '');
    _wordContext = result.tutorContext;
    final strings = context.strings;
    return TutorReply(
      text: [
        '## ${result.word} · ${result.reading}',
        for (final section in result.sections) ...[
          '### ${strings(section.titleKey)}',
          section.text.isEmpty
              ? strings('wordNoPastExamExamples')
              : section.text,
        ],
      ].join('\n\n'),
      followUpQuestions: result.followUpQuestions,
    );
  }

  @override
  Widget build(BuildContext context) => ApiTutorChat(
    title: context.strings('wordExplanation'),
    icon: Icons.auto_awesome_outlined,
    hint: context.strings('typeYourQuestion'),
    suggestionKeys: const [],
    closeKey: const ValueKey('word_chat_close'),
    sendKey: const ValueKey('word_chat_send'),
    level: widget.level,
    language: widget.language,
    contextBuilder: () => _wordContext,
    initialMessage: boundedText(
      [
        '${context.strings('explainWord')}: ${widget.word}',
        if (widget.contextSentence.trim().isNotEmpty) widget.contextSentence,
      ].join('\n'),
      500,
    ),
    showInitialMessage: false,
    initialReplyLoader: _explain,
  );
}
